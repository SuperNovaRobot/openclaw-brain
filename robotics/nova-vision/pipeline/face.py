"""
Face Processor — Face detection and recognition on Jetson GPU.
This module runs on the host (Jetson) rather than the VPU.
"""

import logging
import numpy as np
from dataclasses import dataclass, field
from typing import List, Optional, Tuple
from pathlib import Path

logger = logging.getLogger("nova_vision.face")


@dataclass
class FaceDetection:
    """A detected face."""
    bbox: Tuple[int, int, int, int]  # x1, y1, x2, y2 in pixels
    confidence: float
    identity: str = "unknown"
    identity_confidence: float = 0.0


@dataclass
class FaceResult:
    """All face detections from a single frame."""
    faces: List[FaceDetection] = field(default_factory=list)
    timestamp: float = 0.0


class FaceProcessor:
    """Face detection and recognition using Jetson GPU."""

    def __init__(self, config: dict):
        self.config = config
        self.face_config = config.get("face", {})
        self.enabled = self.face_config.get("enabled", False)
        self._detector = None
        self._recognizer = None
        self._known_embeddings = {}

        if self.enabled:
            self._initialize()

    def _initialize(self):
        """Initialize face detection/recognition models."""
        det_path = self.face_config.get("model_path", "")
        if not Path(det_path).exists():
            project_dir = Path(__file__).parent.parent
            det_path = str(project_dir / det_path)

        if not Path(det_path).exists():
            logger.warning(f"Face detection model not found: {det_path}")
            logger.warning("Face processing disabled — download model first")
            self.enabled = False
            return

        try:
            # Try to load with OpenCV DNN or ONNX Runtime
            import cv2
            self._detector = cv2.dnn.readNetFromONNX(det_path)
            # Prefer CUDA backend on Jetson
            self._detector.setPreferableBackend(cv2.dnn.DNN_BACKEND_CUDA)
            self._detector.setPreferableTarget(cv2.dnn.DNN_TARGET_CUDA)
            logger.info("✅ Face detection initialized (CUDA)")
        except Exception as e:
            logger.warning(f"Face detection init failed: {e}")
            try:
                self._detector = cv2.dnn.readNetFromONNX(det_path)
                logger.info("✅ Face detection initialized (CPU fallback)")
            except Exception as e2:
                logger.error(f"Face detection completely failed: {e2}")
                self.enabled = False

    def process(self, frame: np.ndarray) -> FaceResult:
        """Detect faces in a frame."""
        result = FaceResult()
        if not self.enabled or self._detector is None or frame is None:
            return result

        try:
            import cv2
            h, w = frame.shape[:2]
            blob = cv2.dnn.blobFromImage(frame, 1.0 / 255, (320, 320), swapRB=True, crop=False)
            self._detector.setInput(blob)
            output = self._detector.forward()

            conf_thresh = self.face_config.get("confidence_threshold", 0.6)

            # Parse detections (format depends on model)
            # This is a template — actual parsing depends on the specific model used
            if output is not None and len(output.shape) >= 2:
                for detection in output[0]:
                    if len(detection) >= 5:
                        confidence = float(detection[4])
                        if confidence > conf_thresh:
                            x1 = int(detection[0] * w)
                            y1 = int(detection[1] * h)
                            x2 = int(detection[2] * w)
                            y2 = int(detection[3] * h)
                            result.faces.append(FaceDetection(
                                bbox=(x1, y1, x2, y2),
                                confidence=confidence,
                            ))

        except Exception as e:
            logger.debug(f"Face processing error: {e}")

        return result

    def describe(self, result: FaceResult) -> str:
        """Describe face detection results."""
        if not result.faces:
            return ""
        n = len(result.faces)
        known = [f for f in result.faces if f.identity != "unknown"]
        if known:
            names = ", ".join(f.identity for f in known)
            return f"I see {n} face(s): {names}."
        return f"I see {n} face(s)."
