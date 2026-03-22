#!/usr/bin/env bash
# test-instinct-extraction.sh — Tests for instinct extraction system (Phase 4, Task 31)

set -euo pipefail

REPO_DIR="/mnt/ssd/openclaw-brain"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== Instinct Extraction Tests ==="
echo ""

# Test 1: instinct-extraction.SKILL.md exists and has required sections
echo "[1/6] Instinct extraction skill file"
SKILL_FILE="${REPO_DIR}/workspace/skills/instinct-extraction.SKILL.md"
if [ -f "${SKILL_FILE}" ]; then
    if grep -q "trigger: session_end" "${SKILL_FILE}" && grep -q "Cluster" "${SKILL_FILE}" && grep -q "Evolve" "${SKILL_FILE}"; then
        pass "Skill file exists with trigger, cluster, and evolve sections"
    else
        fail "Skill file exists but missing required sections"
    fi
else
    fail "Skill file not found"
fi

# Test 2: instinct-extractor.py exists and is executable
echo "[2/6] Instinct extractor script"
EXTRACTOR="${REPO_DIR}/workspace/scripts/instinct-extractor.py"
if [ -f "${EXTRACTOR}" ] && [ -x "${EXTRACTOR}" ]; then
    pass "instinct-extractor.py exists and is executable"
else
    fail "instinct-extractor.py missing or not executable"
fi

# Test 3: instinct-extractor.py --help runs
echo "[3/6] Instinct extractor --help"
if python3 "${EXTRACTOR}" --help >/dev/null 2>&1; then
    pass "instinct-extractor.py --help runs without error"
else
    fail "instinct-extractor.py --help failed"
fi

# Test 4: evolve-instincts.sh exists and is executable
echo "[4/6] Evolve instincts script"
EVOLVE="${REPO_DIR}/workspace/scripts/evolve-instincts.sh"
if [ -f "${EVOLVE}" ] && [ -x "${EVOLVE}" ]; then
    pass "evolve-instincts.sh exists and is executable"
else
    fail "evolve-instincts.sh missing or not executable"
fi

# Test 5: workspace/skills/evolved/ directory exists
echo "[5/6] Evolved skills directory"
if [ -d "${REPO_DIR}/workspace/skills/evolved" ]; then
    pass "workspace/skills/evolved/ directory exists"
else
    fail "workspace/skills/evolved/ directory not found"
fi

# Test 6: Memos API reachable (skip if not)
echo "[6/6] Memos API reachable"
if python3 -c "
import urllib.request, sys
try:
    urllib.request.urlopen('http://nova-rig:5230/api/v1/memos?pageSize=1', timeout=5)
    print('reachable')
except Exception:
    print('unreachable')
    sys.exit(2)
" 2>/dev/null | grep -q "reachable"; then
    pass "Memos API at nova-rig:5230 is reachable"
else
    echo "  SKIP: Memos API not reachable (non-fatal)"
fi

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [ "${FAIL}" -gt 0 ]; then
    exit 1
fi
