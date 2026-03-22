# RUKA Hand + VLA Integration Plan

## What We Have

### RUKA SDK (`/mnt/ssd/models/RUKA/`)
- **11 Dynamixel motors**, IDs 0-10 (0-indexed in RUKA SDK, 1-indexed on the bus)
- **Current-based position control** (operating mode 5) — position + torque limiting
- **Per-finger LSTM-MLP controllers** — trained from Manus glove teleoperation data
- **Finger map** (from constants.py):
  - Thumb: motors [0, 1, 2]
  - Index: motors [3, 4]
  - Middle: motors [5, 6]
  - Ring: motors [8, 7]
  - Pinky: motors [10, 9]
- **PID tuned**: MCP vs DIP/PIP motors have different gains
- **Calibration system**: curl limits + tension limits per motor
- **Data collection**: H5 format recorder built in
- **Teleoperation**: Oculus + Manus glove support

### Existing Motion Code (`/mnt/ssd/models/novavoice/novamove/`)
- Your custom finger_map.md with tested grip positions
- Safe ranges JSON
- Vision-grasp integration attempts
- Torque monitoring
- Motor IDs 1-11 (1-indexed, matches Dynamixel bus addressing)

### Container Environment (`glm-server`)
- ✅ dynamixel_sdk
- ✅ torch 2.4.0 + CUDA
- ✅ h5py
- ✅ opencv
- ❌ hydra-core (needed for RUKA configs)
- ❌ zmq (needed for streaming)
- ❌ omegaconf (needed for RUKA configs)

## VLA Model Options for Jetson Orin 64GB

### Recommended: ACT (Action Chunking Transformer)
- **Size**: ~100M params, ~2GB VRAM
- **Speed**: 50+ Hz inference
- **Training**: Single GPU, few hours for fine-tune
- **Data**: 50-100 teleoperation demos sufficient
- **Framework**: LeRobot native support
- **Why**: Fastest path to working VLA, proven on dexterous hands

### Next: SmolVLA
- **Size**: ~2B params, ~6GB VRAM
- **Speed**: 30+ Hz inference
- **Training**: Single GPU, bfloat16
- **Advantage**: Language-conditioned ("pick up the red cup")
- **Framework**: LeRobot native

### Full Power: OpenVLA-OFT
- **Size**: 7B params, ~16GB VRAM (INT8 quant)
- **Speed**: 25-50x faster than vanilla OpenVLA
- **Training**: Needs beefy GPU (A100/4090) — use training machine
- **Advantage**: Most general, language + multi-task

## Fine-Tuning Pipeline

### Step 1: Data Collection (on Jetson)
```bash
# Option A: LeRobot teleoperation (keyboard/gamepad)
lerobot-record --robot.type=ruka_hand --robot.port=/dev/ttyUSB0

# Option B: Use existing RUKA Manus/Oculus teleoperation
python3 -m ruka_hand.teleoperation.manus_teleoperator

# Option C: Kinesthetic teaching (manually move hand, record positions)
python3 -m ruka_hand.data_collection.recorder
```

### Step 2: Convert to LeRobotDataset
- Convert RUKA H5 recordings → LeRobotDataset format (Parquet + MP4)
- Include OAK-D camera frames synchronized with motor states
- Push to HuggingFace Hub for training machine access

### Step 3: Train on Training Machine
```bash
lerobot-train \
  --policy=act \
  --dataset.repo_id=validsyntax/ruka-grasp-v1 \
  --output_dir=./outputs/ruka_act \
  --batch_size=8 \
  --steps=50000
```

### Step 4: Deploy to Jetson
```bash
lerobot-eval \
  --policy.path=validsyntax/ruka_act_trained \
  --robot.type=ruka_hand \
  --robot.port=/dev/ttyUSB0
```

## LeRobot Integration

Need to implement `lerobot.robots.Robot` interface for Ruka:
- Wraps RUKA SDK's Hand class
- Maps 11 motors to observation/action features
- Adds OAK-D camera as observation source
- Calibration from existing motor_limits/

## Motor ID Mapping (RUKA SDK → Physical)

| RUKA Index | Physical ID | Finger | Joint |
|-----------|-------------|--------|-------|
| 0 | 1 | Thumb | Tip |
| 1 | 2 | Thumb | Swing |
| 2 | 3 | Thumb | Mid |
| 3 | 4 | Index | Base |
| 4 | 5 | Index | Top |
| 5 | 6 | Middle | Base |
| 6 | 7 | Middle | Top |
| 7 | 8 | Ring | Top |
| 8 | 9 | Ring | Base |
| 9 | 10 | Pinky | Top |
| 10 | 11 | Pinky | Base |
