#!/usr/bin/env bash
# test-self-improvement.sh — Tests for self-improvement controller (Phase 4, Task 30)

set -euo pipefail

REPO_DIR="/mnt/ssd/openclaw-brain"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== Self-Improvement Controller Tests ==="
echo ""

# Test 1: Self-eval skill file exists and has rubric
echo "[1/6] Self-evaluation skill file"
SKILL_FILE="$REPO_DIR/workspace/skills/self-evaluation-protocol.SKILL.md"
if [ -f "$SKILL_FILE" ]; then
    if grep -q "Quality Rubric" "$SKILL_FILE" && grep -q "trigger: post_task" "$SKILL_FILE"; then
        pass "Skill file exists with rubric and trigger"
    else
        fail "Skill file exists but missing rubric or trigger"
    fi
else
    fail "Skill file not found"
fi

# Test 2: self-eval-logger.py exists and is executable
echo "[2/6] Self-eval logger script"
LOGGER="$REPO_DIR/workspace/scripts/self-eval-logger.py"
if [ -f "$LOGGER" ] && [ -x "$LOGGER" ]; then
    pass "self-eval-logger.py exists and is executable"
else
    fail "self-eval-logger.py missing or not executable"
fi

# Test 3: experiment-runner.sh exists and is executable
echo "[3/6] Experiment runner script"
RUNNER="$REPO_DIR/workspace/scripts/experiment-runner.sh"
if [ -f "$RUNNER" ] && [ -x "$RUNNER" ]; then
    pass "experiment-runner.sh exists and is executable"
else
    fail "experiment-runner.sh missing or not executable"
fi

# Test 4: metric-analyzer.py exists and is executable
echo "[4/6] Metric analyzer script"
ANALYZER="$REPO_DIR/workspace/scripts/metric-analyzer.py"
if [ -f "$ANALYZER" ] && [ -x "$ANALYZER" ]; then
    pass "metric-analyzer.py exists and is executable"
else
    fail "metric-analyzer.py missing or not executable"
fi

# Test 5: self-eval-logger.py --help runs
echo "[5/6] Self-eval logger --help"
if python3 "$LOGGER" --help >/dev/null 2>&1; then
    pass "self-eval-logger.py --help runs without error"
else
    fail "self-eval-logger.py --help failed"
fi

# Test 6: metric-analyzer.py --help runs
echo "[6/6] Metric analyzer --help"
if python3 "$ANALYZER" --help >/dev/null 2>&1; then
    pass "metric-analyzer.py --help runs without error"
else
    fail "metric-analyzer.py --help failed"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ $FAIL -gt 0 ]; then
    exit 1
fi
