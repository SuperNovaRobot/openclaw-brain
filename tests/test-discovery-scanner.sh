#!/usr/bin/env bash
# test-discovery-scanner.sh — Tests for discovery scanner system (Phase 4, Task 32)

set -euo pipefail

REPO_DIR="/mnt/ssd/openclaw-brain"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== Discovery Scanner Tests ==="
echo ""

# Test 1: scan-github-ranking.py exists and is executable
echo "[1/8] scan-github-ranking.py exists and is executable"
SCAN="${REPO_DIR}/workspace/scripts/scan-github-ranking.py"
if [ -f "${SCAN}" ] && [ -x "${SCAN}" ]; then
    pass "scan-github-ranking.py exists and is executable"
else
    fail "scan-github-ranking.py missing or not executable"
fi

# Test 2: tool-evaluator.py exists and is executable
echo "[2/8] tool-evaluator.py exists and is executable"
EVAL="${REPO_DIR}/workspace/scripts/tool-evaluator.py"
if [ -f "${EVAL}" ] && [ -x "${EVAL}" ]; then
    pass "tool-evaluator.py exists and is executable"
else
    fail "tool-evaluator.py missing or not executable"
fi

# Test 3: discovery-scanner.sh exists and is executable
echo "[3/8] discovery-scanner.sh exists and is executable"
DISC="${REPO_DIR}/workspace/scripts/discovery-scanner.sh"
if [ -f "${DISC}" ] && [ -x "${DISC}" ]; then
    pass "discovery-scanner.sh exists and is executable"
else
    fail "discovery-scanner.sh missing or not executable"
fi

# Test 4: scan-github-ranking.py --help runs
echo "[4/8] scan-github-ranking.py --help"
if python3 "${SCAN}" --help >/dev/null 2>&1; then
    pass "scan-github-ranking.py --help runs without error"
else
    fail "scan-github-ranking.py --help failed"
fi

# Test 5: tool-evaluator.py --help runs
echo "[5/8] tool-evaluator.py --help"
if python3 "${EVAL}" --help >/dev/null 2>&1; then
    pass "tool-evaluator.py --help runs without error"
else
    fail "tool-evaluator.py --help failed"
fi

# Test 6: TOOLS.md exists (source for comparison)
echo "[6/8] TOOLS.md exists"
if [ -f "${REPO_DIR}/workspace/TOOLS.md" ]; then
    pass "workspace/TOOLS.md exists"
else
    fail "workspace/TOOLS.md not found"
fi

# Test 7: tool-evaluator.py can score a sample repo from JSON
echo "[7/8] tool-evaluator.py scores a sample repo"
SAMPLE='{"full_name":"test/repo","description":"AI agent framework with MCP support","stars":5000,"language":"Python","topics":["ai","agent","mcp"],"pushed_at":"2026-03-20T00:00:00Z"}'
EVAL_RESULT=$(python3 "${EVAL}" --json "${SAMPLE}" 2>/dev/null || true)
if echo "${EVAL_RESULT}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if isinstance(data, list) and len(data) > 0:
    r = data[0]
    if 'score' in r and 'action' in r and 'reasons' in r:
        sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
    SCORE=$(echo "${EVAL_RESULT}" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['score'])")
    pass "tool-evaluator scored sample repo: ${SCORE}/10"
else
    fail "tool-evaluator did not return valid evaluation"
fi

# Test 8: Obsidian vault tools directory exists
echo "[8/8] Obsidian vault tools directory"
if [ -d "${REPO_DIR}/obsidian-vault/tools" ]; then
    pass "obsidian-vault/tools/ directory exists"
else
    # Not a hard failure — discovery-scanner creates it on first run
    echo "  SKIP: obsidian-vault/tools/ not yet created (created on first discovery)"
fi

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [ "${FAIL}" -gt 0 ]; then
    exit 1
fi
