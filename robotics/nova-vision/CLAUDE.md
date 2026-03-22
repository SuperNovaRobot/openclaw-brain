# CLAUDE.md — Nova Vision System

## What This Is
Complete vision system for Nova humanoid robot using OAK-D Pro PoE camera + NVIDIA Jetson Orin 64GB.

## Architecture Decisions
1. **VPU-first approach**: Run YOLOv8n (object detection) and MobileNet-SSD (person detection) on Myriad X VPU as `.blob` files. The VPU handles inference at ~30 FPS without loading the Jetson GPU.
2. **Spatial detection on-device**: Use `YoloSpatialDetectionNetwork` to fuse detection + depth on the VPU — zero host-side depth lookup needed.
3. **Face detection on Jetson GPU**: Face detection/recognition runs on Jetson via ONNX/TensorRT since VPU bandwidth is used by primary detection.
4. **DepthAI v3 API**: Uses `pipeline.start()`, `createOutputQueue()` — no XLinkOut nodes needed.
5. **PoE connection**: Default IP `169.254.1.222`, auto-reconnect with exponential backoff.
6. **Modular pipeline**: Each capability (detection, depth, face, tracking) can be independently enabled/disabled via config.yaml.

## Key Files
- `main.py` — Entry point, orchestrates all pipelines
- `pipeline/camera.py` — PoE camera connection + pipeline building
- `pipeline/detection.py` — Object detection with spatial awareness
- `pipeline/depth.py` — Stereo depth configuration
- `pipeline/spatial.py` — Spatial awareness / navigation
- `pipeline/face.py` — Face detection (Jetson GPU)
- `integration/nova_bridge.py` — Bridge to Nova's main system
- `config.yaml` — All configuration

## Running
```bash
docker exec -it glm-server bash
cd /home/nova/.openclaw/workspace/nova_vision
python3 main.py
```

## Models Needed
See `models/README.md` for download instructions. Models go in `models/` directory.

## Important Constraints
- DO NOT modify `/mnt/ssd/models/novavoice/fixedoak.py`
- All Python runs inside `glm-server` Docker container
- PoE camera uses static IP `169.254.1.222`
- IR dot projector disabled by default (eye safety)
