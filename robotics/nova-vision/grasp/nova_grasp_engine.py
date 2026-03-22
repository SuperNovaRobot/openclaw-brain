#!/usr/bin/env python3
"""
Nova Grasp Engine — Vision-guided robotic grasping.

Real-time loop (30Hz) that coordinates:
- OAK-D depth → target 3D position
- Visual servoing → hand trajectory
- Dynamixel feedback → grip confirmation

Runs as a service that Nova (LLM) can command via HTTP.

Usage:
    python3 nova_grasp_engine.py                          # Start engine
    python3 nova_grasp_engine.py --port 8091              # Custom port

API:
    POST /grasp   {"target": "cup", "x": 200, "y": -50, "z": 800}
    POST /open    Open hand
    POST /close   Close hand (grip until contact)
    GET  /state   Hand + vision state JSON
    GET  /stop    Emergency stop
"""

import time
import json
import logging
import threading
import numpy as np
import urllib.request
from http.server import HTTPServer, BaseHTTPRequestHandler
from typing import Optional, Dict, Tuple
from dataclasses import dataclass, asdict

logger = logging.getLogger("nova_grasp")

CAMERA_URL = "http://localhost:8090"


@dataclass
class GraspTarget:
    """Target object to grasp."""
    label: str = ""
    x_mm: float = 0.0
    y_mm: float = 0.0
    z_mm: float = 0.0    # distance from camera
    width_mm: float = 80  # estimated object width for grip


@dataclass
class GraspState:
    """Current state of the grasp engine."""
    phase: str = "idle"   # idle, approaching, servoing, gripping, holding, failed
    target: Optional[GraspTarget] = None
    hand_connected: bool = False
    camera_connected: bool = False
    grip_force_ma: int = 0
    error_mm: float = 0.0  # distance to target
    fps: float = 0.0


class GraspEngine:
    """Real-time vision-guided grasp controller."""

    def __init__(self, hand_port: str = "/dev/ttyUSB0", motor_config: Dict[str, int] = None):
        from nova_hand import RukaHand

        self.hand = RukaHand(port=hand_port, motor_config=motor_config or {})
        self.state = GraspState()
        self._running = False
        self._stop = threading.Event()
        self._target: Optional[GraspTarget] = None
        self._lock = threading.Lock()

    def start(self):
        """Connect hand and start control loop."""
        if self.hand.motor_config:
            self.state.hand_connected = self.hand.connect()
            if self.state.hand_connected:
                self.hand.set_mode()  # Current-position mode

        # Check camera
        self.state.camera_connected = self._check_camera()

        self._running = True
        self._thread = threading.Thread(target=self._control_loop, daemon=True)
        self._thread.start()
        logger.info("⚡ Grasp engine started")

    def stop(self):
        """Emergency stop — open hand, disable torque."""
        self._stop.set()
        self._target = None
        self.state.phase = "idle"
        if self.state.hand_connected:
            self.hand.open_hand()
            time.sleep(0.5)
            self.hand.enable_torque(False)
        logger.info("🛑 Grasp engine stopped")

    def grasp(self, target: GraspTarget):
        """Command: grasp the target object."""
        with self._lock:
            self._target = target
            self.state.target = target
            self.state.phase = "approaching"
        logger.info(f"🎯 Grasping: {target.label} at ({target.x_mm}, {target.y_mm}, {target.z_mm}mm)")

    def open(self):
        """Command: open hand."""
        with self._lock:
            self._target = None
            self.state.phase = "idle"
        if self.state.hand_connected:
            self.hand.open_hand()

    def close(self):
        """Command: close hand until contact."""
        with self._lock:
            self.state.phase = "gripping"
        if self.state.hand_connected:
            gripped = self.hand.grip_until_contact()
            self.state.phase = "holding" if gripped else "failed"

    def get_state(self) -> dict:
        """Get current state as dict."""
        with self._lock:
            d = {
                "phase": self.state.phase,
                "hand_connected": self.state.hand_connected,
                "camera_connected": self.state.camera_connected,
                "grip_force_ma": self.state.grip_force_ma,
                "error_mm": round(self.state.error_mm, 1),
                "fps": round(self.state.fps, 1),
            }
            if self.state.target:
                d["target"] = asdict(self.state.target)
            return d

    def _control_loop(self):
        """Main 30Hz control loop."""
        frame_count = 0
        loop_start = time.time()

        while not self._stop.is_set():
            loop_time = time.time()

            with self._lock:
                target = self._target
                phase = self.state.phase

            if phase == "approaching" and target is not None:
                self._servo_step(target)
            elif phase == "gripping":
                pass  # Grip is handled synchronously
            elif phase == "holding":
                # Monitor grip — regrasp if object slips
                if self.state.hand_connected:
                    hand_state = self.hand.read_state()
                    self.state.grip_force_ma = hand_state.grip_force_ma
                    if not hand_state.is_gripping:
                        logger.warning("Object slipped! Regripping...")
                        self.hand.grip_until_contact()

            # FPS tracking
            frame_count += 1
            elapsed = time.time() - loop_start
            if elapsed > 1.0:
                self.state.fps = frame_count / elapsed
                frame_count = 0
                loop_start = time.time()

            # Target ~30Hz
            dt = time.time() - loop_time
            sleep_time = max(0, (1.0 / 30) - dt)
            time.sleep(sleep_time)

    def _servo_step(self, target: GraspTarget):
        """
        One step of visual servoing.
        Gets current depth frame, computes error to target, sends motor correction.
        """
        # Get current target position from camera
        current_pos = self._get_target_position(target.label)
        if current_pos is None:
            return

        cx, cy, cz = current_pos
        error = np.sqrt((cx - target.x_mm)**2 + (cy - target.y_mm)**2 + (cz - target.z_mm)**2)
        self.state.error_mm = error

        if error < 20:  # Within 20mm — close enough to grip
            with self._lock:
                self.state.phase = "gripping"
            if self.state.hand_connected:
                gripped = self.hand.grip_until_contact()
                with self._lock:
                    self.state.phase = "holding" if gripped else "failed"

        # TODO: Send motor commands to move hand toward target
        # This requires knowing the hand's position in camera frame
        # (hand-eye calibration) and inverse kinematics for the arm

    def _get_target_position(self, label: str) -> Optional[Tuple[float, float, float]]:
        """Get target 3D position from camera daemon."""
        try:
            r = urllib.request.urlopen(f"{CAMERA_URL}/status", timeout=0.1)
            status = json.loads(r.read())
            # When detection is running, positions come from YOLO spatial
            # For now return None — needs detection endpoint on daemon
            return None
        except Exception:
            return None

    def _check_camera(self) -> bool:
        """Check if camera daemon is running."""
        try:
            r = urllib.request.urlopen(f"{CAMERA_URL}/status", timeout=2)
            status = json.loads(r.read())
            return status.get("connected", False)
        except Exception:
            return False


# --- HTTP API ---

class GraspHandler(BaseHTTPRequestHandler):
    engine: GraspEngine = None

    def log_message(self, *args):
        pass

    def do_GET(self):
        if self.path == "/state":
            body = json.dumps(self.engine.get_state()).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/stop":
            self.engine.stop()
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"Stopped\n")
        else:
            self.send_error(404)

    def do_POST(self):
        content_len = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(content_len)) if content_len > 0 else {}

        if self.path == "/grasp":
            target = GraspTarget(
                label=body.get("target", "object"),
                x_mm=body.get("x", 0),
                y_mm=body.get("y", 0),
                z_mm=body.get("z", 0),
                width_mm=body.get("width", 80),
            )
            self.engine.grasp(target)
            self._json_response({"status": "approaching", "target": asdict(target)})

        elif self.path == "/open":
            self.engine.open()
            self._json_response({"status": "opened"})

        elif self.path == "/close":
            self.engine.close()
            self._json_response({"status": self.engine.state.phase})

        else:
            self.send_error(404)

    def _json_response(self, data):
        body = json.dumps(data).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body)


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8091)
    parser.add_argument("--hand-port", default="/dev/ttyUSB0")
    # Motor config will come from Ruka hand specs
    parser.add_argument("--no-hand", action="store_true", help="Run without hand connected")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(name)s] %(levelname)s: %(message)s")

    motor_config = {} if args.no_hand else {
        # Placeholder — update with actual Ruka motor IDs
        "thumb": 1,
        "index": 2,
        "middle": 3,
        "ring": 4,
        "pinky": 5,
    }

    engine = GraspEngine(hand_port=args.hand_port, motor_config=motor_config)
    GraspHandler.engine = engine
    engine.start()

    server = HTTPServer(("0.0.0.0", args.port), GraspHandler)
    logger.info(f"⚡ Grasp engine API on http://0.0.0.0:{args.port}")

    import signal
    signal.signal(signal.SIGINT, lambda *_: (engine.stop(), sys.exit(0)))
    signal.signal(signal.SIGTERM, lambda *_: (engine.stop(), sys.exit(0)))

    while True:
        server.handle_request()


if __name__ == "__main__":
    import sys
    main()
