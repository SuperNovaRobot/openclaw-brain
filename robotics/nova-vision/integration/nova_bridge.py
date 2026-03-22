"""
Nova Bridge — Aggregates all vision pipeline outputs into a unified perception state.
Provides the interface between the vision system and Nova's main AI/conversation system.
"""

import json
import time
import logging
import numpy as np
import cv2
from dataclasses import dataclass, field, asdict
from typing import Dict, List, Optional, Any
from datetime import datetime

logger = logging.getLogger("nova_vision.bridge")


@dataclass
class SceneAnalysis:
    """Scene-level analysis."""
    brightness: float = 0.0
    lighting: str = "unknown"  # scotopic, mesopic, photopic
    color_temperature: str = "neutral"  # warm, cool, neutral
    motion_detected: bool = False
    motion_level: float = 0.0


@dataclass
class PerceptionState:
    """Complete perception state from all vision subsystems."""
    timestamp: str = ""
    fps: float = 0.0
    # Scene
    scene: SceneAnalysis = field(default_factory=SceneAnalysis)
    # Detections
    detections: List[Dict] = field(default_factory=list)
    persons_count: int = 0
    nearest_person_distance: float = 0.0
    nearest_object: str = ""
    nearest_object_distance: float = 0.0
    # Spatial
    nearest_distance: float = 0.0
    safe_to_move: bool = True
    best_direction: str = "center"
    intimate_space_alert: bool = False
    # Faces
    faces_count: int = 0
    recognized_faces: List[str] = field(default_factory=list)

    def to_json(self) -> str:
        return json.dumps(asdict(self), indent=2)

    def to_dict(self) -> dict:
        return asdict(self)


class NovaBridge:
    """Bridge between vision system and Nova's main system."""

    def __init__(self, config: dict):
        self.config = config
        self._prev_frame = None
        self._frame_count = 0
        self._start_time = time.time()
        self._last_perception: Optional[PerceptionState] = None

    def build_perception(self, frame=None, depth_frame=None,
                         detection_result=None, spatial_state=None,
                         face_result=None) -> PerceptionState:
        """Build unified perception state from all subsystem outputs."""
        now = time.time()
        self._frame_count += 1
        elapsed = now - self._start_time
        fps = self._frame_count / elapsed if elapsed > 0 else 0

        # Reset FPS counter every 5 seconds
        if elapsed > 5:
            self._frame_count = 0
            self._start_time = now

        state = PerceptionState(
            timestamp=datetime.now().isoformat(),
            fps=round(fps, 1),
        )

        # Scene analysis from RGB frame
        if frame is not None:
            state.scene = self._analyze_scene(frame)

        # Detections
        if detection_result is not None:
            for d in detection_result.detections:
                state.detections.append({
                    "label": d.label,
                    "confidence": round(d.confidence, 2),
                    "distance_m": round(d.spatial_z / 1000, 2) if d.spatial_z > 0 else None,
                    "position": {
                        "x_mm": round(d.spatial_x),
                        "y_mm": round(d.spatial_y),
                        "z_mm": round(d.spatial_z),
                    } if d.spatial_z > 0 else None,
                    "tracker_id": d.tracker_id if d.tracker_id >= 0 else None,
                })

            persons = detection_result.persons
            state.persons_count = len(persons)
            if persons:
                nearest_p = min(persons, key=lambda p: p.spatial_z if p.spatial_z > 0 else float('inf'))
                state.nearest_person_distance = round(nearest_p.spatial_z / 1000, 2) if nearest_p.spatial_z > 0 else 0

            nearest = detection_result.nearest()
            if nearest:
                state.nearest_object = nearest.label
                state.nearest_object_distance = round(nearest.spatial_z / 1000, 2)

        # Spatial awareness
        if spatial_state is not None and spatial_state.valid:
            state.nearest_distance = round(spatial_state.nearest_distance, 2)
            state.safe_to_move = spatial_state.navigation.safe_to_move
            state.best_direction = spatial_state.navigation.best_direction
            state.intimate_space_alert = spatial_state.intimate_space_alert

        # Faces
        if face_result is not None:
            state.faces_count = len(face_result.faces)
            state.recognized_faces = [f.identity for f in face_result.faces if f.identity != "unknown"]

        self._last_perception = state
        return state

    def _analyze_scene(self, frame: np.ndarray) -> SceneAnalysis:
        """Quick scene analysis from RGB frame."""
        scene = SceneAnalysis()
        brightness = float(np.mean(frame))
        scene.brightness = round(brightness, 1)

        if brightness < 50:
            scene.lighting = "scotopic"
        elif brightness < 100:
            scene.lighting = "mesopic"
        else:
            scene.lighting = "photopic"

        avg = np.mean(frame, axis=(0, 1))
        b, g, r = avg[0], avg[1], avg[2]
        if r > g and r > b:
            scene.color_temperature = "warm"
        elif b > r and b > g:
            scene.color_temperature = "cool"
        else:
            scene.color_temperature = "neutral"

        # Motion detection
        if self._prev_frame is not None:
            try:
                diff = cv2.absdiff(frame, self._prev_frame)
                motion = float(np.mean(diff))
                scene.motion_level = round(motion, 1)
                scene.motion_detected = motion > 10
            except Exception:
                pass
        self._prev_frame = frame.copy()

        return scene

    def describe_scene(self) -> str:
        """Generate natural language scene description for Nova's conversation system."""
        state = self._last_perception
        if state is None:
            return "I haven't processed any visual data yet."

        parts = []

        # Scene description
        s = state.scene
        if s.lighting == "scotopic":
            parts.append("It's very dark.")
        elif s.lighting == "mesopic":
            parts.append("It's dimly lit.")
        else:
            parts.append(f"The area is well-lit with {s.color_temperature} tones.")

        # People
        if state.persons_count > 0:
            if state.persons_count == 1:
                dist = state.nearest_person_distance
                parts.append(f"I see one person about {dist:.1f} meters away." if dist > 0 else "I see one person.")
            else:
                parts.append(f"I see {state.persons_count} people.")

        # Objects
        objects = [d for d in state.detections if d["label"] != "person"]
        if objects:
            obj_names = list(set(d["label"] for d in objects))[:5]
            parts.append(f"I can see: {', '.join(obj_names)}.")

        # Spatial
        if state.intimate_space_alert:
            parts.append(f"⚠️ Something is very close at {state.nearest_distance:.1f}m!")

        if not state.safe_to_move:
            parts.append("Path is blocked.")

        if s.motion_detected:
            parts.append("I detect movement.")

        return " ".join(parts) if parts else "The scene is clear."

    def take_snapshot(self, frame: np.ndarray, path: str = None) -> str:
        """Save a snapshot and return the path."""
        if frame is None:
            return ""
        if path is None:
            ts = datetime.now().strftime("%Y%m%d_%H%M%S")
            path = f"/tmp/nova_vision/snapshot_{ts}.jpg"

        import os
        os.makedirs(os.path.dirname(path), exist_ok=True)
        cv2.imwrite(path, frame)
        return path
