"""
Detection Pipeline — Object detection with spatial awareness on Myriad X VPU.
Supports YoloSpatialDetectionNetwork and MobileNetSpatialDetectionNetwork.
"""

import depthai as dai
import logging
from dataclasses import dataclass, field
from typing import List, Optional, Tuple
from pathlib import Path

logger = logging.getLogger("nova_vision.detection")


@dataclass
class Detection:
    """A single detected object with spatial coordinates."""
    label: str
    label_id: int
    confidence: float
    bbox: Tuple[float, float, float, float]  # xmin, ymin, xmax, ymax (normalized)
    spatial_x: float = 0.0  # mm
    spatial_y: float = 0.0  # mm
    spatial_z: float = 0.0  # mm (distance)
    tracker_id: int = -1
    tracker_status: str = ""


@dataclass
class DetectionResult:
    """All detections from a single frame."""
    detections: List[Detection] = field(default_factory=list)
    timestamp: float = 0.0
    inference_fps: float = 0.0

    @property
    def persons(self) -> List[Detection]:
        return [d for d in self.detections if d.label == "person"]

    @property
    def objects(self) -> List[Detection]:
        return [d for d in self.detections if d.label != "person"]

    def find(self, label: str) -> List[Detection]:
        return [d for d in self.detections if d.label == label]

    def nearest(self) -> Optional[Detection]:
        valid = [d for d in self.detections if d.spatial_z > 0]
        return min(valid, key=lambda d: d.spatial_z) if valid else None


class DetectionPipeline:
    """Configures object detection on the VPU with spatial awareness."""

    def __init__(self, config: dict):
        self.config = config
        self.det_config = config.get("detection", {})
        self.track_config = config.get("tracking", {})
        self.labels = self.det_config.get("labels", [])
        self.det_node = None
        self.tracker_node = None

    def configure(self, pipeline: dai.Pipeline) -> Optional[dai.node.YoloSpatialDetectionNetwork]:
        """Add detection network to pipeline."""
        if not self.det_config.get("enabled", True):
            logger.info("Detection disabled in config")
            return None

        blob_path = self.det_config.get("blob_path", "")
        if not Path(blob_path).exists():
            # Try relative to project dir
            project_dir = Path(__file__).parent.parent
            blob_path = str(project_dir / blob_path)

        if not Path(blob_path).exists():
            logger.warning(f"Model blob not found: {blob_path}")
            logger.warning("Detection disabled — download model first (see models/README.md)")
            return None

        model_type = self.det_config.get("model", "yolov8n")
        spatial = self.det_config.get("spatial", True)

        if "yolo" in model_type.lower():
            det_nn = self._configure_yolo(pipeline, blob_path, spatial)
        else:
            det_nn = self._configure_mobilenet(pipeline, blob_path, spatial)

        self.det_node = det_nn

        # Link RGB preview to detection input
        rgb = pipeline._nova_rgb
        rgb.preview.link(det_nn.input)

        # Link depth if spatial
        if spatial and hasattr(pipeline, '_nova_stereo') and pipeline._nova_stereo:
            pipeline._nova_stereo.depth.link(det_nn.inputDepth)

        # Object tracker
        if self.track_config.get("enabled", False):
            self._configure_tracker(pipeline, det_nn, rgb)

        pipeline._nova_detection = det_nn
        logger.info(f"✅ Detection configured: {model_type} (spatial={spatial})")
        return det_nn

    def _configure_yolo(self, pipeline, blob_path, spatial):
        """Configure YOLO spatial detection network."""
        if spatial:
            det_nn = pipeline.create(dai.node.YoloSpatialDetectionNetwork)
            det_nn.setBoundingBoxScaleFactor(self.det_config.get("spatial_bbox_scale", 0.5))
            det_nn.setDepthLowerThreshold(self.det_config.get("depth_lower_threshold", 100))
            det_nn.setDepthUpperThreshold(self.det_config.get("depth_upper_threshold", 10000))
        else:
            det_nn = pipeline.create(dai.node.YoloDetectionNetwork)

        det_nn.setBlobPath(blob_path)
        det_nn.setConfidenceThreshold(self.det_config.get("confidence_threshold", 0.5))
        det_nn.input.setBlocking(False)
        det_nn.input.setQueueSize(1)  # Drop stale frames, reduce latency per Luxonis docs

        # YOLO parameters
        det_nn.setNumClasses(self.det_config.get("num_classes", 80))
        det_nn.setCoordinateSize(4)

        # YOLOv8n anchors (anchor-free uses these defaults)
        model = self.det_config.get("model", "yolov8n")
        if "v4" in model or "v3" in model:
            det_nn.setAnchors([10, 14, 23, 27, 37, 58, 81, 82, 135, 169, 344, 319])
            det_nn.setAnchorMasks({"side26": [1, 2, 3], "side13": [3, 4, 5]})
        # YOLOv8 is anchor-free — anchors not needed

        det_nn.setIouThreshold(self.det_config.get("iou_threshold", 0.5))
        return det_nn

    def _configure_mobilenet(self, pipeline, blob_path, spatial):
        """Configure MobileNet spatial detection network."""
        if spatial:
            det_nn = pipeline.create(dai.node.MobileNetSpatialDetectionNetwork)
            det_nn.setBoundingBoxScaleFactor(self.det_config.get("spatial_bbox_scale", 0.5))
            det_nn.setDepthLowerThreshold(self.det_config.get("depth_lower_threshold", 100))
            det_nn.setDepthUpperThreshold(self.det_config.get("depth_upper_threshold", 10000))
        else:
            det_nn = pipeline.create(dai.node.MobileNetDetectionNetwork)

        det_nn.setBlobPath(blob_path)
        det_nn.setConfidenceThreshold(self.det_config.get("confidence_threshold", 0.5))
        det_nn.input.setBlocking(False)
        det_nn.input.setQueueSize(1)
        return det_nn

    def _configure_tracker(self, pipeline, det_nn, rgb):
        """Configure object tracker."""
        tracker = pipeline.create(dai.node.ObjectTracker)

        tracker_type_map = {
            "ZERO_TERM_COLOR_HISTOGRAM": dai.TrackerType.ZERO_TERM_COLOR_HISTOGRAM,
            "ZERO_TERM_IMAGELESS": dai.TrackerType.ZERO_TERM_IMAGELESS,
            "SHORT_TERM_IMAGELESS": dai.TrackerType.SHORT_TERM_IMAGELESS,
            "SHORT_TERM_KCF": dai.TrackerType.SHORT_TERM_KCF,
        }
        tt = self.track_config.get("tracker_type", "ZERO_TERM_IMAGELESS")
        tracker.setTrackerType(tracker_type_map.get(tt, dai.TrackerType.ZERO_TERM_IMAGELESS))

        track_labels = self.track_config.get("track_labels", [0])
        tracker.setDetectionLabelsToTrack(track_labels)
        tracker.setMaxObjectsToTrack(self.track_config.get("max_objects", 20))

        id_policy_map = {
            "SMALLEST_ID": dai.TrackerIdAssignmentPolicy.SMALLEST_ID,
            "UNIQUE_ID": dai.TrackerIdAssignmentPolicy.UNIQUE_ID,
        }
        id_pol = self.track_config.get("id_policy", "SMALLEST_ID")
        tracker.setTrackerIdAssignmentPolicy(id_policy_map.get(id_pol, dai.TrackerIdAssignmentPolicy.SMALLEST_ID))

        # Link
        det_nn.passthrough.link(tracker.inputTrackerFrame)
        det_nn.passthrough.link(tracker.inputDetectionFrame)
        det_nn.out.link(tracker.inputDetections)

        self.tracker_node = tracker
        pipeline._nova_tracker = tracker
        logger.info(f"✅ Object tracker configured: {tt}")

    def create_queues(self, pipeline, camera_mgr):
        """Create output queues for detection results."""
        if self.det_node is not None:
            camera_mgr.queues["detections"] = self.det_node.out.createOutputQueue(
                maxSize=1, blocking=False
            )
        if self.tracker_node is not None:
            camera_mgr.queues["tracklets"] = self.tracker_node.out.createOutputQueue(
                maxSize=1, blocking=False
            )

    def parse_detections(self, det_msg, tracklets_msg=None) -> DetectionResult:
        """Parse raw detection message into structured DetectionResult."""
        result = DetectionResult()

        if det_msg is None:
            return result

        for det in det_msg.detections:
            label_id = det.label
            label = self.labels[label_id] if label_id < len(self.labels) else str(label_id)

            d = Detection(
                label=label,
                label_id=label_id,
                confidence=det.confidence,
                bbox=(det.xmin, det.ymin, det.xmax, det.ymax),
                spatial_x=getattr(det.spatialCoordinates, 'x', 0) if hasattr(det, 'spatialCoordinates') else 0,
                spatial_y=getattr(det.spatialCoordinates, 'y', 0) if hasattr(det, 'spatialCoordinates') else 0,
                spatial_z=getattr(det.spatialCoordinates, 'z', 0) if hasattr(det, 'spatialCoordinates') else 0,
            )
            result.detections.append(d)

        # Merge tracker info if available
        if tracklets_msg is not None:
            tracked = []
            for t in tracklets_msg.tracklets:
                label_id = t.label
                label = self.labels[label_id] if label_id < len(self.labels) else str(label_id)
                d = Detection(
                    label=label,
                    label_id=label_id,
                    confidence=0.0,
                    bbox=(t.roi.x, t.roi.y, t.roi.x + t.roi.width, t.roi.y + t.roi.height),
                    spatial_x=getattr(t.spatialCoordinates, 'x', 0) if hasattr(t, 'spatialCoordinates') else 0,
                    spatial_y=getattr(t.spatialCoordinates, 'y', 0) if hasattr(t, 'spatialCoordinates') else 0,
                    spatial_z=getattr(t.spatialCoordinates, 'z', 0) if hasattr(t, 'spatialCoordinates') else 0,
                    tracker_id=t.id,
                    tracker_status=t.status.name if hasattr(t.status, 'name') else str(t.status),
                )
                tracked.append(d)
            # If we have tracklets, prefer them for tracked labels
            if tracked:
                result.detections = [d for d in result.detections
                                     if d.label_id not in self.track_config.get("track_labels", [])]
                result.detections.extend(tracked)

        return result
