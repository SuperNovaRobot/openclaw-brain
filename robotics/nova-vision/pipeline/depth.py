"""
Depth Configurator — Stereo depth pipeline setup for OAK-D Pro PoE.
"""

import depthai as dai
import logging

logger = logging.getLogger("nova_vision.depth")

PRESET_MAP = {
    "ROBOTICS": dai.node.StereoDepth.PresetMode.ROBOTICS,
    "HIGH_DENSITY": dai.node.StereoDepth.PresetMode.HIGH_DENSITY,
    "HIGH_DETAIL": dai.node.StereoDepth.PresetMode.HIGH_DETAIL,
    "FACE": dai.node.StereoDepth.PresetMode.FACE,
    "DEFAULT": dai.node.StereoDepth.PresetMode.DEFAULT,
}

MEDIAN_MAP = {
    "MEDIAN_OFF": dai.MedianFilter.MEDIAN_OFF,
    "KERNEL_3x3": dai.MedianFilter.KERNEL_3x3,
    "KERNEL_5x5": dai.MedianFilter.KERNEL_5x5,
    "KERNEL_7x7": dai.MedianFilter.KERNEL_7x7,
}


class DepthConfigurator:
    """Configures stereo depth on the OAK-D Pro PoE pipeline."""

    def __init__(self, config: dict):
        self.config = config
        self.depth_config = config.get("depth", {})
        self.stereo_node = None

    def configure(self, pipeline: dai.Pipeline) -> dai.node.StereoDepth:
        """Add and configure StereoDepth node on the pipeline."""
        if not self.depth_config.get("enabled", True):
            logger.info("Depth disabled in config")
            return None

        stereo = pipeline.create(dai.node.StereoDepth)

        # Preset
        preset_name = self.depth_config.get("preset", "ROBOTICS")
        preset = PRESET_MAP.get(preset_name, PRESET_MAP["ROBOTICS"])
        stereo.setDefaultProfilePreset(preset)
        logger.info(f"Depth preset: {preset_name}")

        # Median filter
        median_name = self.depth_config.get("median_filter", "KERNEL_5x5")
        median = MEDIAN_MAP.get(median_name, dai.MedianFilter.KERNEL_5x5)
        stereo.initialConfig.setMedianFilter(median)

        # Core settings
        stereo.setLeftRightCheck(self.depth_config.get("left_right_check", True))
        stereo.setSubpixel(self.depth_config.get("subpixel", True))
        stereo.setExtendedDisparity(self.depth_config.get("extended_disparity", False))

        # Confidence
        ct = self.depth_config.get("confidence_threshold", 200)
        stereo.initialConfig.setConfidenceThreshold(ct)

        # Align to RGB
        if self.depth_config.get("align_to_rgb", True):
            stereo.setDepthAlign(dai.CameraBoardSocket.CAM_A)

        # Post-processing filters
        if self.depth_config.get("speckle_filter", True):
            stereo.initialConfig.postProcessing.speckleFilter.enable = True
            stereo.initialConfig.postProcessing.speckleFilter.speckleRange = \
                self.depth_config.get("speckle_range", 50)

        if self.depth_config.get("temporal_filter", False):
            stereo.initialConfig.postProcessing.temporalFilter.enable = True

        if self.depth_config.get("spatial_filter", True):
            stereo.initialConfig.postProcessing.spatialFilter.enable = True

        # Link mono cameras
        mono_left = pipeline._nova_mono_left
        mono_right = pipeline._nova_mono_right
        mono_left.out.link(stereo.left)
        mono_right.out.link(stereo.right)

        # Output size matches mono resolution
        stereo.setOutputSize(mono_left.getResolutionWidth(), mono_left.getResolutionHeight())

        self.stereo_node = stereo
        pipeline._nova_stereo = stereo

        logger.info("✅ Stereo depth configured")
        return stereo

    def create_depth_queue(self, pipeline: dai.Pipeline, camera_mgr):
        """Create depth output queue."""
        if self.stereo_node is not None:
            camera_mgr.queues["depth"] = self.stereo_node.depth.createOutputQueue(
                maxSize=1, blocking=False
            )
