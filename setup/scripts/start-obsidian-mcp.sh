#!/bin/bash
set -euo pipefail

echo "=== Starting Obsidian CLI MCP Server ==="

source "$(dirname "$0")/../../setup/.env" 2>/dev/null || true

VAULT_PATH="${OBSIDIAN_VAULT_PATH:-/mnt/ssd/obsidian-vault}"

# Verify obsidian-cli is installed
if ! command -v obsidian-cli &>/dev/null; then
  echo "ERROR: obsidian-cli not installed."
  echo "Install: cargo install obsidian-cli"
  echo "Or: https://github.com/jwhonce/obsidian-cli"
  exit 1
fi

# Verify vault exists
if [ ! -d "$VAULT_PATH" ]; then
  echo "ERROR: Vault not found at $VAULT_PATH"
  echo "Run setup/scripts/setup-obsidian.sh first."
  exit 1
fi

# Kill existing MCP server if running
if [ -f /tmp/obsidian-mcp.pid ]; then
  OLD_PID=$(cat /tmp/obsidian-mcp.pid)
  kill "$OLD_PID" 2>/dev/null || true
  rm -f /tmp/obsidian-mcp.pid
fi

# Start MCP server in background
echo "Starting obsidian-cli MCP server..."
echo "  Vault: $VAULT_PATH"

obsidian-cli serve --vault "$VAULT_PATH" &
MCP_PID=$!

echo "  PID: $MCP_PID"
echo "  MCP server running. Agent can connect via MCP protocol."

# Save PID for shutdown
echo "$MCP_PID" > /tmp/obsidian-mcp.pid
echo "  PID saved to /tmp/obsidian-mcp.pid"
echo "  Stop with: kill \$(cat /tmp/obsidian-mcp.pid)"
