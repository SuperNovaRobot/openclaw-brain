#!/bin/bash
# Setup Tavily MCP server for OpenClaw
# Configures MCP server config and Claude Code integration

echo "=== Setting up Tavily MCP Server ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

source "${REPO_DIR}/setup/.env" 2>/dev/null || true

# ── Configuration ────────────────────────────────────────────────────────────
MCP_SERVERS_DIR="${HOME}/.openclaw/mcp-servers"
CLAUDE_MCP_SETTINGS="${HOME}/.claude/mcp_settings.json"

# ── Check Tavily API key ────────────────────────────────────────────────────
TAVILY_KEY_OK=false

if [ -n "${TAVILY_API_KEY:-}" ] && [ "${TAVILY_API_KEY}" != "your-tavily-api-key" ]; then
  echo "[OK]   TAVILY_API_KEY is set"
  TAVILY_KEY_OK=true
else
  echo "[WARN] TAVILY_API_KEY not set or still default placeholder."
  echo ""
  echo "  To configure, set in setup/.env:"
  echo "    TAVILY_API_KEY=tvly-your-actual-key"
  echo ""
  echo "  Get a key at: https://tavily.com"
  echo ""
  echo "  Setup will continue (deferred credential configuration)."
  echo ""
fi

# ── Create MCP server config directory ───────────────────────────────────────
mkdir -p "${MCP_SERVERS_DIR}"

# ── Write Tavily MCP server config ───────────────────────────────────────────
echo "Creating Tavily MCP config at ${MCP_SERVERS_DIR}/tavily.json..."

cat > "${MCP_SERVERS_DIR}/tavily.json" << EOF
{
  "name": "tavily",
  "description": "Tavily MCP server — advanced web search, context retrieval, and content extraction",
  "version": "1.0.0",
  "capabilities": [
    "search",
    "search_context",
    "search_qna",
    "extract"
  ],
  "config": {
    "api_key": "${TAVILY_API_KEY:-}",
    "max_results": 10,
    "search_depth": "advanced",
    "include_answer": true,
    "include_raw_content": false,
    "timeout_seconds": 30
  },
  "metadata": {
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "created_by": "setup-tavily-mcp.sh"
  }
}
EOF

echo "[OK]   Tavily MCP config created"

# ── Update Claude Code mcp_settings.json ─────────────────────────────────────
mkdir -p "$(dirname "${CLAUDE_MCP_SETTINGS}")"

if [ -f "${CLAUDE_MCP_SETTINGS}" ]; then
  echo "Updating existing ${CLAUDE_MCP_SETTINGS}..."

  # Check if tavily entry already exists
  if grep -q tavily "${CLAUDE_MCP_SETTINGS}" 2>/dev/null; then
    echo "[OK]   Tavily already present in mcp_settings.json (no changes)"
  else
    # Add tavily server entry using python for safe JSON manipulation
    if command -v python3 &>/dev/null; then
      python3 << PYEOF
import json, sys

settings_path = "${CLAUDE_MCP_SETTINGS}"
try:
    with open(settings_path, "r") as f:
        settings = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    settings = {"mcpServers": {}}

if "mcpServers" not in settings:
    settings["mcpServers"] = {}

settings["mcpServers"]["tavily"] = {
    "command": "npx",
    "args": ["-y", "@tavily/mcp-server"],
    "env": {
        "TAVILY_API_KEY": "${TAVILY_API_KEY:-}"
    }
}

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

print("[OK]   Tavily added to mcp_settings.json")
PYEOF
    else
      echo "[WARN] python3 not available — manual mcp_settings.json update needed"
    fi
  fi
else
  echo "Creating ${CLAUDE_MCP_SETTINGS}..."
  cat > "${CLAUDE_MCP_SETTINGS}" << EOF
{
  "mcpServers": {
    "tavily": {
      "command": "npx",
      "args": ["-y", "@tavily/mcp-server"],
      "env": {
        "TAVILY_API_KEY": "${TAVILY_API_KEY:-}"
      }
    }
  }
}
EOF
  echo "[OK]   Created mcp_settings.json with Tavily server"
fi

# ── Status summary ───────────────────────────────────────────────────────────
echo ""
echo "=== Tavily MCP Setup Summary ==="
echo "  Config:         ${MCP_SERVERS_DIR}/tavily.json"
echo "  Claude settings: ${CLAUDE_MCP_SETTINGS}"
echo "  API key:        $([ "$TAVILY_KEY_OK" = true ] && echo "configured" || echo "NOT SET (deferred)")"
echo "  Max results:    10"
echo "  Search depth:   advanced"
echo "  Capabilities:   search, search_context, search_qna, extract"
echo ""
if [ "$TAVILY_KEY_OK" = true ]; then
  echo "[DONE] Tavily MCP server configured and ready."
else
  echo "[DONE] Tavily MCP server configured (API key pending)."
fi
