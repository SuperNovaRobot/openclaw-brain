"""
Spatial Analyzer — Navigation awareness and proxemic zone detection.
Processes depth maps for obstacle avoidance and spatial understanding.
"""

import numpy as np
import logging
from dataclasses import dataclass, field
from typing import Dict, List, Optional

logger = logging.getLogger("nova_vision.spatial")


@dataclass
class NavigationPath:
    """Navigable path analysis."""
    left_clearance: float = 0.0    # meters
    center_clearance: float = 0.0
    right_clearance: float = 0.0
    best_direction: str = "center"
    safe_to_move: bool = False
    obstacle_distance: float = float('inf')


@dataclass
class SpatialState:
    """Complete spatial awareness state."""
    nearest_distance: float = float('inf')  # meters
    average_distance: float = 0.0
    intimate_space_alert: bool = False   # < 0.45m
    personal_space_occupied: bool = False  # 0.45-1.2m
    social_activity: bool = False         # 1.2-3.6m
    navigation: NavigationPath = field(default_factory=NavigationPath)
    valid: bool = False


class SpatialAnalyzer:
    """Analyzes depth maps for spatial awareness."""

    def __init__(self, config: dict):
        self.config = config
        self.spatial_config = config.get("spatial", {})
        self.intimate_dist = self.spatial_config.get("intimate_distance", 0.45)
        self.personal_dist = self.spatial_config.get("personal_distance", 1.2)
        self.social_dist = self.spatial_config.get("social_distance", 3.6)
        self.obstacle_dist = self.spatial_config.get("obstacle_distance", 0.5)
        self.n_sectors = self.spatial_config.get("navigation_sectors", 3)

    def analyze(self, depth_frame: np.ndarray) -> SpatialState:
        """Analyze depth frame for spatial awareness."""
        if depth_frame is None:
            return SpatialState()

        state = SpatialState(valid=True)

        # Convert to meters
        depth_m = depth_frame.astype(np.float32) / 1000.0
        valid = depth_m[depth_m > 0]

        if len(valid) == 0:
            return SpatialState()

        state.nearest_distance = float(np.min(valid))
        state.average_distance = float(np.mean(valid))

        # Proxemic zones
        state.intimate_space_alert = bool(np.any((depth_m > 0) & (depth_m < self.intimate_dist)))
        state.personal_space_occupied = bool(
            np.sum((depth_m >= self.intimate_dist) & (depth_m < self.personal_dist)) > 100
        )
        state.social_activity = bool(
            np.sum((depth_m >= self.personal_dist) & (depth_m < self.social_dist)) > 500
        )

        # Navigation
        state.navigation = self._analyze_navigation(depth_m)

        return state

    def _analyze_navigation(self, depth_m: np.ndarray) -> NavigationPath:
        """Analyze navigable paths."""
        h, w = depth_m.shape
        nav = NavigationPath()

        sector_w = w // self.n_sectors
        sectors = []
        for i in range(self.n_sectors):
            sector = depth_m[:, i * sector_w:(i + 1) * sector_w]
            valid = sector[sector > 0]
            clearance = float(np.mean(valid)) if len(valid) > 0 else 0.0
            sectors.append(clearance)

        if len(sectors) >= 3:
            nav.left_clearance = sectors[0]
            nav.center_clearance = sectors[1]
            nav.right_clearance = sectors[2]
        elif len(sectors) > 0:
            nav.center_clearance = sectors[0]

        # Determine best direction
        max_clearance = max(sectors) if sectors else 0
        if max_clearance > 0:
            idx = sectors.index(max_clearance)
            nav.best_direction = ["left", "center", "right"][min(idx, 2)]

        # Find nearest obstacle
        valid_all = depth_m[depth_m > 0]
        if len(valid_all) > 0:
            nav.obstacle_distance = float(np.min(valid_all))
            nav.safe_to_move = nav.obstacle_distance > self.obstacle_dist

        return nav

    def describe(self, state: SpatialState) -> str:
        """Generate human-readable spatial description."""
        if not state.valid:
            return "No depth data available."

        parts = []

        if state.intimate_space_alert:
            parts.append(f"⚠️ Something very close at {state.nearest_distance:.1f}m!")
        elif state.personal_space_occupied:
            parts.append(f"Object in personal space at {state.nearest_distance:.1f}m.")
        elif state.nearest_distance < 3.0:
            parts.append(f"Nearest object at {state.nearest_distance:.1f}m.")

        nav = state.navigation
        if nav.safe_to_move:
            parts.append(f"Clear path {nav.best_direction} ({nav.center_clearance:.1f}m ahead).")
        else:
            parts.append(f"Obstacle at {nav.obstacle_distance:.1f}m — not safe to move forward.")

        return " ".join(parts) if parts else f"Clear space, average distance {state.average_distance:.1f}m."
