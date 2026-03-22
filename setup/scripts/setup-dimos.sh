#!/usr/bin/env bash
# setup-dimos.sh — Deploy dimos simulation with MuJoCo for sim-first robotics
# dimos abstracts simulation and real hardware behind the same interface.
# ALWAYS simulate before commanding real hardware.
set -euo pipefail

WORKSPACE="/mnt/ssd/openclaw-brain/workspace"
OBSIDIAN="/mnt/ssd/openclaw-brain/obsidian-vault"
MCP_DIR="$HOME/.openclaw/mcp-servers"
SKILL_DIR="$WORKSPACE/skills"
DOCKER_CONTAINER="glm-server"

echo "=== dimos Simulation Setup ==="
echo ""

# Ensure MCP directory exists
mkdir -p "$MCP_DIR"

# Check if dimos is available inside the Docker container
echo "Checking dimos availability..."
if docker exec "$DOCKER_CONTAINER" python3 -c "import dimos" 2>/dev/null; then
    echo "[ok] dimos Python package found inside $DOCKER_CONTAINER container."
elif docker exec "$DOCKER_CONTAINER" bash -c "[ -d /opt/dimos ] || [ -d /mnt/ssd/dimos ]" 2>/dev/null; then
    echo "[ok] dimos repository found inside $DOCKER_CONTAINER container."
    echo "  You may need to: docker exec $DOCKER_CONTAINER pip install -e /path/to/dimos"
else
    echo "[warn] dimos not found inside $DOCKER_CONTAINER container."
    echo ""
    echo "  Install options (inside Docker — never on system Python):"
    echo "    docker exec $DOCKER_CONTAINER pip install dimos"
    echo "  OR clone and install:"
    echo "    docker exec $DOCKER_CONTAINER bash -c \\"
    echo "      'cd /mnt/ssd && git clone https://github.com/dimensionalOS/dimos.git && pip install -e dimos'"
    echo ""
fi

# Check MuJoCo availability
echo "Checking MuJoCo availability..."
if docker exec "$DOCKER_CONTAINER" python3 -c "import mujoco" 2>/dev/null; then
    echo "[ok] MuJoCo Python bindings found inside $DOCKER_CONTAINER container."
elif docker exec "$DOCKER_CONTAINER" bash -c "[ -f /usr/local/lib/libmujoco.so ] || [ -d ~/.mujoco ]" 2>/dev/null; then
    echo "[ok] MuJoCo libraries found. Python bindings may need install:"
    echo "    docker exec $DOCKER_CONTAINER pip install mujoco"
else
    echo "[warn] MuJoCo not found inside $DOCKER_CONTAINER container."
    echo ""
    echo "  Install (inside Docker):"
    echo "    docker exec $DOCKER_CONTAINER pip install mujoco"
    echo "  MuJoCo is now open-source — no license key needed."
    echo ""
fi

# Create MCP server config
echo "Creating dimos MCP server config..."
cat > "$MCP_DIR/dimos.json" << 'EOF'
{
  "name": "dimos",
  "description": "dimos MCP server — simulation-first robotics abstraction layer (MuJoCo + real hardware)",
  "version": "1.0.0",
  "capabilities": [
    "move_joint",
    "set_position",
    "get_sensor",
    "navigate",
    "simulate_trajectory",
    "validate_motion",
    "get_joint_state",
    "emergency_stop"
  ],
  "config": {
    "backend": "mujoco",
    "sim_timestep": 0.002,
    "realtime_factor": 1.0,
    "safety": {
      "sim_validation_required": true,
      "max_joint_velocity_deg_s": 180,
      "max_joint_torque_nm": 5.0,
      "collision_check": true
    },
    "docker_container": "glm-server",
    "model_path": "/mnt/ssd/openclaw-brain/workspace/models/robot.xml"
  },
  "metadata": {
    "created": "2026-03-22T00:00:00Z",
    "created_by": "setup-dimos.sh",
    "sim_first": "ALWAYS simulate before commanding real hardware"
  }
}
EOF
echo "[ok] Created MCP config: $MCP_DIR/dimos.json"

# Create Obsidian reference note
ROBOT_NOTE="$OBSIDIAN/robots/dimos-simulation.md"
mkdir -p "$(dirname "$ROBOT_NOTE")"
cat > "$ROBOT_NOTE" << 'EOF'
---
title: dimos Simulation Environment
tags: [robotics, simulation, mujoco, dimos, safety]
created: 2026-03-22
---

# dimos Simulation Environment

## Purpose
dimos provides a unified abstraction layer over simulation (MuJoCo) and real hardware.
The agent ALWAYS validates actions in simulation before executing on real hardware.

## Sim-First Safety Protocol
1. Plan trajectory in dimos simulation
2. Validate: no collisions, within joint limits, torque limits OK
3. Execute on real hardware through dimos abstraction
4. Verify: compare real result to simulated expectation
5. Log discrepancies to [[arm-control.SKILL]] and Memos #hardware

## Related Notes
- [[vision-pipeline.SKILL]] — camera feeds into sim for reality matching
- [[arm-control.SKILL]] — arm commands routed through dimos
- [[self-evaluation-protocol.SKILL]] — sim results feed self-eval loop
- [[TOOLS]] — dimos registered as MCP tool

## Source
- https://github.com/dimensionalOS/dimos
- MuJoCo: https://mujoco.org/
EOF
echo "[ok] Created Obsidian note: $ROBOT_NOTE"

# Create models directory
mkdir -p "$WORKSPACE/models"
echo "[ok] Created workspace/models/ directory for MJCF/URDF files."

# Verify skill file exists
if [ -f "$SKILL_DIR/robotics-simulation.SKILL.md" ]; then
    echo "[ok] Robotics simulation skill already exists."
else
    echo "[info] Skill file will be created separately: robotics-simulation.SKILL.md"
fi

echo ""
echo "=== dimos Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Ensure dimos + mujoco are installed inside $DOCKER_CONTAINER"
echo "  2. Place robot MJCF/URDF model at workspace/models/robot.xml"
echo "  3. Test with: docker exec $DOCKER_CONTAINER python3 -c 'import dimos; import mujoco'"
echo "  4. Run tests/test-robotics.sh to verify integration"
