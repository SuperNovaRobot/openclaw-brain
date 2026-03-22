#!/bin/bash
set -euo pipefail

echo "=== Setting up MemOS Cloud OpenClaw Plugin ==="

source "$(dirname "$0")/../../setup/.env" 2>/dev/null || true

# Check if openclaw is available
if ! command -v openclaw &>/dev/null; then
  echo "WARNING: openclaw CLI not found. Configuring plugin files manually."
fi

PLUGIN_DIR="$HOME/.openclaw/plugins/memos-cloud-openclaw-plugin"
mkdir -p "$PLUGIN_DIR"

# Configure the plugin
echo "Configuring MemOS Cloud plugin..."
cat > "$PLUGIN_DIR/config.json" <<JSON
{
  "baseUrl": "${MEMOS_BASE_URL:-https://memos.memtensor.cn/api/openmem/v1}",
  "apiKey": "${MEMOS_API_KEY:-your-memos-cloud-api-key}",
  "userId": "${MEMOS_USER_ID:-openclaw-user}",
  "recallGlobal": ${MEMOS_RECALL_GLOBAL:-true},
  "multiAgentMode": ${MEMOS_MULTI_AGENT_MODE:-true},
  "recallFilterEnabled": false,
  "conversationResetOnNew": true
}
JSON

# Also configure local Memos integration (for self-hosted layer 2)
cat > "$PLUGIN_DIR/local-memos.json" <<JSON
{
  "localMemosUrl": "http://localhost:${MEMOS_PORT:-5230}",
  "localMemosEnabled": true,
  "syncToCloud": false,
  "lifecycleHooks": {
    "before_agent_start": {
      "action": "search_memory",
      "endpoint": "/search/memory",
      "maxResults": 10
    },
    "agent_end": {
      "action": "persist_message",
      "endpoint": "/add/message",
      "includeToolCalls": true
    }
  }
}
JSON

echo ""
echo "MemOS Cloud plugin configured."
echo "  Plugin dir: $PLUGIN_DIR"
echo "  Lifecycle hooks:"
echo "    before_agent_start → POST /search/memory (recall)"
echo "    agent_end → POST /add/message (persist)"
echo "  Multi-agent mode: enabled (agent_id isolation)"
echo ""
echo "  To install via openclaw (when available):"
echo "    openclaw plugin install memos-cloud-openclaw-plugin"
