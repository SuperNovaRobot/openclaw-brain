# Nova Vision System

Complete vision system for the Nova humanoid robot, built on **OAK-D Pro PoE** camera with **NVIDIA Jetson Orin 64GB**.

## Architecture

```
OAK-D Pro PoE (Myriad X VPU)          Jetson Orin 64GB
┌─────────────────────────────┐       ┌─────────────────────┐
│ Color Camera (IMX378)       │       │                     │
│ Stereo Mono Pair (OV9282)   │──PoE──│ Host Processing     │
│ IR Dot Projector             │       │ - Face Detection    │
│ IR Flood LED                 │       │ - Scene Analysis    │
│                              │       │ - Motion Detection  │
│ On-VPU Processing:           │       │ - Nova Bridge       │
│ - YOLOv8n Detection          │       │                     │
│ - Stereo Depth               │       │ Output:             │
│ - Spatial Coordinates         │       │ - JSON perception   │
│ - Object Tracking            │       │ - Natural language   │
└─────────────────────────────┘       └─────────────────────┘
```

## Quick Start

```bash
# The workspace isn't mounted in glm-server by default.
# Option 1: Copy project into the container's mounted volume
cp -r /home/nova/.openclaw/workspace/nova_vision /mnt/ssd/models/nova_vision

# Option 2: Add a volume mount to glm-server (requires container restart)
# docker ... -v /home/nova/.openclaw/workspace:/workspace ...

# Enter the runtime container
docker exec -it glm-server bash

# Navigate to project
cd /models/nova_vision  # if using Option 1

# Download models (first time)
pip install blobconverter
python3 -c "
import blobconverter
blobconverter.from_zoo(name='yolov8n_coco_416x416', zoo_type='depthai', shaves=6,
                       output_dir='models/')
"

# Run
python3 main.py

# Quick test (10 seconds)
python3 main.py --test

# Take a snapshot
python3 main.py --snapshot

# Describe what Nova sees
python3 main.py --describe
```

## Features

| Feature | Where | FPS |
|---------|-------|-----|
| Object Detection (80 COCO classes) | VPU | ~30 |
| Spatial 3D Coordinates | VPU | ~30 |
| Stereo Depth | VPU | ~30 |
| Object Tracking | VPU | ~30 |
| Face Detection | Jetson GPU | ~15 |
| Scene Analysis | Jetson CPU | ~30 |
| Motion Detection | Jetson CPU | ~30 |

## Configuration

All settings in `config.yaml`. Key options:

- **Camera**: FPS, resolution, PoE IP
- **Depth**: Preset, filters, range
- **Detection**: Model, confidence, spatial mode
- **Tracking**: Type, tracked labels
- **Face**: Enable/disable, models
- **Spatial**: Proxemic zones, obstacle distance

## Model Recommendations

| Use Case | Model | Run On | Format |
|----------|-------|--------|--------|
| Object Detection | YOLOv8n 416x416 | Myriad X VPU | .blob |
| Person Detection | MobileNet-SSD 300x300 | Myriad X VPU | .blob |
| Face Detection | SCRFD / RetinaFace | Jetson GPU | ONNX |
| Face Recognition | ArcFace | Jetson GPU | ONNX |

**Why this split?**
- VPU: 1.4 TOPS, perfect for lightweight detection models. Runs in parallel with Jetson.
- Jetson GPU: 275 TOPS (INT8), handles heavier models. Left free for other Nova tasks.
- Running detection on VPU means zero GPU load for the primary perception loop.

## Integration

The `NovaBridge` class provides:
- `perceive()` → dict with all detection/spatial/scene data
- `describe()` → natural language scene description
- `snapshot()` → captured image path

## Hardware Specs (OAK-D Pro PoE)

- **Color**: IMX378, 12MP, 4056x3040, 66° HFOV, auto-focus
- **Stereo**: OV9282 pair, 1280x800, 80° HFOV, global shutter
- **Baseline**: 7.5cm
- **Depth Range**: ~20cm (extended) to 38m (theoretical)
- **IR**: Dot projector (4700 dots, 940nm) + Flood LED
- **IMU**: BNO086 9-axis
- **Connection**: 1Gbps PoE
- **VPU**: Myriad X, 4 TOPS (1.4 TOPS AI)
