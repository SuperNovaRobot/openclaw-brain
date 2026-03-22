"""
Camera Manager — PoE connection handling with auto-reconnect.
Builds the DepthAI pipeline and manages device lifecycle.
"""

import depthai as dai
import logging
import time
from typing import Optional, Dict, Any
from pathlib import Path

logger = logging.getLogger("nova_vision.camera")


class CameraManager:
    """Manages OAK-D Pro PoE camera connection and pipeline."""

    def __init__(self, config: dict):
        self.config = config
        self.cam_config = config["camera"]
        self.pipeline: Optional[dai.Pipeline] = None
        self.queues: Dict[str, Any] = {}
        self._running = False
        self._reconnect_count = 0

    def build_pipeline(self) -> dai.Pipeline:
        """Build the complete DepthAI pipeline based on config."""
        pipeline = dai.Pipeline()

        # --- Color Camera ---
        cam_rgb = pipeline.create(dai.node.ColorCamera)
        res_map = {
            "1080p": dai.ColorCameraProperties.SensorResolution.THE_1080_P,
            "4k": dai.ColorCameraProperties.SensorResolution.THE_4_K,
        }
        cam_rgb.setResolution(res_map.get(self.cam_config["color_resolution"], res_map["1080p"]))
        preview_w, preview_h = self.cam_config["preview_size"]
        cam_rgb.setPreviewSize(preview_w, preview_h)
        cam_rgb.setVideoSize(1920, 1080)
        cam_rgb.setFps(self.cam_config["fps"])
        cam_rgb.setBoardSocket(dai.CameraBoardSocket.CAM_A)
        cam_rgb.setInterleaved(False)
        cam_rgb.setColorOrder(dai.ColorCameraProperties.ColorOrder.BGR)

        # --- Mono Cameras ---
        mono_left = pipeline.create(dai.node.MonoCamera)
        mono_right = pipeline.create(dai.node.MonoCamera)
        mono_res_map = {
            "400p": dai.MonoCameraProperties.SensorResolution.THE_400_P,
            "720p": dai.MonoCameraProperties.SensorResolution.THE_720_P,
            "800p": dai.MonoCameraProperties.SensorResolution.THE_800_P,
        }
        mono_res = mono_res_map.get(self.cam_config["mono_resolution"], mono_res_map["400p"])
        mono_left.setResolution(mono_res)
        mono_right.setResolution(mono_res)
        mono_left.setFps(self.cam_config["fps"])
        mono_right.setFps(self.cam_config["fps"])
        mono_left.setBoardSocket(dai.CameraBoardSocket.CAM_B)
        mono_right.setBoardSocket(dai.CameraBoardSocket.CAM_C)

        # MJPEG encoder for PoE bandwidth efficiency
        # Raw 1080p = ~622 Mbps, MJPEG cuts latency from 51ms to 31ms at 1080p
        video_enc = pipeline.create(dai.node.VideoEncoder)
        video_enc.setDefaultProfilePreset(self.cam_config["fps"], dai.VideoEncoderProperties.Profile.MJPEG)
        video_enc.setQuality(90)
        cam_rgb.video.link(video_enc.input)

        # Optimize XLink for PoE
        pipeline.setXLinkChunkSize(0)

        # Store references for other pipeline builders
        pipeline._nova_rgb = cam_rgb
        pipeline._nova_mono_left = mono_left
        pipeline._nova_mono_right = mono_right
        pipeline._nova_video_enc = video_enc

        self.pipeline = pipeline
        return pipeline

    def create_output_queues(self):
        """Create output queues after pipeline is built and linked."""
        pipeline = self.pipeline
        rgb = pipeline._nova_rgb

        # MJPEG-encoded video output (bandwidth-efficient for PoE)
        video_enc = pipeline._nova_video_enc
        self.queues["video"] = video_enc.out.createOutputQueue(maxSize=1, blocking=False)
        # Raw preview for NN input / processing
        self.queues["preview"] = rgb.preview.createOutputQueue(maxSize=1, blocking=False)

        # Depth queue created by depth module
        # Detection queue created by detection module

    def start(self) -> bool:
        """Start the pipeline with PoE connection."""
        try:
            self.create_output_queues()
            logger.info("Starting PoE vision pipeline...")
            self.pipeline.start()
            self._running = True
            self._reconnect_count = 0

            # Configure IR after pipeline starts
            ir_config = self.config.get("ir", {})
            dot = ir_config.get("dot_projector_intensity", 0.0)
            flood = ir_config.get("flood_light_intensity", 0.0)
            if dot > 0 or flood > 0:
                # IR is set via device after pipeline.start()
                # In v3, we'd need device reference; for now log intent
                logger.info(f"IR config: dot={dot}, flood={flood}")

            logger.info("✅ Pipeline started successfully")
            return True
        except Exception as e:
            logger.error(f"Pipeline start failed: {e}")
            self._running = False
            return False

    def reconnect(self) -> bool:
        """Attempt to reconnect to the camera."""
        max_attempts = self.cam_config.get("max_reconnect_attempts", 10)
        delay = self.cam_config.get("reconnect_delay", 2.0)

        if self._reconnect_count >= max_attempts:
            logger.error(f"Max reconnect attempts ({max_attempts}) reached")
            return False

        self._reconnect_count += 1
        logger.warning(f"Reconnect attempt {self._reconnect_count}/{max_attempts}...")
        time.sleep(delay)

        try:
            self.stop()
            self.pipeline = None
            self.queues = {}
            self.build_pipeline()
            # Re-run pipeline configuration (detection, depth, etc. need to re-link)
            return True
        except Exception as e:
            logger.error(f"Reconnect failed: {e}")
            return False

    def get_frame(self, queue_name: str, timeout_ms: int = 100):
        """Get a frame from a queue with timeout."""
        from datetime import timedelta
        queue = self.queues.get(queue_name)
        if queue is None:
            return None
        try:
            return queue.get(timeout=timedelta(milliseconds=timeout_ms))
        except Exception:
            return None

    @property
    def is_running(self) -> bool:
        try:
            return self._running and self.pipeline is not None and self.pipeline.isRunning()
        except Exception:
            return False

    def stop(self):
        """Stop the pipeline."""
        try:
            if self.pipeline:
                self.pipeline.stop()
                logger.info("Pipeline stopped")
        except Exception as e:
            logger.warning(f"Stop warning: {e}")
        self._running = False

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.stop()
