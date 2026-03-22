#!/bin/bash
# Setup NotebookLM MCP server for OpenClaw
# Configures MCP server config and Claude Code integration

echo "=== Setting up NotebookLM MCP Server ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

source "${REPO_DIR}/setup/.env" 2>/dev/null || true

# ── Configuration ────────────────────────────────────────────────────────────
MASTER_NOTEBOOK_ID="${NOTEBOOKLM_NOTEBOOK_ID:-0f502fd6-fdeb-49bf-bc50-d759bf38483e}"
MCP_SERVERS_DIR="${HOME}/.openclaw/mcp-servers"
CLAUDE_MCP_SETTINGS="${HOME}/.claude/mcp_settings.json"

# ── Check Google credentials ────────────────────────────────────────────────
GOOGLE_CREDS_OK=false

if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && [ -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]; then
  echo "[OK]   GOOGLE_APPLICATION_CREDENTIALS set: ${GOOGLE_APPLICATION_CREDENTIALS}"
  GOOGLE_CREDS_OK=true
elif [ -n "${GOOGLE_API_KEY:-}" ]; then
  echo "[OK]   GOOGLE_API_KEY is set"
  GOOGLE_CREDS_OK=true
else
  echo "[WARN] No Google credentials found."
  echo ""
  echo "  To configure, set one of the following in setup/.env:"
  echo "    GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json"
  echo "    GOOGLE_API_KEY=your-google-api-key"
  echo ""
  echo "  Setup will continue (deferred credential configuration)."
  echo ""
fi

# ── Create MCP server config directory ───────────────────────────────────────
mkdir -p "${MCP_SERVERS_DIR}"

# ── Write NotebookLM MCP server config ───────────────────────────────────────
echo "Creating NotebookLM MCP config at ${MCP_SERVERS_DIR}/notebooklm.json..."

cat > "${MCP_SERVERS_DIR}/notebooklm.json" << EOF
{
  "name": "notebooklm",
  "description": "NotebookLM MCP server — Gemini-powered research via Google NotebookLM",
  "version": "1.0.0",
  "master_notebook": {
    "id": "${MASTER_NOTEBOOK_ID}",
    "access": "READ-ONLY",
    "rules": "Only add 10/10 sources to master notebook"
  },
  "capabilities": [
    "notebook_query",
    "notebook_get",
    "notebook_create",
    "source_list",
    "source_add",
    "audio_overview"
  ],
  "config": {
    "google_credentials": "${GOOGLE_APPLICATION_CREDENTIALS:-}",
    "google_api_key": "${GOOGLE_API_KEY:-}",
    "default_notebook_id": "${MASTER_NOTEBOOK_ID}",
    "timeout_seconds": 30,
    "max_retries": 3
  },
  "metadata": {
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "created_by": "setup-notebooklm-mcp.sh"
  }
}
EOF

echo "[OK]   NotebookLM MCP config created"

# ── Update Claude Code mcp_settings.json ─────────────────────────────────────
mkdir -p "$(dirname "${CLAUDE_MCP_SETTINGS}")"

if [ -f "${CLAUDE_MCP_SETTINGS}" ]; then
  echo "Updating existing ${CLAUDE_MCP_SETTINGS}..."

  # Check if notebooklm entry already exists
  if grep -q notebooklm "${CLAUDE_MCP_SETTINGS}" 2>/dev/null; then
    echo "[OK]   NotebookLM already present in mcp_settings.json (no changes)"
  else
    # Add notebooklm server entry using python for safe JSON manipulation
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

settings["mcpServers"]["notebooklm"] = {
    "command": "notebooklm-mcp",
    "args": ["serve"],
    "env": {
        "NOTEBOOKLM_NOTEBOOK_ID": "${MASTER_NOTEBOOK_ID}"
    }
}

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

print("[OK]   NotebookLM added to mcp_settings.json")
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
    "notebooklm": {
      "command": "notebooklm-mcp",
      "args": ["serve"],
      "env": {
        "NOTEBOOKLM_NOTEBOOK_ID": "${MASTER_NOTEBOOK_ID}"
      }
    }
  }
}
EOF
  echo "[OK]   Created mcp_settings.json with NotebookLM server"
fi

# ── Status summary ───────────────────────────────────────────────────────────
echo ""
echo "=== NotebookLM MCP Setup Summary ==="
echo "  Config:           ${MCP_SERVERS_DIR}/notebooklm.json"
echo "  Claude settings:  ${CLAUDE_MCP_SETTINGS}"
echo "  Master notebook:  ${MASTER_NOTEBOOK_ID}"
echo "  Google creds:     $([ "$GOOGLE_CREDS_OK" = true ] && echo "configured" || echo "NOT SET (deferred)")"
echo "  Capabilities:     notebook_query, notebook_get, notebook_create, source_list, source_add, audio_overview"
echo ""
if [ "$GOOGLE_CREDS_OK" = true ]; then
  echo "[DONE] NotebookLM MCP server configured and ready."
else
  echo "[DONE] NotebookLM MCP server configured (credentials pending)."
fi
