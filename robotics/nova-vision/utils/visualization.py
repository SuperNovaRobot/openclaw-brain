"""
Visualization utilities for debugging (optional, headless-friendly).
"""

import numpy as np
import cv2
from typing import List, Optional
import logging

logger = logging.getLogger("nova_vision.viz")


class Visualizer:
    """Draw detections and depth on frames. Used for debugging only."""

    @staticmethod
    def draw_detections(frame: np.ndarray, detections: list,
                        labels: Optional[list] = None) -> np.ndarray:
        """Draw bounding boxes and labels on frame."""
        h, w = frame.shape[:2]
        out = frame.copy()

        for det in detections:
            x1 = int(det.bbox[0] * w)
            y1 = int(det.bbox[1] * h)
            x2 = int(det.bbox[2] * w)
            y2 = int(det.bbox[3] * h)

            color = (0, 255, 0) if det.label == "person" else (255, 0, 0)
            cv2.rectangle(out, (x1, y1), (x2, y2), color, 2)

            label_text = f"{det.label} {det.confidence:.0%}"
            cv2.putText(out, label_text, (x1, y1 - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1)

            if det.spatial_z > 0:
                dist_text = f"{det.spatial_z / 1000:.1f}m"
                cv2.putText(out, dist_text, (x1, y2 + 20),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1)

            if det.tracker_id >= 0:
                id_text = f"ID:{det.tracker_id}"
                cv2.putText(out, id_text, (x1, y1 - 25),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0, 255, 255), 1)

        return out

    @staticmethod
    def save_frame(frame: np.ndarray, path: str):
        """Save frame to file."""
        cv2.imwrite(path, frame)
