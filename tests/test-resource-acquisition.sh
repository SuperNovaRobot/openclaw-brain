#!/usr/bin/env bash
# test-resource-acquisition.sh — Verify resource acquisition loop wiring
set -euo pipefail

REPO="/mnt/ssd/openclaw-brain"
PASS=0
FAIL=0

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "=== Resource Acquisition Integration Tests ==="
echo ""

# Test 1: resource-tracker.py exists and is executable
if [ -x "$REPO/workspace/scripts/resource-tracker.py" ]; then
    pass "resource-tracker.py exists and is executable"
else
    fail "resource-tracker.py missing or not executable"
fi

# Test 2: resource-tracker.py --help runs without error
if python3 "$REPO/workspace/scripts/resource-tracker.py" --help >/dev/null 2>&1; then
    pass "resource-tracker.py --help runs successfully"
else
    fail "resource-tracker.py --help failed"
fi

# Test 3: resource-tracker.py has --summary flag
if python3 "$REPO/workspace/scripts/resource-tracker.py" --help 2>&1 | grep -q "\-\-summary"; then
    pass "resource-tracker.py supports --summary flag"
else
    fail "resource-tracker.py missing --summary flag"
fi

# Test 4: resource-tracker.py has --needs flag
if python3 "$REPO/workspace/scripts/resource-tracker.py" --help 2>&1 | grep -q "\-\-needs"; then
    pass "resource-tracker.py supports --needs flag"
else
    fail "resource-tracker.py missing --needs flag"
fi

# Test 5: resource-tracker.py uses stdlib only (no third-party imports)
if grep -qE "^import (requests|httpx|aiohttp|boto3)" "$REPO/workspace/scripts/resource-tracker.py"; then
    fail "resource-tracker.py imports third-party libraries (must use stdlib only)"
else
    pass "resource-tracker.py uses stdlib only"
fi

# Test 6: resource-acquisition.SKILL.md exists and has frontmatter
if [ -f "$REPO/workspace/skills/resource-acquisition.SKILL.md" ]; then
    if head -1 "$REPO/workspace/skills/resource-acquisition.SKILL.md" | grep -q "^---"; then
        pass "resource-acquisition.SKILL.md has frontmatter"
    else
        fail "resource-acquisition.SKILL.md missing frontmatter"
    fi
else
    fail "resource-acquisition.SKILL.md not found"
fi

# Test 7: resource-acquisition.SKILL.md version 2.0.0
if grep -q "version: 2.0.0" "$REPO/workspace/skills/resource-acquisition.SKILL.md"; then
    pass "resource-acquisition.SKILL.md is version 2.0.0"
else
    fail "resource-acquisition.SKILL.md not version 2.0.0"
fi

# Test 8: resource-acquisition.SKILL.md has revenue tracking format
if grep -q "Revenue Tracking Format" "$REPO/workspace/skills/resource-acquisition.SKILL.md"; then
    pass "resource-acquisition.SKILL.md has revenue tracking format"
else
    fail "resource-acquisition.SKILL.md missing revenue tracking format"
fi

# Test 9: resource-acquisition.SKILL.md has hardware need format
if grep -q "Hardware Need Format" "$REPO/workspace/skills/resource-acquisition.SKILL.md"; then
    pass "resource-acquisition.SKILL.md has hardware need format"
else
    fail "resource-acquisition.SKILL.md missing hardware need format"
fi

# Test 10: TOOLS.md has nemoclaw reference entry
if grep -q "nemoclaw" "$REPO/workspace/TOOLS.md"; then
    pass "TOOLS.md has nemoclaw entry"
else
    fail "TOOLS.md missing nemoclaw entry"
fi

# Test 11: TOOLS.md nemoclaw is marked as reference type
if grep -q "type: reference" "$REPO/workspace/TOOLS.md"; then
    pass "TOOLS.md nemoclaw is type: reference"
else
    fail "TOOLS.md nemoclaw not marked as reference"
fi

# Test 12: TOOLS.md nemoclaw mentions agent runs free
if grep -qi "runs free" "$REPO/workspace/TOOLS.md"; then
    pass "TOOLS.md nemoclaw says Eve runs FREE"
else
    fail "TOOLS.md nemoclaw missing 'runs free' assertion"
fi

# Test 13: setup-nemoclaw.sh exists and is executable
if [ -x "$REPO/setup/scripts/setup-nemoclaw.sh" ]; then
    pass "setup-nemoclaw.sh exists and is executable"
else
    fail "setup-nemoclaw.sh missing or not executable"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
echo "All tests passed!"
