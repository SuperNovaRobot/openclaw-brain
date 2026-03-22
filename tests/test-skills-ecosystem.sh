#!/bin/bash
# Skills Ecosystem Integration Test

echo "=== Skills Ecosystem Test ==="
echo ""

PASS=0
FAIL=0
SKIP=0

BRAIN_DIR="/mnt/ssd/openclaw-brain"

# Ensure npm global bin is on PATH (non-interactive shells may miss it)
NPM_GLOBAL_BIN="$(npm config get prefix 2>/dev/null)/bin"
if [ -d "$NPM_GLOBAL_BIN" ]; then
  export PATH="$NPM_GLOBAL_BIN:$PATH"
fi

test_pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
test_fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
test_skip() { echo "  [SKIP] $1"; SKIP=$((SKIP + 1)); }

# Skill packs installed
echo "Skill Packs:"
ECC=$(find "$BRAIN_DIR/workspace/skills/ecc" -type f 2>/dev/null | wc -l)
if [ "$ECC" -gt 50 ]; then
  test_pass "everything-claude-code: $ECC files"
else
  test_fail "everything-claude-code: only $ECC files (expected 100+)"
fi

CS=$(find "$BRAIN_DIR/workspace/skills/claude-skills" -type f 2>/dev/null | wc -l)
if [ "$CS" -gt 100 ]; then
  test_pass "claude-skills: $CS files"
else
  test_fail "claude-skills: only $CS files (expected 192+)"
fi

SP=$(find "$BRAIN_DIR/workspace/skills/superpowers" -type f 2>/dev/null | wc -l)
if [ "$SP" -gt 10 ]; then
  test_pass "superpowers: $SP files"
else
  test_fail "superpowers: only $SP files (expected 14+)"
fi

BMAD_WF=$(find "$BRAIN_DIR/workspace/skills/bmad" -type f 2>/dev/null | wc -l)
if [ "$BMAD_WF" -gt 20 ]; then
  test_pass "BMAD workflows: $BMAD_WF files"
else
  test_fail "BMAD workflows: only $BMAD_WF files (expected 34+)"
fi

BMAD_AG=$(find "$BRAIN_DIR/workspace/bmad-agents" -type f 2>/dev/null | wc -l)
if [ "$BMAD_AG" -gt 5 ]; then
  test_pass "BMAD agents: $BMAD_AG files"
else
  test_fail "BMAD agents: only $BMAD_AG files (expected 12+)"
fi

# Behavioral skills
echo ""
echo "Behavioral Skills:"
for skill in when-to-research when-to-delegate memory-routing self-evaluation-protocol tool-discovery resource-acquisition memory-agent; do
  if [ -f "$BRAIN_DIR/workspace/skills/${skill}.SKILL.md" ]; then
    test_pass "${skill}.SKILL.md"
  else
    test_fail "${skill}.SKILL.md missing"
  fi
done

# acpx configuration
echo ""
echo "acpx Configuration:"
if command -v acpx >/dev/null 2>&1; then
  test_pass "acpx installed"
else
  test_fail "acpx not installed"
fi

CONFIG="$HOME/.config/acpx/config.json"
if [ -f "$CONFIG" ]; then
  test_pass "Config file exists"
  # Check agents configured using node for JSON parsing
  for agent in claude codex openclaw; do
    if node -e "const c=require('$CONFIG'); process.exit(c.agents && c.agents.$agent ? 0 : 1)" 2>/dev/null; then
      test_pass "Agent configured: $agent"
    else
      test_fail "Agent missing: $agent"
    fi
  done
else
  test_fail "Config file missing"
fi

# Delegation tools
echo ""
echo "Delegation Tools:"
if command -v claude >/dev/null 2>&1; then
  test_pass "Claude Code CLI"
else
  test_skip "Claude Code CLI not installed (install: npm i -g @anthropic-ai/claude-code)"
fi

if command -v codex >/dev/null 2>&1; then
  test_pass "Codex CLI"
else
  test_skip "Codex CLI not installed (optional)"
fi

# Workspace files
echo ""
echo "Workspace:"
if [ -f "$BRAIN_DIR/workspace/TOOLS.md" ]; then
  test_pass "TOOLS.md exists"
else
  test_fail "TOOLS.md missing"
fi

if [ -f "$BRAIN_DIR/workspace/AGENTS.md" ]; then
  test_pass "AGENTS.md exists"
else
  test_fail "AGENTS.md missing"
fi

# Total skill count
echo ""
TOTAL=$((ECC + CS + SP + BMAD_WF + BMAD_AG))
echo "Total skills installed: $TOTAL"
echo ""
echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
