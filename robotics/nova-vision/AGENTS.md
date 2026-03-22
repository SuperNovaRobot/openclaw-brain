# AGENTS.md — Nova Vision

## For AI Agents Working on This Project

### Before You Start
1. Read `CLAUDE.md` for architecture decisions
2. Read `config.yaml` for current settings
3. Run inside `docker exec -it glm-server bash`

### Rules
- Never modify `/mnt/ssd/models/novavoice/fixedoak.py`
- Test changes inside glm-server container
- Models are `.blob` format for VPU, ONNX/TensorRT for Jetson GPU
- DepthAI v3 API — no XLinkOut nodes, use `createOutputQueue()`

### Architecture
Pipeline modules are independent. Each returns structured data (dataclasses).
The `nova_bridge.py` aggregates all pipeline outputs into a unified perception state.

### Testing
```bash
docker exec -it glm-server python3 /home/nova/.openclaw/workspace/nova_vision/main.py --test
```
