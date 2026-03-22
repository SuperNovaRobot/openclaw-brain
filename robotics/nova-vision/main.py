#!/usr/bin/env python3
"""
Nova Vision System — Main entry point.
Complete vision pipeline for Nova humanoid robot.

Usage:
    python3 main.py              # Run vision system
    python3 main.py --test       # Quick test (10 seconds)
    python3 main.py --snapshot   # Take a single photo and exit
    python3 main.py --describe   # Take photo + describe scene
"""

import sys
import time
import yaml
import logging
import argparse
import signal
import numpy as np
from pathlib import Path
from typing import Optional

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
    datefmt="%H:%M:%S"
)
logger = logging.getLogger("nova_vision")

# Project root
PROJECT_DIR = Path(__file__).parent


def load_config(config_path: str = None) -> dict:
    """Load configuration from YAML."""
    if config_path is None:
        config_path = str(PROJECT_DIR / "config.yaml")
    with open(config_path, 'r') as f:
        return yaml.safe_load(f)


class NovaVision:
    """Main vision system orchestrator."""

    def __init__(self, config: dict):
        self.config = config
        self._running = False

        # Import pipeline modules
        from pipeline.camera import CameraManager
        from pipeline.depth import DepthConfigurator
        from pipeline.detection import DetectionPipeline
        from pipeline.spatial import SpatialAnalyzer
        from pipeline.face import FaceProcessor
        from integration.nova_bridge import NovaBridge

        # Initialize modules
        self.camera = CameraManager(config)
        self.depth = DepthConfigurator(config)
        self.detection = DetectionPipeline(config)
        self.spatial = SpatialAnalyzer(config)
        self.face = FaceProcessor(config)
        self.bridge = NovaBridge(config)

        self._last_frame = None

    def initialize(self) -> bool:
        """Build and start the complete pipeline."""
        try:
            # Build pipeline
            pipeline = self.camera.build_pipeline()

            # Configure depth (must be before detection for spatial linking)
            self.depth.configure(pipeline)

            # Configure detection
            self.detection.configure(pipeline)

            # Create output queues
            self.depth.create_depth_queue(pipeline, self.camera)
            self.detection.create_queues(pipeline, self.camera)

            # Start pipeline
            if not self.camera.start():
                return False

            self._running = True
            logger.info("🤖 Nova Vision System initialized!")
            return True

        except Exception as e:
            logger.error(f"Initialization failed: {e}")
            import traceback
            traceback.print_exc()
            return False

    def perceive(self) -> Optional[dict]:
        """Run one perception cycle. Returns perception state dict."""
        if not self.camera.is_running:
            if self.config["camera"].get("auto_reconnect", True):
                logger.warning("Camera disconnected, attempting reconnect...")
                if self.camera.reconnect():
                    # Need to re-initialize the full pipeline
                    self.initialize()
                else:
                    return None
            else:
                return None

        # Get frames
        preview_msg = self.camera.get_frame("preview", timeout_ms=50)
        depth_msg = self.camera.get_frame("depth", timeout_ms=50)
        det_msg = self.camera.get_frame("detections", timeout_ms=50)
        track_msg = self.camera.get_frame("tracklets", timeout_ms=50)

        # Process frames
        frame = preview_msg.getCvFrame() if preview_msg else None
        depth_frame = depth_msg.getFrame() if depth_msg else None

        if frame is not None:
            self._last_frame = frame

        # Parse detections
        detection_result = self.detection.parse_detections(det_msg, track_msg)

        # Spatial analysis
        spatial_state = self.spatial.analyze(depth_frame) if depth_frame is not None else None

        # Face processing (runs on Jetson GPU, not every frame)
        face_result = None
        if self.face.enabled and frame is not None:
            face_result = self.face.process(frame)

        # Build unified perception
        perception = self.bridge.build_perception(
            frame=frame,
            depth_frame=depth_frame,
            detection_result=detection_result,
            spatial_state=spatial_state,
            face_result=face_result,
        )

        return perception.to_dict()

    def describe(self) -> str:
        """Get natural language description of current scene."""
        return self.bridge.describe_scene()

    def snapshot(self, path: str = None) -> str:
        """Take a snapshot, returns file path."""
        import cv2
        # Get a fresh frame — video is MJPEG encoded, decode it
        msg = self.camera.get_frame("video", timeout_ms=1000)
        if msg is not None:
            frame = cv2.imdecode(np.frombuffer(msg.getData(), dtype=np.uint8), cv2.IMREAD_COLOR)
        else:
            msg = self.camera.get_frame("preview", timeout_ms=1000)
            frame = msg.getCvFrame() if msg else self._last_frame
        if frame is None:
            return ""
        return self.bridge.take_snapshot(frame, path)

    def get_status(self) -> dict:
        """Get system status."""
        return {
            "running": self.camera.is_running,
            "camera_ip": self.config["camera"]["device_ip"],
            "fps": self.config["camera"]["fps"],
            "depth_enabled": self.config["depth"]["enabled"],
            "detection_enabled": self.config["detection"]["enabled"],
            "detection_model": self.config["detection"]["model"],
            "tracking_enabled": self.config["tracking"]["enabled"],
            "face_enabled": self.config["face"]["enabled"],
        }

    def shutdown(self):
        """Clean shutdown."""
        self._running = False
        self.camera.stop()
        logger.info("Nova Vision shutdown complete")


def main():
    parser = argparse.ArgumentParser(description="Nova Vision System")
    parser.add_argument("--config", type=str, default=None, help="Config file path")
    parser.add_argument("--test", action="store_true", help="Run 10-second test")
    parser.add_argument("--snapshot", action="store_true", help="Take one photo and exit")
    parser.add_argument("--describe", action="store_true", help="Describe current scene")
    args = parser.parse_args()

    config = load_config(args.config)
    vision = NovaVision(config)

    # Handle signals
    def signal_handler(sig, frame):
        logger.info("Shutting down...")
        vision.shutdown()
        sys.exit(0)
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    if not vision.initialize():
        logger.error("Failed to initialize vision system")
        sys.exit(1)

    if args.snapshot:
        path = vision.snapshot()
        print(f"Snapshot saved: {path}" if path else "Failed to capture snapshot")
        vision.shutdown()
        return

    if args.describe:
        # Run a few frames to warm up
        for _ in range(10):
            vision.perceive()
        print(vision.describe())
        vision.shutdown()
        return

    # Main loop
    duration = 10 if args.test else float('inf')
    start = time.time()
    frame_count = 0
    last_report = start

    print("🤖 Nova Vision System running...")
    print("   Press Ctrl+C to stop\n")

    while time.time() - start < duration:
        perception = vision.perceive()
        if perception is None:
            time.sleep(0.1)
            continue

        frame_count += 1
        now = time.time()

        # Report every 2 seconds
        if now - last_report >= 2.0:
            last_report = now
            print(f"  FPS: {perception['fps']}")
            print(f"  Scene: {perception['scene']['lighting']} ({perception['scene']['color_temperature']})")
            if perception['detections']:
                labels = [d['label'] for d in perception['detections'][:5]]
                print(f"  Detected: {', '.join(labels)}")
            if perception['persons_count'] > 0:
                print(f"  Persons: {perception['persons_count']} (nearest: {perception['nearest_person_distance']:.1f}m)")
            if perception['intimate_space_alert']:
                print(f"  ⚠️ CLOSE OBSTACLE at {perception['nearest_distance']:.1f}m")
            print(f"  Safe to move: {perception['safe_to_move']} ({perception['best_direction']})")
            print()

    elapsed = time.time() - start
    avg_fps = frame_count / elapsed if elapsed > 0 else 0
    print(f"\n📊 Summary: {frame_count} frames in {elapsed:.1f}s = {avg_fps:.1f} FPS avg")
    print(f"\n🔍 Scene: {vision.describe()}")

    vision.shutdown()


if __name__ == "__main__":
    main()
