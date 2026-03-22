#!/usr/bin/env bash
# test-gws.sh — Tests for Google Workspace CLI integration
# Part of Phase 3, Task 28

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

PASS=0
FAIL=0
SKIP=0

pass() { echo -e "  ${GREEN}[PASS]${RESET} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}[FAIL]${RESET} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "  ${YELLOW}[SKIP]${RESET} $1"; SKIP=$((SKIP + 1)); }

echo -e "${BOLD}=== Google Workspace CLI Tests ===${RESET}"
echo ""

# ------------------------------------------------------------------
# Test 1: Check if gws binary is installed
# ------------------------------------------------------------------
export PATH="$HOME/.npm-global/bin:$HOME/.cargo/bin:/usr/local/bin:$PATH"

if command -v gws &>/dev/null; then
    pass "gws binary found: $(command -v gws)"
    GWS_INSTALLED=true
else
    skip "gws binary not installed (remaining gws runtime tests will be skipped)"
    GWS_INSTALLED=false
fi

# ------------------------------------------------------------------
# Test 2: Check MCP config exists
# ------------------------------------------------------------------
MCP_CONFIG="$HOME/.openclaw/mcp-servers/gws.json"
if [ -f "$MCP_CONFIG" ]; then
    # Validate it is valid JSON
    if python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$MCP_CONFIG" 2>/dev/null; then
        pass "MCP config exists and is valid JSON: $MCP_CONFIG"
    else
        fail "MCP config exists but is not valid JSON: $MCP_CONFIG"
    fi
else
    fail "MCP config not found: $MCP_CONFIG"
fi

# ------------------------------------------------------------------
# Test 3: Check skill file exists
# ------------------------------------------------------------------
SKILL_FILE="/mnt/ssd/openclaw-brain/workspace/skills/google-workspace.SKILL.md"
if [ -f "$SKILL_FILE" ]; then
    # Check it has expected content
    if grep -q "Google Workspace" "$SKILL_FILE" && grep -q "## Commands Reference" "$SKILL_FILE"; then
        pass "Skill file exists with expected content: $SKILL_FILE"
    else
        fail "Skill file exists but missing expected content: $SKILL_FILE"
    fi
else
    fail "Skill file not found: $SKILL_FILE"
fi

# ------------------------------------------------------------------
# Test 4: Check gws auth status (skip if not installed)
# ------------------------------------------------------------------
if [ "$GWS_INSTALLED" = true ]; then
    if gws auth status &>/dev/null 2>&1; then
        pass "gws is authenticated"
    else
        skip "gws is not authenticated (run: gws auth login)"
    fi
else
    skip "gws auth status check (binary not installed)"
fi

# ------------------------------------------------------------------
# Test 5: Check TOOLS.md has gws entry
# ------------------------------------------------------------------
TOOLS_FILE="/mnt/ssd/openclaw-brain/workspace/TOOLS.md"
if [ -f "$TOOLS_FILE" ]; then
    if grep -q "### gws" "$TOOLS_FILE" && grep -q "google-workspace.SKILL.md" "$TOOLS_FILE"; then
        pass "TOOLS.md has gws entry with skill reference"
    elif grep -q "### gws" "$TOOLS_FILE"; then
        fail "TOOLS.md has gws entry but missing skill reference"
    else
        fail "TOOLS.md missing gws entry"
    fi
else
    fail "TOOLS.md not found: $TOOLS_FILE"
fi

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
echo ""
TOTAL=$((PASS + FAIL + SKIP))
echo -e "${BOLD}Results: $TOTAL tests — ${GREEN}$PASS passed${RESET}, ${RED}$FAIL failed${RESET}, ${YELLOW}$SKIP skipped${RESET}"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
