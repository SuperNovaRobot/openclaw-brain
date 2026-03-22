#!/usr/bin/env bash
# setup-riva.sh — Wire NVIDIA Riva voice ASR/TTS for robot speech
# Riva server runs on nova-rig (GPU 0 dedicated, gRPC :50051)
# Riva client (Python SDK) runs on nova inside glm-server container
set -euo pipefail

WORKSPACE="/mnt/ssd/openclaw-brain/workspace"
OBSIDIAN="/mnt/ssd/openclaw-brain/obsidian-vault"
MCP_DIR="$HOME/.openclaw/mcp-servers"
SKILL_DIR="$WORKSPACE/skills"
DOCKER_CONTAINER="glm-server"
RIVA_SERVER="nova-rig:50051"

echo "=== NVIDIA Riva Voice (ASR/TTS) Setup ==="
echo ""

# Ensure MCP directory exists
mkdir -p "$MCP_DIR"

# Check Riva server reachability on nova-rig
echo "Checking Riva server on $RIVA_SERVER..."
if docker exec "$DOCKER_CONTAINER" python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(3)
try:
    s.connect(('nova-rig', 50051))
    s.close()
    print('reachable')
except:
    print('unreachable')
" 2>/dev/null | grep -q "reachable"; then
    echo "[ok] Riva gRPC server reachable at $RIVA_SERVER."
else
    echo "[warn] Cannot reach Riva server at $RIVA_SERVER."
    echo ""
    echo "  Riva server should be running on nova-rig with GPU 0 dedicated."
    echo "  Check:"
    echo "    ssh nova-rig docker ps | grep riva"
    echo "    ssh nova-rig docker logs riva-speech"
    echo ""
    echo "  If not running, start the riva-speech container on nova-rig:"
    echo "    ssh nova-rig docker start riva-speech"
    echo ""
fi

# Check Riva client SDK inside Docker on nova
echo "Checking Riva client SDK..."
if docker exec "$DOCKER_CONTAINER" python3 -c "import riva.client" 2>/dev/null; then
    echo "[ok] Riva client SDK found inside $DOCKER_CONTAINER container."
    RIVA_VER=$(docker exec "$DOCKER_CONTAINER" python3 -c "import riva.client; print(riva.client.__version__)" 2>/dev/null || echo "unknown")
    echo "  Version: $RIVA_VER"
else
    echo "[warn] Riva client SDK not found inside $DOCKER_CONTAINER container."
    echo ""
    echo "  Install (inside Docker — never on system Python):"
    echo "    docker exec $DOCKER_CONTAINER pip install nvidia-riva-client"
    echo ""
fi

# Check for audio devices (microphone + speaker on nova)
echo "Checking audio devices on nova..."
if command -v arecord &>/dev/null; then
    MIC_COUNT=$(arecord -l 2>/dev/null | grep -c "^card" || echo "0")
    echo "  Capture devices (microphones): $MIC_COUNT"
else
    echo "  [info] arecord not found — install alsa-utils for audio device listing."
fi
if command -v aplay &>/dev/null; then
    SPK_COUNT=$(aplay -l 2>/dev/null | grep -c "^card" || echo "0")
    echo "  Playback devices (speakers): $SPK_COUNT"
else
    echo "  [info] aplay not found — install alsa-utils for audio device listing."
fi

# Check riva-speech container on nova (stopped)
echo "Checking local riva-speech container state..."
if docker ps -a --format '{{.Names}}' | grep -q "riva-speech"; then
    RIVA_STATE=$(docker inspect -f '{{.State.Status}}' riva-speech 2>/dev/null || echo "unknown")
    echo "  [info] riva-speech container exists on nova (state: $RIVA_STATE)."
    echo "  Note: Riva server runs on nova-rig, not nova. This container is the client reference."
else
    echo "  [info] No riva-speech container found on nova (expected — server runs on nova-rig)."
fi

# Create MCP server config
echo "Creating Riva MCP server config..."
cat > "$MCP_DIR/riva.json" << 'MCPEOF'
{
  "name": "riva",
  "description": "NVIDIA Riva MCP server — ASR (speech-to-text) and TTS (text-to-speech) via gRPC",
  "version": "1.0.0",
  "capabilities": [
    "asr_streaming",
    "asr_offline",
    "tts_synthesis",
    "tts_streaming",
    "get_languages",
    "get_voices"
  ],
  "config": {
    "server": "nova-rig:50051",
    "protocol": "gRPC",
    "asr": {
      "language": "en-US",
      "encoding": "LINEAR_PCM",
      "sample_rate_hz": 16000,
      "streaming": true,
      "interim_results": true,
      "automatic_punctuation": true,
      "verbatim_transcripts": false
    },
    "tts": {
      "language": "en-US",
      "voice": "English-US.Female-1",
      "encoding": "LINEAR_PCM",
      "sample_rate_hz": 22050,
      "streaming": true
    },
    "docker_container": "glm-server",
    "audio": {
      "capture_device": "default",
      "playback_device": "default"
    }
  },
  "metadata": {
    "created": "2026-03-22T00:00:00Z",
    "created_by": "setup-riva.sh",
    "server_location": "nova-rig (GPU 0 dedicated)",
    "client_location": "nova (glm-server container)"
  }
}
MCPEOF
echo "[ok] Created MCP config: $MCP_DIR/riva.json"

# Create Obsidian reference note
ROBOT_NOTE="$OBSIDIAN/robots/riva-voice-pipeline.md"
mkdir -p "$(dirname "$ROBOT_NOTE")"
cat > "$ROBOT_NOTE" << 'OBSEOF'
---
title: NVIDIA Riva Voice Pipeline
tags: [robotics, voice, asr, tts, riva, nvidia, grpc]
created: 2026-03-22
---

# NVIDIA Riva Voice Pipeline

## Architecture
- **Riva Server**: runs on nova-rig (GPU 0 dedicated), gRPC on port 50051
- **Riva Client**: nvidia-riva-client SDK inside glm-server container on nova
- **Audio I/O**: microphone + speaker connected to nova host

## Pipeline
```
Microphone -> ASR (streaming) -> text -> agent -> response -> TTS (streaming) -> Speaker
```

## Capabilities
- **ASR**: real-time streaming speech-to-text, English-US, automatic punctuation
- **TTS**: real-time streaming text-to-speech, multiple voices
- Low-latency streaming for conversational interaction

## Safety
- Voice commands for hardware require verbal confirmation
- "Move arm" -> agent repeats command -> user says "confirm" -> execute
- Emergency stop voice command has highest priority

## Related Notes
- [[avatar-display.SKILL]] — lip sync driven by TTS audio stream
- [[arm-control.SKILL]] — voice commands for hardware need safety chain
- [[TOOLS]] — Riva registered as SDK tool

## Source
- https://developer.nvidia.com/riva
- Client SDK: pip install nvidia-riva-client (inside Docker)
OBSEOF
echo "[ok] Created Obsidian note: $ROBOT_NOTE"

# Verify skill file exists
if [ -f "$SKILL_DIR/voice-interface.SKILL.md" ]; then
    echo "[ok] Voice interface skill already exists."
else
    echo "[info] Skill file will be created separately: voice-interface.SKILL.md"
fi

echo ""
echo "=== Riva Voice Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Ensure Riva server is running on nova-rig: ssh nova-rig docker start riva-speech"
echo "  2. Install Riva client SDK: docker exec $DOCKER_CONTAINER pip install nvidia-riva-client"
echo "  3. Connect microphone + speaker to nova"
echo "  4. Test ASR: docker exec $DOCKER_CONTAINER python3 -c 'import riva.client; print(\"Riva client OK\")'"
echo "  5. Test connectivity: docker exec $DOCKER_CONTAINER python3 -c \\"
echo "     'import riva.client; auth = riva.client.Auth(uri=\"$RIVA_SERVER\"); print(\"Connected\")'"
echo "  6. Run tests/test-robotics.sh to verify integration"
