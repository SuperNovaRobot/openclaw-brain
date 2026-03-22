# Arm Control (Dynamixel XM430-W350, 6-DOF + Custom Hand)

## Core Rule
**ALL commands go through dimos abstraction layer. NEVER direct hardware access.**

## Hardware
- **Servos**: 6x Dynamixel XM430-W350 (arm) + custom hand servos
- **Torque**: 4.1 Nm per joint (XM430-W350)
- **Communication**: TTL serial, 1 Mbps, Dynamixel Protocol 2.0
- **Adapter**: Dynamixel U2D2 USB-to-TTL at /dev/ttyUSB0
- **SDK**: dynamixel-sdk (pip install inside Docker, never system Python)

## Joint Map

| ID | Joint | Range | Home | Max Velocity |
|----|-------|-------|------|--------------|
| 1 | Base rotation | +/-180 deg | 0 deg | 46 RPM |
| 2 | Shoulder pitch | +/-90 deg | 0 deg | 46 RPM |
| 3 | Elbow pitch | +/-120 deg | 0 deg | 46 RPM |
| 4 | Wrist pitch | +/-90 deg | 0 deg | 46 RPM |
| 5 | Wrist roll | +/-180 deg | 0 deg | 46 RPM |
| 6 | Wrist yaw | +/-90 deg | 0 deg | 46 RPM |

## Safety Limits
- **Joint velocity**: 50% of max (23 RPM) during normal operation
- **Torque limit**: 80% of max (3.28 Nm) during normal operation
- **Position tolerance**: 2 degrees — error if exceeded after move
- **Current limit**: 1.5A per servo — error if exceeded
- **Temperature limit**: 72C — disable servo if exceeded

## Safety Chain (MANDATORY for every movement)
1. **Plan** — define target pose or trajectory
2. **Simulate** — run through [[robotics-simulation.SKILL]] (MuJoCo)
   - Check joint limits
   - Check self-collision
   - Check environment collision (uses [[vision-pipeline.SKILL]] depth data)
   - Check torque requirements
   - Check velocity profile
3. **Validate** — ALL sim checks must pass. If ANY fail, abort.
4. **Execute** — send validated commands through dimos to hardware
5. **Verify** — read actual joint states, compare to expected
   - Position error > 5%: log warning to Memos #hardware-anomaly
   - Position error > 15%: emergency stop
6. **Log** — movement recorded to Obsidian robots/ and Memos #hardware

## Emergency Stop
- **Trigger**: any error in the safety chain, any anomaly, operator command
- **Action**: all servos set to torque-off (register 64 = 0)
- **Recovery**: manual inspection required before re-enabling torque
- **Log**: emergency stop events logged to Memos #emergency with full state dump

## Commands

| Command | Description | Goes Through dimos |
|---------|-------------|-------------------|
| `move_joint(id, angle)` | Move single joint | Yes |
| `move_to_pose(x, y, z, rx, ry, rz)` | IK to end-effector pose | Yes |
| `get_joint_states()` | Read all joint positions/velocities/loads | Yes |
| `get_end_effector_pose()` | Forward kinematics | Yes |
| `open_hand()` | Open gripper/hand | Yes |
| `close_hand()` | Close gripper/hand | Yes |
| `set_grip_force(percent)` | Set hand grip force | Yes |
| `home_position()` | Move all joints to home (0 deg) | Yes |
| `emergency_stop()` | All servos torque-off | Direct (bypass OK) |
| `scan_servos()` | Ping all expected servo IDs | Direct (read-only OK) |

## Integration
- All movements validated first in [[robotics-simulation.SKILL]]
- Vision from [[vision-pipeline.SKILL]] verifies workspace is clear
- Arm state logged to Memos #hardware after every sequence
- Movement trajectories logged to Obsidian robots/ with [[wiki-links]]
- Self-eval loop tracks: success rate, position accuracy, anomaly frequency

## Rules
- NEVER bypass dimos for hardware commands (except emergency_stop and scan_servos)
- NEVER move without camera verification of workspace
- NEVER exceed 80% torque or 50% velocity in normal operation
- Emergency stop is the ONLY command that can bypass the safety chain
- Dynamixel SDK runs inside Docker — not on system Python
