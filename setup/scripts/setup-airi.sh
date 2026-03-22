#!/usr/bin/env bash
# setup-airi.sh — Wire moeru-ai/airi avatar display for robot personality
# airi provides an animated avatar face on nova connected display.
# Syncs expressions with agent state and lip sync with Riva TTS.
set -euo pipefail

WORKSPACE="/mnt/ssd/openclaw-brain/workspace"
OBSIDIAN="/mnt/ssd/openclaw-brain/obsidian-vault"
MCP_DIR="$HOME/.openclaw/mcp-servers"
SKILL_DIR="$WORKSPACE/skills"

echo "=== airi Avatar Display Setup ==="
echo ""

# Ensure MCP directory exists
mkdir -p "$MCP_DIR"

# Check display availability
echo "Checking display output..."
if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    echo "[ok] Display environment detected (DISPLAY=${DISPLAY:-unset})."
elif [ -d /tmp/.X11-unix ] && ls /tmp/.X11-unix/ 2>/dev/null | grep -q "X"; then
    echo "[ok] X11 socket found at /tmp/.X11-unix/."
    echo "  Set DISPLAY=:0 if not already set."
else
    echo "[warn] No display environment detected."
    echo ""
    echo "  airi needs a connected display (HDMI/DP) on nova."
    echo "  Ensure X11 or Wayland is running:"
    echo "    export DISPLAY=:0"
    echo "    # or start X: sudo systemctl start gdm"
    echo ""
fi

# Check for Node.js (needed for Electron/web-based airi)
echo "Checking Node.js availability..."
if command -v node &>/dev/null; then
    NODE_VER=$(node --version 2>/dev/null || echo "unknown")
    echo "[ok] Node.js found: $NODE_VER"
else
    echo "[warn] Node.js not found."
    echo ""
    echo "  airi may require Node.js for Electron or web mode."
    echo "  Install: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash - && sudo apt install -y nodejs"
    echo ""
fi

# Check for Rust/Cargo (needed for Tauri-based airi)
echo "Checking Rust/Cargo availability..."
if command -v cargo &>/dev/null; then
    CARGO_VER=$(cargo --version 2>/dev/null || echo "unknown")
    echo "[ok] Cargo found: $CARGO_VER"
else
    echo "[info] Cargo not found — only needed if airi uses Tauri backend."
fi

# Check if airi is already cloned
AIRI_DIR="/mnt/ssd/airi"
echo "Checking for airi repository..."
if [ -d "$AIRI_DIR" ]; then
    echo "[ok] airi repository found at $AIRI_DIR."
elif [ -d "$HOME/sickGit/airi" ]; then
    AIRI_DIR="$HOME/sickGit/airi"
    echo "[ok] airi repository found at $AIRI_DIR."
else
    echo "[info] airi not found locally."
    echo ""
    echo "  Clone the repository:"
    echo "    cd /mnt/ssd && git clone https://github.com/moeru-ai/airi.git"
    echo ""
fi

# Create MCP server config
echo "Creating airi MCP server config..."
cat > "$MCP_DIR/airi.json" << 'MCPEOF'
{
  "name": "airi",
  "description": "airi MCP server — animated avatar display with expression control and lip sync",
  "version": "1.0.0",
  "capabilities": [
    "set_expression",
    "set_lip_sync",
    "set_idle_animation",
    "get_current_expression",
    "set_background",
    "set_avatar_model",
    "show_text_overlay",
    "hide_text_overlay"
  ],
  "config": {
    "display": ":0",
    "mode": "fullscreen",
    "resolution": "1920x1080",
    "expressions": [
      "neutral",
      "happy",
      "thinking",
      "listening",
      "speaking",
      "error",
      "surprised",
      "concerned"
    ],
    "lip_sync": {
      "enabled": true,
      "audio_source": "riva_tts",
      "method": "viseme"
    },
    "idle": {
      "breathing": true,
      "eye_blink": true,
      "micro_expressions": true
    }
  },
  "metadata": {
    "created": "2026-03-22T00:00:00Z",
    "created_by": "setup-airi.sh",
    "source": "https://github.com/moeru-ai/airi",
    "display_location": "nova connected screen (HDMI/DP)"
  }
}
MCPEOF
echo "[ok] Created MCP config: $MCP_DIR/airi.json"

# Create Obsidian reference note
ROBOT_NOTE="$OBSIDIAN/robots/airi-avatar-display.md"
mkdir -p "$(dirname "$ROBOT_NOTE")"
cat > "$ROBOT_NOTE" << 'OBSEOF'
---
title: airi Avatar Display
tags: [robotics, avatar, display, airi, personality, lip-sync]
created: 2026-03-22
---

# airi Avatar Display

## Purpose
airi provides an animated face/avatar for the robot on nova's connected screen.
The avatar visually represents the agent's current state — thinking, listening, speaking, errors.

## Architecture
- **Display**: HDMI/DP connected screen on nova
- **Rendering**: Electron, Tauri, or web-based (browser)
- **Lip Sync**: driven by Riva TTS audio stream
- **Expressions**: mapped to agent state machine

## Expression Mapping
| Agent State | Expression |
|-------------|-----------|
| Idle | neutral (with idle animations) |
| Processing query | thinking |
| Listening (ASR active) | listening |
| Speaking (TTS active) | speaking (with lip sync) |
| Task completed | happy |
| Error occurred | error |
| Unexpected input | surprised |
| Safety concern | concerned |

## Related Notes
- [[riva-voice-pipeline]] — TTS audio drives lip sync
- [[voice-interface.SKILL]] — voice interaction triggers expression changes
- [[self-evaluation-protocol.SKILL]] — expression feedback logged
- [[TOOLS]] — airi registered as MCP tool

## Source
- https://github.com/moeru-ai/airi
OBSEOF
echo "[ok] Created Obsidian note: $ROBOT_NOTE"

# Verify skill file exists
if [ -f "$SKILL_DIR/avatar-display.SKILL.md" ]; then
    echo "[ok] Avatar display skill already exists."
else
    echo "[info] Skill file will be created separately: avatar-display.SKILL.md"
fi

echo ""
echo "=== airi Avatar Display Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Clone airi: cd /mnt/ssd && git clone https://github.com/moeru-ai/airi.git"
echo "  2. Ensure nova has a connected display (HDMI/DP) with DISPLAY=:0"
echo "  3. Install airi dependencies (check airi README for Electron/Tauri/web mode)"
echo "  4. Configure lip sync audio source to Riva TTS output"
echo "  5. Start airi: cd /mnt/ssd/airi && npm start (or cargo build, depending on mode)"
echo "  6. Run tests/test-robotics.sh to verify integration"
