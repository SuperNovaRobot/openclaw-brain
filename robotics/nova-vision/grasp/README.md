# Nova Grasp — Vision-Guided Robotic Hand Control

## Architecture
- **nova_grasp_engine.py** — Real-time grasp loop (30Hz on Jetson)
- **nova_hand.py** — Ruka hand interface via Dynamixel SDK
- **nova_servo.py** — Visual servoing (depth → hand position error → correction)
- **grasp_planner.py** — Grasp pose estimation from depth + segmentation

## Hardware
- Hand: Ruka (all Dynamixel motors)
- Camera: OAK-D Pro PoE (depth + RGB from nova_cam daemon)
- Compute: Jetson Orin 64GB (GPU for SAM/segmentation, CPU for servo loop)

## Dynamixel Interface
- Protocol: 2.0
- Feedback: Position, Velocity, Current (torque) at 1kHz
- Grasp detection: Current threshold = object contact
- SDK: dynamixel_sdk (pip install dynamixel-sdk)

## Grasp Flow
1. Nova (LLM) sees scene → identifies target → plans approach vector
2. Grasp engine receives plan → begins visual servo approach
3. OAK-D depth tracks target in 3D, hand position via Dynamixel feedback
4. Fingers close until torque threshold → grip confirmed
5. Engine reports back → Nova verifies with snapshot

## TODO
- [ ] Get Ruka hand specs (motor IDs, joint limits, grip patterns)
- [ ] Install dynamixel-sdk in container
- [ ] Build hand interface with basic open/close/position control
- [ ] Implement visual servoing with depth feedback
- [ ] SAM integration for precise object boundaries
- [ ] Grasp pose estimation
- [ ] End-to-end test: see cup → grab cup
