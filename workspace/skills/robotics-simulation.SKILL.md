# Robotics Simulation (dimos + MuJoCo)

## Core Rule
**ALWAYS simulate before commanding real hardware.** No exceptions.

## What dimos Does
dimos abstracts simulation and real hardware behind a single interface.
The agent writes one set of commands — dimos routes to sim or hardware.
MuJoCo provides the physics engine for accurate simulation.

## Commands

| Command | Description | Sim | Real |
|---------|-------------|-----|------|
| `move_joint(joint_id, angle)` | Move a joint to target angle | Yes | Yes |
| `set_position(x, y, z, rx, ry, rz)` | Set end-effector pose | Yes | Yes |
| `get_sensor(sensor_id)` | Read sensor value | Yes | Yes |
| `navigate(x, y, theta)` | Move base to position | Yes | Yes |
| `simulate_trajectory(waypoints)` | Validate full trajectory | Yes | No |
| `validate_motion(start, end)` | Check for collisions/limits | Yes | No |
| `emergency_stop()` | All servos to torque-off | N/A | Yes |

## Safety Protocol
1. **Plan** — generate trajectory from current state to goal
2. **Simulate** — run trajectory in MuJoCo, check for:
   - Joint limit violations
   - Self-collisions or environment collisions
   - Torque limit exceedances
   - Velocity limit violations
3. **Validate** — simulation must pass ALL checks before hardware execution
4. **Execute** — send validated commands through dimos to real hardware
5. **Verify** — compare real joint states to expected simulated states
6. **Log** — discrepancies > 5% logged to Memos #hardware-anomaly

## MuJoCo Configuration
- Timestep: 0.002s (500Hz)
- Solver: Newton (default)
- Model format: MJCF (XML) or URDF import
- Model location: workspace/models/robot.xml

## Integration
- Vision data from [[vision-pipeline.SKILL]] feeds scene reconstruction
- Arm commands through [[arm-control.SKILL]] are validated here first
- Simulation results logged to Obsidian robots/ with [[wiki-links]]
- Anomalies logged to Memos #hardware-anomaly
- Self-eval loop checks sim accuracy vs real over time

## Rules
- Never bypass simulation for real hardware commands
- If simulation fails, do NOT execute on hardware — fix the plan first
- All MuJoCo models must be version-controlled in workspace/models/
- dimos runs inside Docker (glm-server) — not on system Python
