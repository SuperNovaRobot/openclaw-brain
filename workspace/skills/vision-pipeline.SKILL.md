# Vision Pipeline (OAK-D Pro)

## Hardware
**OAK-D Pro**: depth + RGB + on-device AI via USB3 to nova (Jetson Orin).
- RGB: 12MP IMX378 (4K capable)
- Stereo: 1MP OV9282 global shutter pair
- IR: active dot projector for low-light depth
- VPU: Intel Movidius Myriad X (4 TOPS)

## Connection
- USB3 to nova Jetson Orin
- DepthAI SDK inside Docker (never system Python)
- Docker container needs `--device /dev/bus/usb` or `--privileged`

## Calibration
1. Print 9x6 checkerboard pattern (25mm squares) on rigid board
2. Hold at 10+ positions covering the full field of view
3. Run: `depthai calibrate --board CHARUCO_9x6 --squareSize 25`
4. Verify depth accuracy: < 2% error at 1m, < 5% at 3m
5. Store calibration file at workspace/calibration/oakd-calib.json
6. Re-calibrate after any physical mounting change

## Pipeline Stages

| Stage | Input | Output | On-Device |
|-------|-------|--------|-----------|
| Capture | USB stream | RGB + stereo frames | Yes |
| Depth Map | Stereo pair + IR | Disparity/depth map | Yes |
| Object Detection | RGB frame | Bounding boxes + labels | Yes (YOLO) |
| Pose Estimation | RGB + depth | 6DOF object poses | Partial |
| Point Cloud | Depth map | 3D point cloud | No (host) |
| Scene Reconstruction | Point cloud + poses | Environment model | No (host) |

## Integration
- Depth data feeds into [[robotics-simulation.SKILL]] for collision avoidance
- Object poses feed into [[arm-control.SKILL]] for grasp planning
- Scene data logged to Obsidian robots/ for spatial memory
- Visual anomalies logged to Memos #vision-anomaly

## Safety
- Camera must be verified working before ANY arm commands
- If depth stream drops, halt all arm movement immediately
- Minimum 15 FPS depth stream required for real-time operation
- Object detection confidence threshold: 0.7 minimum for action

## Commands

| Command | Description |
|---------|-------------|
| `capture_rgb()` | Single RGB frame |
| `capture_depth()` | Single depth map |
| `capture_stereo()` | Synchronized RGB + depth |
| `detect_objects()` | Run detection pipeline, return boxes + labels |
| `estimate_pose(object_id)` | Get 6DOF pose of detected object |
| `get_pointcloud()` | Generate 3D point cloud from current depth |
| `calibrate()` | Run calibration sequence |
| `get_camera_info()` | Get intrinsics, extrinsics, status |

## Rules
- Never send arm commands without verified camera feed
- All captures timestamped and logged for replay
- Calibration data version-controlled in workspace/calibration/
- DepthAI runs inside Docker — not on system Python
