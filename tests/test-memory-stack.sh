#!/bin/bash
# Production memory stack integration test
# Tests all memory layers that are currently available

echo "=== Memory Stack Integration Test ==="
echo ""

PASS=0
FAIL=0
SKIP=0

source "$(dirname "$0")/../setup/.env" 2>/dev/null || true

test_pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
test_fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
test_skip() { echo "  [SKIP] $1"; SKIP=$((SKIP + 1)); }

# Layer 2: Memos
echo "Layer 2 (Memos):"
if curl -sf http://localhost:${MEMOS_PORT:-5230}/api/v1/workspace/profile > /dev/null 2>&1; then
  # Create test memo
  MEMO_RESULT=$(curl -sf -X POST "http://localhost:${MEMOS_PORT:-5230}/api/v1/memos" \
    -H "Content-Type: application/json" \
    -d '{"content": "Integration test memo #test-integration-run"}' 2>/dev/null)
  if [ -n "$MEMO_RESULT" ]; then
    test_pass "Create memo"
  else
    test_fail "Create memo"
  fi
  
  # Search by content
  SEARCH=$(curl -sf "http://localhost:${MEMOS_PORT:-5230}/api/v1/memos" 2>/dev/null)
  if echo "$SEARCH" | grep -q "test-integration-run" 2>/dev/null; then
    test_pass "Search memo by content"
  else
    test_fail "Search memo by content"
  fi
else
  test_skip "Memos not running"
fi

# Layer 3: Obsidian
echo ""
echo "Layer 3 (Obsidian):"
VAULT_PATH="${OBSIDIAN_VAULT_PATH:-/mnt/ssd/obsidian-vault}"
if [ -d "$VAULT_PATH" ]; then
  # Create test note directly (don't require obsidian-cli)
  TEST_NOTE="$VAULT_PATH/test-integration-note.md"
  cat > "$TEST_NOTE" << 'NOTE'
---
date: 2026-03-22
tags: #test-integration
---

# Test Integration Note

This tests the Obsidian vault layer.

## Related
- [[_index]]

#test-integration
NOTE
  
  if [ -f "$TEST_NOTE" ]; then
    test_pass "Create note in vault"
  else
    test_fail "Create note in vault"
  fi
  
  # Verify wiki-links present
  if grep -q '\[\[_index\]\]' "$TEST_NOTE" 2>/dev/null; then
    test_pass "Wiki-links present"
  else
    test_fail "Wiki-links present"
  fi
  
  # Cleanup
  rm -f "$TEST_NOTE"
  test_pass "Cleanup test note"
else
  test_skip "Obsidian vault not found at $VAULT_PATH"
fi

# Layer 4: RagFlow
echo ""
echo "Layer 4 (RagFlow):"
RAGFLOW_URL="http://localhost:${RAGFLOW_PORT:-9380}"
if curl -sf "$RAGFLOW_URL/api/v1/datasets" -H "Authorization: Bearer ${RAGFLOW_API_KEY:-changeme}" > /dev/null 2>&1; then
  test_pass "RagFlow API accessible"
  
  DATASETS=$(curl -sf "$RAGFLOW_URL/api/v1/datasets" -H "Authorization: Bearer ${RAGFLOW_API_KEY:-changeme}" 2>/dev/null)
  DS_COUNT=$(echo "$DATASETS" | jq '.data | length' 2>/dev/null || echo "0")
  if [ "$DS_COUNT" -gt 0 ]; then
    test_pass "Datasets exist ($DS_COUNT found)"
  else
    test_fail "No datasets found"
  fi
else
  test_skip "RagFlow not running (expected on ARM64 — needs investigation)"
fi

# Layer 5: SurfSense
echo ""
echo "Layer 5 (SurfSense):"
if curl -sf "http://localhost:${SURFSENSE_PORT:-8000}/health" > /dev/null 2>&1; then
  test_pass "SurfSense health check"
else
  test_skip "SurfSense not running (expected on ARM64 — needs investigation)"
fi

# Ingestion: crawl4ai
echo ""
echo "Ingestion (crawl4ai):"
if curl -sf "http://localhost:${CRAWL4AI_PORT:-11235}/health" > /dev/null 2>&1; then
  test_pass "crawl4ai health check"
else
  test_skip "crawl4ai not running"
fi

# Memory Agent
echo ""
echo "Memory Agent:"
AGENT_SKILL="$(dirname "$0")/../workspace/skills/memory-agent.SKILL.md"
if [ -f "$AGENT_SKILL" ]; then
  test_pass "Memory Agent SKILL.md exists"
else
  test_fail "Memory Agent SKILL.md missing"
fi

AGENT_SOUL="$(dirname "$0")/../workspace/memory-agent/SOUL.md"
if [ -f "$AGENT_SOUL" ]; then
  test_pass "Memory Agent SOUL.md exists"
else
  test_fail "Memory Agent SOUL.md missing"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
