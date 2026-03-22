#!/bin/bash
# Robotics Integration Test — dimos, OAK-D Pro, Arm+Hand

echo "=== Robotics Integration Test ==="
echo ""

PASS=0
FAIL=0
SKIP=0

BRAIN_DIR="/mnt/ssd/openclaw-brain"
MCP_DIR="$HOME/.openclaw/mcp-servers"
OBSIDIAN="$BRAIN_DIR/obsidian-vault"

test_pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
test_fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
test_skip() { echo "  [SKIP] $1"; SKIP=$((SKIP + 1)); }

# ---- Task 39: dimos Simulation ----
echo "Task 39: dimos Simulation"

if [ -f "$MCP_DIR/dimos.json" ]; then
    test_pass "dimos MCP config exists"
else
    test_fail "dimos MCP config missing at $MCP_DIR/dimos.json"
fi

if [ -f "$BRAIN_DIR/workspace/skills/robotics-simulation.SKILL.md" ]; then
    test_pass "Robotics simulation skill exists"
else
    test_fail "Robotics simulation skill missing"
fi

if [ -d "$BRAIN_DIR/workspace/models" ]; then
    test_pass "workspace/models/ directory exists"
else
    test_fail "workspace/models/ directory missing"
fi

if [ -f "$OBSIDIAN/robots/dimos-simulation.md" ]; then
    test_pass "Obsidian dimos-simulation note exists"
else
    test_fail "Obsidian dimos-simulation note missing"
fi

if grep -q "sim_validation_required" "$MCP_DIR/dimos.json" 2>/dev/null; then
    test_pass "dimos MCP config enforces sim-first safety"
else
    test_fail "dimos MCP config missing sim_validation_required"
fi

echo ""

# ---- Task 40: OAK-D Pro Vision ----
echo "Task 40: OAK-D Pro Vision"

if [ -f "$MCP_DIR/oakd.json" ]; then
    test_pass "OAK-D MCP config exists"
else
    test_fail "OAK-D MCP config missing at $MCP_DIR/oakd.json"
fi

if [ -f "$BRAIN_DIR/workspace/skills/vision-pipeline.SKILL.md" ]; then
    test_pass "Vision pipeline skill exists"
else
    test_fail "Vision pipeline skill missing"
fi

if [ -f "$OBSIDIAN/robots/oakd-pro-vision.md" ]; then
    test_pass "Obsidian OAK-D Pro vision note exists"
else
    test_fail "Obsidian OAK-D Pro vision note missing"
fi

if grep -q "capture_depth" "$MCP_DIR/oakd.json" 2>/dev/null; then
    test_pass "OAK-D MCP config has depth capture capability"
else
    test_fail "OAK-D MCP config missing depth capabilities"
fi

echo ""

# ---- Task 41: Custom Arm + Hand ----
echo "Task 41: Custom Arm + Hand"

if [ -f "$MCP_DIR/arm.json" ]; then
    test_pass "Arm MCP config exists"
else
    test_fail "Arm MCP config missing at $MCP_DIR/arm.json"
fi

if [ -f "$BRAIN_DIR/workspace/skills/arm-control.SKILL.md" ]; then
    test_pass "Arm control skill exists"
else
    test_fail "Arm control skill missing"
fi

if [ -f "$OBSIDIAN/robots/custom-arm-hand.md" ]; then
    test_pass "Obsidian custom-arm-hand note exists"
else
    test_fail "Obsidian custom-arm-hand note missing"
fi

if grep -q "route_through_dimos" "$MCP_DIR/arm.json" 2>/dev/null; then
    test_pass "Arm MCP config enforces dimos routing"
else
    test_fail "Arm MCP config missing route_through_dimos safety"
fi

if grep -q "emergency_stop_on_error" "$MCP_DIR/arm.json" 2>/dev/null; then
    test_pass "Arm MCP config has emergency stop on error"
else
    test_fail "Arm MCP config missing emergency_stop_on_error"
fi

echo ""

# ---- Cross-integration checks ----
echo "Cross-Integration Checks"

if [ -d "$OBSIDIAN/robots" ]; then
    test_pass "Obsidian robots/ directory exists"
else
    test_fail "Obsidian robots/ directory missing"
fi

ROBOT_NOTES=$(find "$OBSIDIAN/robots" -name "*.md" -type f 2>/dev/null | wc -l)
if [ "$ROBOT_NOTES" -ge 3 ]; then
    test_pass "Obsidian robots/ has $ROBOT_NOTES notes"
else
    test_fail "Obsidian robots/ has only $ROBOT_NOTES notes (expected 3+)"
fi

# Check wiki-links exist in robotics skills
WIKILINKS=0
for skill in robotics-simulation vision-pipeline arm-control; do
    SKILL_FILE="$BRAIN_DIR/workspace/skills/${skill}.SKILL.md"
    if [ -f "$SKILL_FILE" ] && grep -q '\[\[' "$SKILL_FILE" 2>/dev/null; then
        WIKILINKS=$((WIKILINKS + 1))
    fi
done
if [ "$WIKILINKS" -ge 3 ]; then
    test_pass "All 3 robotics skills contain [[wiki-links]]"
else
    test_fail "Only $WIKILINKS/3 robotics skills contain [[wiki-links]]"
fi

# Check sim-first safety is referenced across skills
SIM_FIRST=0
for skill in robotics-simulation vision-pipeline arm-control; do
    SKILL_FILE="$BRAIN_DIR/workspace/skills/${skill}.SKILL.md"
    if [ -f "$SKILL_FILE" ] && grep -qi "simulat" "$SKILL_FILE" 2>/dev/null; then
        SIM_FIRST=$((SIM_FIRST + 1))
    fi
done
if [ "$SIM_FIRST" -ge 3 ]; then
    test_pass "All 3 robotics skills reference simulation safety"
else
    test_fail "Only $SIM_FIRST/3 robotics skills reference simulation"
fi

echo ""

# ---- Summary ----
TOTAL=$((PASS + FAIL + SKIP))
echo "=== Results ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "  Skipped: $SKIP"
echo "  Total:  $TOTAL"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo "All robotics integration tests passed."
    exit 0
else
    echo "Some tests failed. Review output above."
    exit 1
fi
