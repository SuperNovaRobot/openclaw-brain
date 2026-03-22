#!/bin/bash
set -euo pipefail

echo "=== Setting up acpx (Agent-to-Agent Comms) ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

source "${REPO_DIR}/setup/.env" 2>/dev/null || true

# ── Install acpx if not present ─────────────────────────────────────────────
if command -v acpx &>/dev/null; then
  CURRENT_VERSION=$(acpx --version 2>/dev/null || echo "unknown")
  echo "acpx already installed: ${CURRENT_VERSION}"
else
  echo "Installing acpx via npm..."
  npm install -g acpx || {
    echo "ERROR: Failed to install acpx via npm."
    echo "Try manually: npm install -g acpx"
    echo "Or from source: https://github.com/openclaw/acpx"
    exit 1
  }
  echo "acpx installed: $(acpx --version 2>/dev/null || echo 'installed')"
fi

# ── Configure agent registry ────────────────────────────────────────────────
echo "Configuring agent registry..."

ACPX_CONFIG_DIR="${HOME}/.acpx"
REGISTRY_FILE="${ACPX_CONFIG_DIR}/registry.json"
mkdir -p "$ACPX_CONFIG_DIR"

cat > "$REGISTRY_FILE" << REGISTRY_EOF
{
  "agents": {
    "openclaw": {
      "name": "OpenClaw (Eve)",
      "type": "orchestrator",
      "endpoint": "http://localhost:${OPENCLAW_PORT:-18789}",
      "model": "${OPENCLAW_MODEL:-nemotron}",
      "capabilities": ["planning", "memory", "tool-use", "self-improvement"],
      "priority": 1
    },
    "claude": {
      "name": "Claude Code",
      "type": "coding-agent",
      "endpoint": "cli://claude",
      "capabilities": ["coding", "analysis", "debugging", "architecture"],
      "invoke": "claude --dangerously-skip-permissions",
      "priority": 2
    },
    "codex": {
      "name": "OpenAI Codex CLI",
      "type": "coding-agent",
      "endpoint": "cli://codex",
      "capabilities": ["coding", "refactoring", "testing"],
      "invoke": "codex --approval-mode full-auto",
      "priority": 3
    }
  },
  "routing": {
    "default": "openclaw",
    "coding": ["claude", "codex"],
    "planning": ["openclaw"],
    "research": ["openclaw"]
  },
  "config": {
    "timeout_seconds": 300,
    "retry_count": 2,
    "parallel_agents": 3
  }
}
REGISTRY_EOF

echo "Agent registry configured at ${REGISTRY_FILE}"
echo "  Agents:"
echo "    - openclaw (Eve) — orchestrator at localhost:${OPENCLAW_PORT:-18789}"
echo "    - claude — coding agent via CLI"
echo "    - codex — coding agent via CLI"

# ── Verify agent connectivity ────────────────────────────────────────────────
echo ""
echo "Verifying agent connectivity..."

# Check Claude Code
if command -v claude &>/dev/null; then
  echo "  [OK]   Claude Code CLI found: $(which claude)"
else
  echo "  [SKIP] Claude Code CLI not found (install: npm install -g @anthropic-ai/claude-code)"
fi

# Check Codex
if command -v codex &>/dev/null; then
  echo "  [OK]   Codex CLI found: $(which codex)"
else
  echo "  [SKIP] Codex CLI not found (install: npm install -g @openai/codex)"
fi

# Check OpenClaw gateway (may not be running yet)
if curl -sf "http://localhost:${OPENCLAW_PORT:-18789}/health" &>/dev/null; then
  echo "  [OK]   OpenClaw gateway responding at localhost:${OPENCLAW_PORT:-18789}"
else
  echo "  [SKIP] OpenClaw gateway not running yet (this is normal during setup)"
fi

echo ""
echo "acpx setup complete."
echo "  Config:    ${ACPX_CONFIG_DIR}"
echo "  Registry:  ${REGISTRY_FILE}"
echo "  Agents:    openclaw, claude, codex"
