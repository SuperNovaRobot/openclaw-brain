#!/usr/bin/env bash
# setup-arm.sh — Connect custom 6-DOF arm + hand via Dynamixel servos
# ALL commands go through dimos abstraction layer. Never direct hardware access.
set -euo pipefail

WORKSPACE="/mnt/ssd/openclaw-brain/workspace"
OBSIDIAN="/mnt/ssd/openclaw-brain/obsidian-vault"
MCP_DIR="$HOME/.openclaw/mcp-servers"
SKILL_DIR="$WORKSPACE/skills"
DOCKER_CONTAINER="glm-server"

echo "=== Custom Arm + Hand Setup ==="
echo ""

# Ensure MCP directory exists
mkdir -p "$MCP_DIR"

# Check for Dynamixel USB adapter (FTDI-based)
echo "Checking for Dynamixel USB adapter..."
if lsusb 2>/dev/null | grep -qi "FTDI\|0403"; then
    echo "[ok] FTDI USB device detected (likely Dynamixel U2D2 adapter)."
    lsusb | grep -i "FTDI\|0403" | while read -r line; do
        echo "  Device: $line"
    done
elif ls /dev/ttyUSB* 2>/dev/null | head -1 > /dev/null; then
    echo "[ok] Serial device(s) found at /dev/ttyUSB*."
    ls /dev/ttyUSB* 2>/dev/null | while read -r dev; do
        echo "  Device: $dev"
    done
else
    echo "[warn] No FTDI/Dynamixel USB adapter detected."
    echo ""
    echo "  Troubleshooting:"
    echo "    1. Connect Dynamixel U2D2 adapter via USB"
    echo "    2. Check: ls /dev/ttyUSB*"
    echo "    3. FTDI USB vendor ID: 0403"
    echo "    4. May need: sudo usermod -aG dialout \$USER"
    echo ""
fi

# Check Dynamixel SDK inside Docker
echo "Checking Dynamixel SDK availability..."
if docker exec "$DOCKER_CONTAINER" python3 -c "import dynamixel_sdk" 2>/dev/null; then
    echo "[ok] Dynamixel SDK found inside $DOCKER_CONTAINER container."
else
    echo "[warn] Dynamixel SDK not found inside $DOCKER_CONTAINER container."
    echo ""
    echo "  Install (inside Docker — never on system Python):"
    echo "    docker exec $DOCKER_CONTAINER pip install dynamixel-sdk"
    echo ""
    echo "  Note: Docker container needs serial device access."
    echo "  If not already configured, restart container with:"
    echo "    --device /dev/ttyUSB0  or  --privileged"
    echo ""
fi

# Expected servo configuration
echo "Expected servo configuration:"
echo "  Arm (6-DOF):"
echo "    ID 1: Base rotation    — Dynamixel XM430-W350"
echo "    ID 2: Shoulder pitch   — Dynamixel XM430-W350"
echo "    ID 3: Elbow pitch      — Dynamixel XM430-W350"
echo "    ID 4: Wrist pitch      — Dynamixel XM430-W350"
echo "    ID 5: Wrist roll       — Dynamixel XM430-W350"
echo "    ID 6: Wrist yaw        — Dynamixel XM430-W350"
echo "  Hand:"
echo "    IDs 7+: Custom hand servos (configuration TBD)"
echo ""

# Create MCP server config
echo "Creating arm MCP server config..."
cat > "$MCP_DIR/arm.json" << 'EOF'
{
  "name": "arm",
  "description": "Custom arm + hand MCP server — 6-DOF Dynamixel arm with custom hand, routed through dimos",
  "version": "1.0.0",
  "capabilities": [
    "move_joint",
    "move_to_pose",
    "get_joint_states",
    "get_end_effector_pose",
    "open_hand",
    "close_hand",
    "set_grip_force",
    "home_position",
    "emergency_stop",
    "scan_servos",
    "set_torque_enable"
  ],
  "config": {
    "protocol_version": 2.0,
    "baudrate": 1000000,
    "port": "/dev/ttyUSB0",
    "servos": {
      "arm": {
        "model": "XM430-W350",
        "ids": [1, 2, 3, 4, 5, 6],
        "max_torque_nm": 4.1,
        "max_velocity_rpm": 46
      },
      "hand": {
        "ids": [7, 8, 9, 10, 11],
        "note": "Custom hand — servo models TBD"
      }
    },
    "safety": {
      "route_through_dimos": true,
      "sim_validation_required": true,
      "torque_limit_percent": 80,
      "velocity_limit_percent": 50,
      "emergency_stop_on_error": true
    },
    "docker_container": "glm-server"
  },
  "metadata": {
    "created": "2026-03-22T00:00:00Z",
    "created_by": "setup-arm.sh",
    "safety": "ALL commands routed through dimos — never direct hardware access"
  }
}
EOF
echo "[ok] Created MCP config: $MCP_DIR/arm.json"

# Create Obsidian reference note
ROBOT_NOTE="$OBSIDIAN/robots/custom-arm-hand.md"
mkdir -p "$(dirname "$ROBOT_NOTE")"
cat > "$ROBOT_NOTE" << 'EOF'
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
EOF
echo "[ok] Created Obsidian note: $ROBOT_NOTE"

# Verify skill file exists
if [ -f "$SKILL_DIR/arm-control.SKILL.md" ]; then
    echo "[ok] Arm control skill already exists."
else
    echo "[info] Skill file will be created separately: arm-control.SKILL.md"
fi

echo ""
echo "=== Arm + Hand Setup Complete ==="
echo ""
echo "SAFETY REMINDER: ALL arm commands go through dimos. Never direct hardware access."
echo ""
echo "Next steps:"
echo "  1. Connect Dynamixel U2D2 adapter via USB to nova"
echo "  2. Install SDK: docker exec $DOCKER_CONTAINER pip install dynamixel-sdk"
echo "  3. Ensure Docker has serial access (--device /dev/ttyUSB0 or --privileged)"
echo "  4. Scan for servos: use Dynamixel Wizard 2.0 or SDK scan"
echo "  5. Verify all 6 arm servos respond at IDs 1-6"
echo "  6. Run tests/test-robotics.sh to verify integration"
