#!/bin/bash
# HEARTBEAT test — verifies proactive behavior infrastructure

echo "=== HEARTBEAT Test ==="
echo ""

PASS=0
FAIL=0
SKIP=0

source "$(dirname "$0")/../setup/.env" 2>/dev/null || true

test_pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
test_fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
test_skip() { echo "  [SKIP] $1"; SKIP=$((SKIP + 1)); }

# Check workspace files
echo "Workspace files:"
for f in SOUL.md IDENTITY.md TOOLS.md HEARTBEAT.md MEMORY.md AGENTS.md; do
  FPATH="$(dirname "$0")/../workspace/$f"
  if [ -f "$FPATH" ]; then
    test_pass "$f exists"
  else
    test_fail "$f missing"
  fi
done

# Check skills
echo ""
echo "Behavioral skills:"
SKILLS_DIR="$(dirname "$0")/../workspace/skills"
for skill in when-to-research when-to-delegate memory-routing self-evaluation-protocol tool-discovery resource-acquisition memory-agent; do
  if [ -f "$SKILLS_DIR/${skill}.SKILL.md" ]; then
    test_pass "${skill}.SKILL.md"
  else
    test_fail "${skill}.SKILL.md missing"
  fi
done

# Check cron jobs
echo ""
echo "Cron jobs:"
if crontab -l 2>/dev/null | grep -q "obsidian-vault"; then
  test_pass "Obsidian git sync (10min)"
else
  test_skip "Obsidian git sync not configured yet"
fi

# Check services needed for HEARTBEAT tasks
echo ""
echo "Services for HEARTBEAT tasks:"
if curl -sf "http://localhost:${MEMOS_PORT:-5230}/api/v1/workspace/profile" > /dev/null 2>&1; then
  test_pass "Memos (for TODO check, self-eval logging)"
else
  test_fail "Memos not running"
fi

# Check disk monitoring
echo ""
echo "Disk monitoring:"
USAGE=$(df /mnt/ssd --output=pcent 2>/dev/null | tail -1 | tr -d ' %' || echo "0")
if [ -n "$USAGE" ] && [ "$USAGE" -gt 0 ]; then
  test_pass "Disk usage readable: ${USAGE}%"
  if [ "$USAGE" -lt 90 ]; then
    test_pass "Disk usage under 90%"
  else
    test_fail "Disk usage critical: ${USAGE}%"
  fi
else
  test_fail "Cannot read disk usage"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
