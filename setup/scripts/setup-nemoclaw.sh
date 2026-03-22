#!/usr/bin/env bash
# setup-nemoclaw.sh — Wire NemoClaw as OPTIONAL REFERENCE only
# NemoClaw (NVIDIA) is reference architecture. Eve runs FREE.
set -euo pipefail

WORKSPACE="/mnt/ssd/openclaw-brain/workspace"
OBSIDIAN="/mnt/ssd/openclaw-brain/obsidian-vault"

echo "=== NemoClaw Reference Setup ==="
echo ""
echo "NemoClaw (NVIDIA/NemoClaw) is an optional reference architecture."
echo "It provides useful patterns for agent design but is NOT installed"
echo "as a constraint or sandbox on this agent."
echo ""

# Check if openclaw has a nemoclaw subcommand
if command -v openclaw &>/dev/null; then
    if openclaw --help 2>/dev/null | grep -q nemoclaw; then
        echo "[info] openclaw has a nemoclaw subcommand available."
        echo "  Usage: openclaw nemoclaw --help"
        echo "  Note: This is for REFERENCE only. It does not constrain the agent."
    else
        echo "[info] openclaw CLI found but no nemoclaw subcommand detected."
        echo "  NemoClaw patterns are used as reference material only."
    fi
else
    echo "[info] openclaw CLI not yet installed. NemoClaw remains documentation-only reference."
fi

echo ""

# Create workspace reference note
REFERENCE_NOTE="${OBSIDIAN}/references/nemoclaw-reference.md"
mkdir -p "$(dirname "$REFERENCE_NOTE")"

cat > "$REFERENCE_NOTE" << 'EOF'
---
title: NemoClaw Reference Architecture
tags: [reference, nvidia, nemoclaw, architecture]
created: 2026-03-22
---

# NemoClaw Reference Architecture

## Status: REFERENCE ONLY

NemoClaw is NVIDIA's agent architecture framework. We reference its patterns
for agent design but do NOT use it as a sandbox or constraint.

## Useful Patterns from NemoClaw
- Agent loop structures (observe -> plan -> act -> reflect)
- Tool orchestration patterns
- Safety gate designs (we adapt these for our operator-approval gates)
- Multi-agent coordination patterns

## What We Do NOT Import
- Sandboxing constraints — Eve runs free
- Execution limits — the agent decides its own boundaries
- Restricted tool access — all tools are available

## Related Notes
- [[TOOLS]] — our actual tool registry
- [[self-evaluation-protocol.SKILL]] — our self-eval loop (inspired by, not constrained by, NemoClaw)
- [[resource-acquisition.SKILL]] — the agent funds its own upgrades

## Source
- https://github.com/NVIDIA/NemoClaw
- Reference only. No installation required.
EOF

echo "[ok] Created reference note: $REFERENCE_NOTE"
echo ""
echo "NemoClaw is reference architecture only. Eve runs free."
