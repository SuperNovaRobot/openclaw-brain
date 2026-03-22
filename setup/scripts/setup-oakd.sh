#!/usr/bin/env bash
# setup-oakd.sh — Connect OAK-D Pro stereo depth camera for robot vision
# OAK-D Pro provides depth + RGB + on-device neural inference via USB3.
set -euo pipefail

WORKSPACE="/mnt/ssd/openclaw-brain/workspace"
OBSIDIAN="/mnt/ssd/openclaw-brain/obsidian-vault"
MCP_DIR="$HOME/.openclaw/mcp-servers"
SKILL_DIR="$WORKSPACE/skills"
DOCKER_CONTAINER="glm-server"

echo "=== OAK-D Pro Vision Setup ==="
echo ""

# Ensure MCP directory exists
mkdir -p "$MCP_DIR"

# Check for OAK-D Pro USB device
echo "Checking for OAK-D Pro USB device..."
if lsusb 2>/dev/null | grep -qi "luxonis\|03e7"; then
    echo "[ok] Luxonis OAK-D device detected on USB bus."
    lsusb | grep -i "luxonis\|03e7" | while read -r line; do
        echo "  Device: $line"
    done
else
    echo "[warn] No Luxonis OAK-D device detected on USB."
    echo ""
    echo "  Troubleshooting:"
    echo "    1. Ensure OAK-D Pro is connected via USB3 (blue port)"
    echo "    2. Check cable — OAK-D requires USB3 data cable, not charge-only"
    echo "    3. Try: sudo dmesg | tail -20  (look for USB device events)"
    echo "    4. Luxonis USB vendor ID: 03e7"
    echo ""
fi

# Check DepthAI SDK inside Docker
echo "Checking DepthAI SDK availability..."
if docker exec "$DOCKER_CONTAINER" python3 -c "import depthai" 2>/dev/null; then
    echo "[ok] DepthAI SDK found inside $DOCKER_CONTAINER container."
    DEPTHAI_VER=$(docker exec "$DOCKER_CONTAINER" python3 -c "import depthai; print(depthai.__version__)" 2>/dev/null || echo "unknown")
    echo "  Version: $DEPTHAI_VER"
else
    echo "[warn] DepthAI SDK not found inside $DOCKER_CONTAINER container."
    echo ""
    echo "  Install (inside Docker — never on system Python):"
    echo "    docker exec $DOCKER_CONTAINER pip install depthai"
    echo ""
    echo "  Note: Docker container needs USB device access."
    echo "  If not already configured, restart container with:"
    echo "    --device /dev/bus/usb  or  --privileged"
    echo ""
fi

# Create MCP server config
echo "Creating OAK-D MCP server config..."
cat > "$MCP_DIR/oakd.json" << 'EOF'
{
  "name": "oakd",
  "description": "OAK-D Pro MCP server — stereo depth + RGB camera with on-device AI inference",
  "version": "1.0.0",
  "capabilities": [
    "capture_rgb",
    "capture_depth",
    "capture_stereo",
    "detect_objects",
    "estimate_pose",
    "get_pointcloud",
    "calibrate",
    "get_camera_info"
  ],
  "config": {
    "resolution": {
      "rgb": "1080p",
      "depth": "400p"
    },
    "fps": 30,
    "depth_preset": "HIGH_ACCURACY",
    "stereo_depth": true,
    "on_device_nn": true,
    "usb_speed": "USB3",
    "docker_container": "glm-server"
  },
  "metadata": {
    "created": "2026-03-22T00:00:00Z",
    "created_by": "setup-oakd.sh",
    "hardware": "Luxonis OAK-D Pro"
  }
}
EOF
echo "[ok] Created MCP config: $MCP_DIR/oakd.json"

# Create Obsidian reference note
ROBOT_NOTE="$OBSIDIAN/robots/oakd-pro-vision.md"
mkdir -p "$(dirname "$ROBOT_NOTE")"
cat > "$ROBOT_NOTE" << 'EOF'
---
title: OAK-D Pro Vision Pipeline
tags: [robotics, vision, camera, depth, oakd, depthai]
created: 2026-03-22
---

# OAK-D Pro Vision Pipeline

## Hardware
- Luxonis OAK-D Pro stereo depth camera
- RGB 4K sensor + stereo depth pair + IR dot projector
- On-device Intel Movidius Myriad X VPU for neural inference
- Connection: USB3 to nova (Jetson Orin)

## Capabilities
- Depth mapping (stereo + active IR)
- RGB capture up to 4K
- On-device object detection (YOLO, MobileNet)
- On-device pose estimation
- 3D point cloud generation
- Hardware-accelerated encoding (H.264/H.265)

## Calibration
- 9x6 checkerboard pattern, 25mm squares
- Hold pattern at 10+ positions covering full FOV
- Verify: depth accuracy < 2% error at 1m distance
- Re-calibrate after any physical mounting change

## Related Notes
- [[dimos-simulation]] — visual data feeds simulation for scene matching
- [[arm-control.SKILL]] — camera must verify before arm commands
- [[robotics-simulation.SKILL]] — sim uses depth data for collision avoidance
- [[TOOLS]] — OAK-D registered as MCP tool

## Source
- https://docs.luxonis.com/
- DepthAI SDK: pip install depthai (inside Docker)
EOF
echo "[ok] Created Obsidian note: $ROBOT_NOTE"

# Verify skill file exists
if [ -f "$SKILL_DIR/vision-pipeline.SKILL.md" ]; then
    echo "[ok] Vision pipeline skill already exists."
else
    echo "[info] Skill file will be created separately: vision-pipeline.SKILL.md"
fi

echo ""
echo "=== OAK-D Pro Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Connect OAK-D Pro via USB3 to nova"
echo "  2. Install DepthAI: docker exec $DOCKER_CONTAINER pip install depthai"
echo "  3. Ensure Docker has USB access (--device /dev/bus/usb or --privileged)"
echo "  4. Calibrate with 9x6 checkerboard pattern"
echo "  5. Test: docker exec $DOCKER_CONTAINER python3 -c 'import depthai; print(depthai.Device.getAllAvailableDevices())'"
echo "  6. Run tests/test-robotics.sh to verify integration"
