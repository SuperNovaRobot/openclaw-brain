#!/bin/bash
set -euo pipefail

echo "=== Setting up Memory Agent ==="

source "$(dirname "$0")/../../setup/.env" 2>/dev/null || true

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORKSPACE_DIR="$HOME/.openclaw/agents/memory-agent"

# Create agent workspace
mkdir -p "$WORKSPACE_DIR/skills"

# Copy workspace files
echo "Copying Memory Agent workspace files..."
cp "$REPO_DIR/workspace/memory-agent/SOUL.md" "$WORKSPACE_DIR/"
cp "$REPO_DIR/workspace/memory-agent/TOOLS.md" "$WORKSPACE_DIR/"
cp "$REPO_DIR/workspace/skills/memory-agent.SKILL.md" "$WORKSPACE_DIR/skills/"

echo ""
echo "Memory Agent setup complete."
echo "  Workspace: $WORKSPACE_DIR"
echo "  Files: SOUL.md, TOOLS.md, skills/memory-agent.SKILL.md"
echo "  Spawn: acpx openclaw --session memory-agent \"Search for: {query}\""
echo "  agent_id: memory-agent (MemOS isolation enabled)"
