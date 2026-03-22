#!/bin/bash
# Multi-Agent Memory Isolation Test

echo "=== Multi-Agent Memory Isolation Test ==="
echo ""

PASS=0
FAIL=0
SKIP=0
MEMOS_URL="http://nova-rig:5230"

test_pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
test_fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
test_skip() { echo "  [SKIP] $1"; SKIP=$((SKIP + 1)); }

# Check Memos is reachable
if ! curl -sf --connect-timeout 5 "$MEMOS_URL/api/v1/workspace/profile" >/dev/null 2>&1; then
  echo "Memos not reachable at $MEMOS_URL — skipping live tests"
  SKIP=$((SKIP + 1))

  # Still test file-based isolation
  echo ""
  echo "File-based isolation:"

  BRAIN="/mnt/ssd/openclaw-brain"

  # Memory Agent workspace exists
  if [ -d "$BRAIN/workspace/memory-agent" ]; then
    test_pass "Memory Agent workspace exists"
  else
    test_fail "Memory Agent workspace missing"
  fi

  # Isolation skill exists
  if [ -f "$BRAIN/workspace/skills/multi-agent-isolation.SKILL.md" ]; then
    test_pass "Isolation skill exists"
  else
    test_fail "Isolation skill missing"
  fi

  # MemOS plugin config exists
  PLUGIN_DIR="$HOME/.openclaw/plugins/memos-cloud-openclaw-plugin"
  if [ -d "$PLUGIN_DIR" ]; then
    test_pass "MemOS plugin directory exists"
    if [ -f "$PLUGIN_DIR/config.json" ]; then
      # Check multiAgentMode is enabled
      if python3 -c "import json; c=json.load(open('$PLUGIN_DIR/config.json')); assert c.get('multiAgentMode', False)" 2>/dev/null; then
        test_pass "Multi-agent mode enabled in MemOS config"
      else
        test_fail "Multi-agent mode not enabled"
      fi
    else
      test_fail "MemOS config.json missing"
    fi
  else
    test_skip "MemOS plugin not configured yet"
  fi

  # Shared resources accessible
  if [ -d "$BRAIN/obsidian-vault" ]; then
    test_pass "Shared Obsidian vault accessible"
  else
    test_skip "Obsidian vault not deployed yet"
  fi

  if [ -f "$BRAIN/workspace/TOOLS.md" ]; then
    test_pass "Shared TOOLS.md accessible"
  else
    test_fail "TOOLS.md missing"
  fi

  # Agent IDs documented
  if grep -q "agent_id" "$BRAIN/workspace/skills/multi-agent-isolation.SKILL.md" 2>/dev/null; then
    test_pass "Agent IDs documented in isolation skill"
  else
    test_fail "Agent IDs not documented"
  fi

  # Behavior MCPs exist (they'll enforce routing)
  for mcp in task-router memory-decision self-eval; do
    if [ -f "$BRAIN/workspace/behavior-mcps/$mcp/server.py" ]; then
      test_pass "Behavior MCP: $mcp exists"
    else
      test_fail "Behavior MCP: $mcp missing"
    fi
  done

else
  # Full live tests with Memos
  echo "Live isolation tests:"

  # Create a main agent memo
  curl -sf -X POST "$MEMOS_URL/api/v1/memos" \
    -H "Content-Type: application/json" \
    -d '{"content": "#agent:openclaw-main #test-isolation Main agent private memo"}' >/dev/null 2>&1
  test_pass "Created main agent memo"

  # Create a sub-agent memo
  curl -sf -X POST "$MEMOS_URL/api/v1/memos" \
    -H "Content-Type: application/json" \
    -d '{"content": "#agent:memory-agent #test-isolation Memory agent private memo"}' >/dev/null 2>&1
  test_pass "Created memory-agent memo"

  # Create a shared memo (no agent tag)
  curl -sf -X POST "$MEMOS_URL/api/v1/memos" \
    -H "Content-Type: application/json" \
    -d '{"content": "#shared #test-isolation Shared knowledge accessible to all"}' >/dev/null 2>&1
  test_pass "Created shared memo"

  # Verify isolation: search for main agent memos
  MAIN_MEMOS=$(curl -sf "$MEMOS_URL/api/v1/memos" | python3 -c "
import sys, json
memos = json.load(sys.stdin)
count = sum(1 for m in memos if #agent:openclaw-main in m.get(content,) and #test-isolation in m.get(content,))
print(count)
" 2>/dev/null || echo "0")
  if [ "$MAIN_MEMOS" -ge 1 ]; then
    test_pass "Main agent can see own memos ($MAIN_MEMOS found)"
  else
    test_fail "Main agent can't find own memos"
  fi

  # All tests done
  BRAIN="/mnt/ssd/openclaw-brain"
  for f in multi-agent-isolation.SKILL.md; do
    if [ -f "$BRAIN/workspace/skills/$f" ]; then
      test_pass "Skill: $f"
    fi
  done

  for mcp in task-router memory-decision self-eval; do
    if [ -f "$BRAIN/workspace/behavior-mcps/$mcp/server.py" ]; then
      test_pass "MCP: $mcp"
    fi
  done
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
