---
title: Custom Arm + Hand Hardware
tags: [robotics, hardware, dynamixel, arm, hand, actuator]
created: 2026-03-22
---

# Custom Arm + Hand Hardware

## Arm Specification
- 6-DOF serial manipulator
- All joints: Dynamixel XM430-W350
- Torque: 4.1 Nm per joint
- Communication: TTL serial at 1 Mbps via U2D2 adapter
- Protocol: Dynamixel Protocol 2.0

## Joint Configuration
| ID | Joint | Range | Home |
|----|-------|-------|------|
| 1 | Base rotation | -180 to +180 deg | 0 deg |
| 2 | Shoulder pitch | -90 to +90 deg | 0 deg |
| 3 | Elbow pitch | -120 to +120 deg | 0 deg |
| 4 | Wrist pitch | -90 to +90 deg | 0 deg |
| 5 | Wrist roll | -180 to +180 deg | 0 deg |
| 6 | Wrist yaw | -90 to +90 deg | 0 deg |

## Safety Chain
1. Plan in [[dimos-simulation]] (sim-first, always)
2. Validate: joint limits, torque limits, collision check
3. Execute on hardware through dimos abstraction
4. Verify: compare actual joint states to expected
5. Emergency stop: all servos to torque-off on ANY error

## Related Notes
- [[dimos-simulation]] — ALL commands routed through dimos
- [[robotics-simulation.SKILL]] — sim validates before hardware
- [[vision-pipeline.SKILL]] — camera verifies workspace before movement
- [[oakd-pro-vision]] — visual feedback for grasp verification

## Source
- Dynamixel XM430-W350: https://emanual.robotis.com/docs/en/dxl/x/xm430-w350/
- Dynamixel SDK: pip install dynamixel-sdk (inside Docker)
