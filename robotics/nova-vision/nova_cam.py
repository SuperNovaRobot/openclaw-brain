#!/usr/bin/env python3
"""
Nova Camera Daemon — Persistent OAK-D Pro PoE connection with HTTP MJPEG stream.

Stays connected, auto-reconnects on drop, serves frames over HTTP.
Kill cleanly with Ctrl+C or SIGTERM.

Usage:
    python3 nova_cam.py                    # Start daemon (port 8090)
    python3 nova_cam.py --port 8091        # Custom port
    python3 nova_cam.py --no-depth         # RGB only, no depth/detection
    python3 nova_cam.py --fps 30           # Target FPS

Endpoints:
    /              — Web UI with live view
    /stream        — Raw MJPEG stream (for <img> tags, VLC, etc.)
    /snapshot      — Single JPEG frame
    /depth         — Depth colormap MJPEG stream
    /status        — JSON status
    /kill          — Clean shutdown
"""

import os
import sys
import time
import signal
import logging
import threading
import json
import numpy as np
import cv2
from datetime import datetime, timedelta
from http.server import HTTPServer, BaseHTTPRequestHandler
from typing import Optional
import argparse

# Must be set BEFORE importing depthai
# Can be overridden by --ip flag in main()
if "DEPTHAI_DEVICE_NAME_LIST" not in os.environ:
    os.environ["DEPTHAI_DEVICE_NAME_LIST"] = "169.254.1.222"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
    datefmt="%H:%M:%S"
)
logger = logging.getLogger("nova_cam")


class CameraState:
    """Thread-safe shared state between camera thread and HTTP server."""

    def __init__(self):
        self.lock = threading.Lock()
        self.rgb_frame: Optional[np.ndarray] = None
        self.depth_frame: Optional[np.ndarray] = None
        self.rgb_jpeg: Optional[bytes] = None
        self.depth_jpeg: Optional[bytes] = None
        self.fps: float = 0.0
        self.frame_count: int = 0
        self.connected: bool = False
        self.reconnect_count: int = 0
        self.last_frame_time: float = 0
        self.started_at: float = time.time()
        self.error: str = ""
        self.detection_results: list = []

    def update_rgb(self, frame: np.ndarray):
        _, jpeg = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
        with self.lock:
            self.rgb_frame = frame
            self.rgb_jpeg = jpeg.tobytes()
            self.frame_count += 1
            now = time.time()
            if self.last_frame_time > 0:
                dt = now - self.last_frame_time
                # Exponential moving average FPS
                instant_fps = 1.0 / dt if dt > 0 else 0
                self.fps = self.fps * 0.9 + instant_fps * 0.1 if self.fps > 0 else instant_fps
            self.last_frame_time = now

    def update_depth(self, depth_frame: np.ndarray):
        # Colormap for visualization
        depth_norm = cv2.normalize(depth_frame, None, 0, 255, cv2.NORM_MINMAX, dtype=cv2.CV_8U)
        depth_color = cv2.applyColorMap(depth_norm, cv2.COLORMAP_JET)
        _, jpeg = cv2.imencode('.jpg', depth_color, [cv2.IMWRITE_JPEG_QUALITY, 80])
        with self.lock:
            self.depth_frame = depth_frame
            self.depth_jpeg = jpeg.tobytes()

    def get_rgb_jpeg(self) -> Optional[bytes]:
        with self.lock:
            return self.rgb_jpeg

    def get_depth_jpeg(self) -> Optional[bytes]:
        with self.lock:
            return self.depth_jpeg

    def get_status(self) -> dict:
        with self.lock:
            return {
                "connected": self.connected,
                "fps": round(self.fps, 1),
                "frame_count": self.frame_count,
                "reconnect_count": self.reconnect_count,
                "uptime_seconds": round(time.time() - self.started_at),
                "last_frame_age_ms": round((time.time() - self.last_frame_time) * 1000) if self.last_frame_time > 0 else -1,
                "error": self.error,
            }


class CameraDaemon(threading.Thread):
    """Persistent camera connection with auto-reconnect."""

    def __init__(self, state: CameraState, device_ip: str = "169.254.1.222",
                 fps: int = 30, enable_depth: bool = True, enable_detection: bool = False,
                 blob_path: str = ""):
        super().__init__(daemon=True)
        self.state = state
        self.device_ip = device_ip
        self.fps = fps
        self.enable_depth = enable_depth
        self.enable_detection = enable_detection
        self.blob_path = blob_path
        self._stop_event = threading.Event()

    def stop(self):
        self._stop_event.set()

    def run(self):
        """Main loop — connect, stream, reconnect on failure."""
        # Set env var BEFORE importing depthai so it picks up the PoE IP
        import os as _os
        _os.environ["DEPTHAI_DEVICE_NAME_LIST"] = self.device_ip
        import depthai as dai

        while not self._stop_event.is_set():
            try:
                self._run_pipeline(dai)
            except Exception as e:
                logger.error(f"Pipeline error: {e}")
                self.state.error = str(e)
                self.state.connected = False

            if not self._stop_event.is_set():
                self.state.reconnect_count += 1
                wait = min(2 ** min(self.state.reconnect_count, 5), 30)
                logger.warning(f"Reconnecting in {wait}s (attempt {self.state.reconnect_count})...")
                self._stop_event.wait(wait)

    def _run_pipeline(self, dai):
        """Build pipeline, connect, and stream until failure or stop."""
        pipeline = dai.Pipeline()

        # --- RGB Camera ---
        rgb = pipeline.create(dai.node.ColorCamera)
        rgb.setResolution(dai.ColorCameraProperties.SensorResolution.THE_1080_P)
        rgb.setVideoSize(1920, 1080)
        rgb.setPreviewSize(416, 416)  # NN input size
        rgb.setFps(self.fps)
        rgb.setBoardSocket(dai.CameraBoardSocket.CAM_A)
        rgb.setInterleaved(False)
        rgb.setColorOrder(dai.ColorCameraProperties.ColorOrder.BGR)

        # --- MJPEG encoder for bandwidth ---
        encoder = pipeline.create(dai.node.VideoEncoder)
        encoder.setDefaultProfilePreset(self.fps, dai.VideoEncoderProperties.Profile.MJPEG)
        encoder.setQuality(85)
        rgb.video.link(encoder.input)

        # Optimize for PoE
        pipeline.setXLinkChunkSize(0)

        # Create queues
        video_q = encoder.out.createOutputQueue(maxSize=1, blocking=False)
        preview_q = rgb.preview.createOutputQueue(maxSize=1, blocking=False)

        depth_q = None
        det_q = None

        if self.enable_depth:
            mono_left = pipeline.create(dai.node.MonoCamera)
            mono_right = pipeline.create(dai.node.MonoCamera)
            mono_left.setResolution(dai.MonoCameraProperties.SensorResolution.THE_400_P)
            mono_right.setResolution(dai.MonoCameraProperties.SensorResolution.THE_400_P)
            mono_left.setFps(self.fps)
            mono_right.setFps(self.fps)
            mono_left.setBoardSocket(dai.CameraBoardSocket.CAM_B)
            mono_right.setBoardSocket(dai.CameraBoardSocket.CAM_C)

            stereo = pipeline.create(dai.node.StereoDepth)
            stereo.setDefaultProfilePreset(dai.node.StereoDepth.PresetMode.ROBOTICS)
            stereo.initialConfig.setMedianFilter(dai.MedianFilter.KERNEL_5x5)
            stereo.setLeftRightCheck(True)
            stereo.setSubpixel(True)
            stereo.setDepthAlign(dai.CameraBoardSocket.CAM_A)
            stereo.initialConfig.postProcessing.speckleFilter.enable = True
            stereo.initialConfig.postProcessing.speckleFilter.speckleRange = 50
            stereo.initialConfig.postProcessing.spatialFilter.enable = True

            mono_left.out.link(stereo.left)
            mono_right.out.link(stereo.right)

            depth_q = stereo.depth.createOutputQueue(maxSize=1, blocking=False)

            # Detection (if blob available)
            if self.enable_detection and self.blob_path:
                import os
                if os.path.exists(self.blob_path):
                    det_nn = pipeline.create(dai.node.YoloSpatialDetectionNetwork)
                    det_nn.setBlobPath(self.blob_path)
                    det_nn.setConfidenceThreshold(0.5)
                    det_nn.setNumClasses(80)
                    det_nn.setCoordinateSize(4)
                    det_nn.setIouThreshold(0.5)
                    det_nn.setBoundingBoxScaleFactor(0.5)
                    det_nn.setDepthLowerThreshold(100)
                    det_nn.setDepthUpperThreshold(10000)
                    det_nn.input.setBlocking(False)
                    det_nn.input.setQueueSize(1)

                    rgb.preview.link(det_nn.input)
                    stereo.depth.link(det_nn.inputDepth)

                    det_q = det_nn.out.createOutputQueue(maxSize=1, blocking=False)

        # --- Start pipeline (device targeted via DEPTHAI_DEVICE_NAME_LIST env var) ---
        logger.info(f"Connecting to PoE camera at {self.device_ip}...")
        pipeline.start()
        self.state.connected = True
        self.state.error = ""
        logger.info("✅ Pipeline running")

        # --- Stream loop ---
        while pipeline.isRunning() and not self._stop_event.is_set():
            # RGB (MJPEG encoded)
            try:
                msg = video_q.get(timeout=timedelta(milliseconds=500))
                if msg is not None:
                    frame = cv2.imdecode(
                        np.frombuffer(msg.getData(), dtype=np.uint8),
                        cv2.IMREAD_COLOR
                    )
                    if frame is not None:
                        self.state.update_rgb(frame)
            except Exception:
                pass

            # Depth
            if depth_q is not None:
                try:
                    dmsg = depth_q.tryGet()
                    if dmsg is not None:
                        self.state.update_depth(dmsg.getFrame())
                except Exception:
                    pass

            # Detections
            if det_q is not None:
                try:
                    det_msg = det_q.tryGet()
                    if det_msg is not None:
                        dets = []
                        for d in det_msg.detections:
                            dets.append({
                                "label": d.label,
                                "confidence": round(d.confidence, 2),
                                "z_mm": round(d.spatialCoordinates.z) if hasattr(d, 'spatialCoordinates') else 0,
                            })
                        self.state.detection_results = dets
                except Exception:
                    pass

        pipeline.stop()
        self.state.connected = False
        logger.info("Pipeline stopped")


# ---- HTTP Server ----

BOUNDARY = b"--novacamframe"

HTML_PAGE = """<!DOCTYPE html>
<html>
<head>
    <title>Nova Vision</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { background: #0a0a0a; color: #e0e0e0; font-family: 'Courier New', monospace; }
        .header { padding: 12px 20px; background: #111; border-bottom: 1px solid #222;
                   display: flex; justify-content: space-between; align-items: center; }
        .header h1 { font-size: 16px; color: #4fc3f7; }
        .status { font-size: 12px; }
        .status .live { color: #4caf50; }
        .status .dead { color: #f44336; }
        .grid { display: flex; flex-wrap: wrap; padding: 10px; gap: 10px; }
        .feed { flex: 1; min-width: 480px; position: relative; }
        .feed img { width: 100%%; border: 1px solid #222; border-radius: 4px; }
        .feed-label { position: absolute; top: 8px; left: 8px; background: rgba(0,0,0,0.7);
                       padding: 2px 8px; border-radius: 3px; font-size: 11px; color: #4fc3f7; }
        .info { padding: 10px 20px; font-size: 12px; color: #888; }
        #stats { padding: 8px 20px; font-size: 12px; color: #aaa; }
    </style>
</head>
<body>
    <div class="header">
        <h1>⚡ NOVA VISION</h1>
        <div class="status"><span id="indicator" class="dead">● CONNECTING</span></div>
    </div>
    <div class="grid">
        <div class="feed">
            <div class="feed-label">RGB</div>
            <img id="rgb" src="/stream" alt="RGB Stream">
        </div>
        <div class="feed">
            <div class="feed-label">DEPTH</div>
            <img id="depth" src="/depth" alt="Depth Stream">
        </div>
    </div>
    <div id="stats"></div>
    <script>
        function poll() {
            fetch('/status').then(r => r.json()).then(s => {
                const el = document.getElementById('indicator');
                if (s.connected) {
                    el.className = 'live';
                    el.textContent = '● LIVE  ' + s.fps + ' FPS  |  ' + s.frame_count + ' frames  |  reconnects: ' + s.reconnect_count;
                } else {
                    el.className = 'dead';
                    el.textContent = '● DISCONNECTED  ' + (s.error || '');
                }
                document.getElementById('stats').textContent =
                    'Uptime: ' + s.uptime_seconds + 's  |  Last frame: ' + s.last_frame_age_ms + 'ms ago';
            }).catch(() => {});
        }
        setInterval(poll, 1000);
        poll();
    </script>
</body>
</html>"""


class StreamHandler(BaseHTTPRequestHandler):
    """HTTP handler for MJPEG streams and API endpoints."""

    state: CameraState = None  # Set by factory
    shutdown_event: threading.Event = None

    def log_message(self, format, *args):
        pass  # Suppress access logs

    def do_GET(self):
        if self.path == "/":
            self._serve_html()
        elif self.path == "/stream":
            self._serve_mjpeg("rgb")
        elif self.path == "/depth":
            self._serve_mjpeg("depth")
        elif self.path == "/snapshot":
            self._serve_snapshot()
        elif self.path == "/status":
            self._serve_status()
        elif self.path == "/kill":
            self._serve_kill()
        else:
            self.send_error(404)

    def _serve_html(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(HTML_PAGE.encode())

    def _serve_mjpeg(self, stream_type):
        self.send_response(200)
        self.send_header("Content-Type", "multipart/x-mixed-replace; boundary=novacamframe")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()

        try:
            while not self.shutdown_event.is_set():
                if stream_type == "rgb":
                    jpeg = self.state.get_rgb_jpeg()
                else:
                    jpeg = self.state.get_depth_jpeg()

                if jpeg is not None:
                    self.wfile.write(BOUNDARY + b"\r\n")
                    self.wfile.write(b"Content-Type: image/jpeg\r\n")
                    self.wfile.write(f"Content-Length: {len(jpeg)}\r\n\r\n".encode())
                    self.wfile.write(jpeg)
                    self.wfile.write(b"\r\n")
                    self.wfile.flush()

                time.sleep(1.0 / 30)  # Cap stream to 30 FPS for browsers
        except (BrokenPipeError, ConnectionResetError):
            pass

    def _serve_snapshot(self):
        jpeg = self.state.get_rgb_jpeg()
        if jpeg is None:
            self.send_error(503, "No frame available")
            return
        self.send_response(200)
        self.send_header("Content-Type", "image/jpeg")
        self.send_header("Content-Length", str(len(jpeg)))
        self.end_headers()
        self.wfile.write(jpeg)

    def _serve_status(self):
        status = self.state.get_status()
        body = json.dumps(status).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _serve_kill(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"Shutting down...\n")
        self.shutdown_event.set()


def main():
    parser = argparse.ArgumentParser(description="Nova Camera Daemon")
    parser.add_argument("--ip", default="169.254.1.222", help="Camera IP")
    parser.add_argument("--port", type=int, default=8090, help="HTTP port")
    parser.add_argument("--fps", type=int, default=30, help="Target FPS")
    parser.add_argument("--no-depth", action="store_true", help="Disable depth")
    parser.add_argument("--detect", action="store_true", help="Enable YOLO detection")
    parser.add_argument("--blob", default="/mnt/ssd/models/nova_vision/blobs/yolov8n_coco_416x416_openvino_2022.1_6shave.blob",
                        help="Path to YOLO blob")
    args = parser.parse_args()

    state = CameraState()
    shutdown_event = threading.Event()

    # Camera thread
    cam = CameraDaemon(
        state=state,
        device_ip=args.ip,
        fps=args.fps,
        enable_depth=not args.no_depth,
        enable_detection=args.detect,
        blob_path=args.blob,
    )

    # HTTP server
    StreamHandler.state = state
    StreamHandler.shutdown_event = shutdown_event
    server = HTTPServer(("0.0.0.0", args.port), StreamHandler)
    server.timeout = 1

    # Signal handling
    def handle_signal(sig, frame):
        logger.info("Shutdown signal received")
        shutdown_event.set()
    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    # Start
    cam.start()
    logger.info(f"⚡ Nova Cam serving on http://0.0.0.0:{args.port}")
    logger.info(f"   Stream: http://0.0.0.0:{args.port}/stream")
    logger.info(f"   Depth:  http://0.0.0.0:{args.port}/depth")
    logger.info(f"   Status: http://0.0.0.0:{args.port}/status")
    logger.info(f"   Kill:   http://0.0.0.0:{args.port}/kill")

    while not shutdown_event.is_set():
        server.handle_request()

    # Cleanup
    logger.info("Shutting down...")
    cam.stop()
    cam.join(timeout=5)
    server.server_close()
    logger.info("✅ Nova Cam stopped cleanly")


if __name__ == "__main__":
    main()
