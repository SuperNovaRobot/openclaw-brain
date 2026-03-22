#!/bin/bash
set -euo pipefail

echo "=== Setting up OpenClaw Agent ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

source "${REPO_DIR}/setup/.env" 2>/dev/null || true

OPENCLAW_HOME="${HOME}/.openclaw"
WORKSPACE_DIR="${OPENCLAW_HOME}/workspace"

# ── Install OpenClaw if not present ─────────────────────────────────────────
if command -v openclaw &>/dev/null; then
  CURRENT_VERSION=$(openclaw --version 2>/dev/null || echo "unknown")
  echo "OpenClaw already installed: ${CURRENT_VERSION}"
else
  echo "Installing OpenClaw via npm..."
  npm install -g openclaw || {
    echo "ERROR: Failed to install openclaw via npm."
    echo "Try manually: npm install -g openclaw"
    exit 1
  }
  echo "OpenClaw installed: $(openclaw --version 2>/dev/null || echo 'installed')"
fi

# ── Run onboarding if fresh install ─────────────────────────────────────────
if [ ! -d "$OPENCLAW_HOME" ]; then
  echo "Fresh install detected. Running onboarding..."
  mkdir -p "$OPENCLAW_HOME"
  openclaw onboard 2>/dev/null || {
    echo "WARNING: openclaw onboard failed or is not available yet."
    echo "Creating directory structure manually..."
    mkdir -p "${OPENCLAW_HOME}/workspace"
    mkdir -p "${OPENCLAW_HOME}/config"
    mkdir -p "${OPENCLAW_HOME}/logs"
    mkdir -p "${OPENCLAW_HOME}/plugins"
  }
else
  echo "Existing OpenClaw installation found at ${OPENCLAW_HOME}"
fi

# ── Copy workspace files ────────────────────────────────────────────────────
echo "Copying workspace files..."
mkdir -p "$WORKSPACE_DIR"
if [ -d "${REPO_DIR}/workspace" ]; then
  cp -r "${REPO_DIR}/workspace/"* "$WORKSPACE_DIR/" 2>/dev/null || true
  echo "Workspace files copied to ${WORKSPACE_DIR}"
  echo "  Files:"
  ls -1 "$WORKSPACE_DIR" 2>/dev/null | sed 's/^/    /'
else
  echo "WARNING: No workspace directory found at ${REPO_DIR}/workspace"
fi

# ── Install MemOS plugin ────────────────────────────────────────────────────
echo "Configuring MemOS plugin..."
MEMOS_CONFIG="${OPENCLAW_HOME}/config/memos.json"
mkdir -p "${OPENCLAW_HOME}/config"

python3 -c "
import json, sys
config = {
    'plugin': 'memos',
    'enabled': True,
    'api_key': '${MEMOS_API_KEY:-}',
    'base_url': '${MEMOS_BASE_URL:-https://memos.memtensor.cn/api/openmem/v1}',
    'user_id': '${MEMOS_USER_ID:-openclaw-user}',
    'recall_global': True,
    'multi_agent_mode': True,
    'local_endpoint': 'http://localhost:${MEMOS_PORT:-5230}'
}
json.dump(config, open('${MEMOS_CONFIG}', 'w'), indent=2)
" 2>/dev/null || {
  # Fallback without python
  cat > "$MEMOS_CONFIG" << MEMOS_EOF
{
  "plugin": "memos",
  "enabled": true,
  "api_key": "${MEMOS_API_KEY:-}",
  "base_url": "${MEMOS_BASE_URL:-https://memos.memtensor.cn/api/openmem/v1}",
  "user_id": "${MEMOS_USER_ID:-openclaw-user}",
  "recall_global": true,
  "multi_agent_mode": true,
  "local_endpoint": "http://localhost:${MEMOS_PORT:-5230}"
}
MEMOS_EOF
}
echo "MemOS plugin configured at ${MEMOS_CONFIG}"

# ── Configure channel ───────────────────────────────────────────────────────
echo "Configuring communication channel..."
CHANNEL_CONFIG="${OPENCLAW_HOME}/config/channel.json"

if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ "$TELEGRAM_BOT_TOKEN" != "your-telegram-token" ]; then
  cat > "$CHANNEL_CONFIG" << CHAN_EOF
{
  "channel": "telegram",
  "bot_token": "${TELEGRAM_BOT_TOKEN}",
  "enabled": true
}
CHAN_EOF
  echo "Channel configured: Telegram"
elif [ -n "${DISCORD_BOT_TOKEN:-}" ] && [ "$DISCORD_BOT_TOKEN" != "your-discord-token" ]; then
  cat > "$CHANNEL_CONFIG" << CHAN_EOF
{
  "channel": "discord",
  "bot_token": "${DISCORD_BOT_TOKEN}",
  "enabled": true
}
CHAN_EOF
  echo "Channel configured: Discord"
elif [ -n "${SLACK_BOT_TOKEN:-}" ] && [ "$SLACK_BOT_TOKEN" != "your-slack-token" ]; then
  cat > "$CHANNEL_CONFIG" << CHAN_EOF
{
  "channel": "slack",
  "bot_token": "${SLACK_BOT_TOKEN}",
  "enabled": true
}
CHAN_EOF
  echo "Channel configured: Slack"
else
  cat > "$CHANNEL_CONFIG" << CHAN_EOF
{
  "channel": "cli",
  "enabled": true
}
CHAN_EOF
  echo "Channel configured: CLI-only (no bot token set)"
fi

# ── Configure inference endpoint ────────────────────────────────────────────
echo "Configuring inference endpoint..."
INFERENCE_CONFIG="${OPENCLAW_HOME}/config/inference.json"
cat > "$INFERENCE_CONFIG" << INF_EOF
{
  "host": "${INFERENCE_HOST:-http://nova-rig:8080}",
  "api_key": "${INFERENCE_API_KEY:-changeme}",
  "backend": "${INFERENCE_BACKEND:-llamacpp}",
  "model": "${OPENCLAW_MODEL:-nemotron}"
}
INF_EOF
echo "Inference configured: ${INFERENCE_HOST:-http://nova-rig:8080}"

echo ""
echo "OpenClaw setup complete."
echo "  Home:       ${OPENCLAW_HOME}"
echo "  Workspace:  ${WORKSPACE_DIR}"
echo "  Inference:  ${INFERENCE_HOST:-http://nova-rig:8080}"
