"""
Depth and image transforms.
"""

import numpy as np
from typing import Tuple


class DepthTransforms:
    """Utility transforms for depth data."""

    @staticmethod
    def depth_to_colormap(depth_frame: np.ndarray, min_depth_mm: int = 200,
                          max_depth_mm: int = 10000) -> np.ndarray:
        """Convert depth frame to color visualization."""
        import cv2
        depth = depth_frame.copy().astype(np.float32)
        depth[depth == 0] = max_depth_mm  # invalid → far
        depth = np.clip(depth, min_depth_mm, max_depth_mm)
        normalized = ((depth - min_depth_mm) / (max_depth_mm - min_depth_mm) * 255).astype(np.uint8)
        return cv2.applyColorMap(normalized, cv2.COLORMAP_JET)

    @staticmethod
    def pixel_to_3d(x: int, y: int, depth_mm: float,
                    fx: float, fy: float, cx: float, cy: float) -> Tuple[float, float, float]:
        """Convert pixel + depth to 3D coordinates (mm)."""
        z = depth_mm
        x_3d = (x - cx) * z / fx
        y_3d = (y - cy) * z / fy
        return (x_3d, y_3d, z)

    @staticmethod
    def get_depth_at_roi(depth_frame: np.ndarray, bbox: Tuple[float, float, float, float],
                         frame_w: int, frame_h: int) -> float:
        """Get average depth in a bounding box region."""
        x1 = int(bbox[0] * frame_w)
        y1 = int(bbox[1] * frame_h)
        x2 = int(bbox[2] * frame_w)
        y2 = int(bbox[3] * frame_h)

        x1, x2 = max(0, x1), min(frame_w, x2)
        y1, y2 = max(0, y1), min(frame_h, y2)

        if x2 <= x1 or y2 <= y1:
            return 0.0

        roi = depth_frame[y1:y2, x1:x2]
        valid = roi[roi > 0]
        return float(np.median(valid)) if len(valid) > 0 else 0.0
