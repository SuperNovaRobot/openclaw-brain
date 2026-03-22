#!/bin/bash
set -euo pipefail

echo "=== Memory Stack Integration Test ==="

source "$(dirname "$0")/../setup/.env" 2>/dev/null || true

PASS=0
FAIL=0

test_pass() { echo "  [PASS] $1"; ((PASS++)); }
test_fail() { echo "  [FAIL] $1"; ((FAIL++)); }

# Layer 2: Create and retrieve a memo
echo "Testing Layer 2 (Memos)..."
MEMO_RESPONSE=$(curl -sf -X POST http://localhost:5230/api/v1/memos \
  -H "Content-Type: application/json" \
  -d '{"content": "Test memo from integration test #test"}' 2>/dev/null) && \
  test_pass "Layer 2: Memos create" || test_fail "Layer 2: Memos create"

# Layer 3: Create and find an Obsidian note
echo "Testing Layer 3 (Obsidian)..."
if command -v obsidian-cli &>/dev/null; then
  obsidian-cli new "test-integration" --content "Test note [[_index]]" 2>/dev/null && \
    obsidian-cli find "test-integration" 2>/dev/null | grep -q "test-integration" && \
    test_pass "Layer 3: Obsidian create + find" || test_fail "Layer 3: Obsidian create + find"
  obsidian-cli rm "test-integration" 2>/dev/null || true
else
  echo "  [SKIP] Layer 3: obsidian-cli not installed"
fi

# Layer 4: Search RagFlow
echo "Testing Layer 4 (RagFlow)..."
curl -sf -X POST http://localhost:9380/api/v1/retrieval \
  -H "Authorization: Bearer ${RAGFLOW_API_KEY:-changeme}" \
  -H "Content-Type: application/json" \
  -d '{"question": "test query", "datasets": ["agent-memory"]}' 2>/dev/null && \
  test_pass "Layer 4: RagFlow search" || test_fail "Layer 4: RagFlow search"

echo ""
echo "=== Memory Stack: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
