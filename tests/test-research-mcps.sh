#!/bin/bash
# Test NotebookLM and Tavily MCP server configurations
# Safe counters, no set -e

echo "=== Research MCP Servers Test ==="
echo ""

PASS=0
FAIL=0
SKIP=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

source "${REPO_DIR}/setup/.env" 2>/dev/null || true

MCP_SERVERS_DIR="${HOME}/.openclaw/mcp-servers"
CLAUDE_MCP_SETTINGS="${HOME}/.claude/mcp_settings.json"

test_pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
test_fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
test_skip() { echo "  [SKIP] $1"; SKIP=$((SKIP + 1)); }

# -- NotebookLM MCP Config ---------------------------------------------------
echo "NotebookLM MCP:"

if [ -f "${MCP_SERVERS_DIR}/notebooklm.json" ]; then
  test_pass "NotebookLM MCP config exists"
else
  test_fail "NotebookLM MCP config not found at ${MCP_SERVERS_DIR}/notebooklm.json"
fi

# Check master notebook ID
EXPECTED_NOTEBOOK="0f502fd6-fdeb-49bf-bc50-d759bf38483e"
if [ -f "${MCP_SERVERS_DIR}/notebooklm.json" ]; then
  if grep -q "${EXPECTED_NOTEBOOK}" "${MCP_SERVERS_DIR}/notebooklm.json" 2>/dev/null; then
    test_pass "Master notebook ID is set"
  else
    test_fail "Master notebook ID not found in config"
  fi
else
  test_skip "Master notebook ID check -- config missing"
fi

# Check Google credentials availability
if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && [ -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]; then
  test_pass "GOOGLE_APPLICATION_CREDENTIALS set and file exists"
elif [ -n "${GOOGLE_API_KEY:-}" ]; then
  test_pass "GOOGLE_API_KEY is set"
else
  test_skip "Google credentials not configured -- deferred setup"
fi

# Check capabilities in config
if [ -f "${MCP_SERVERS_DIR}/notebooklm.json" ]; then
  MISSING_CAPS=""
  for cap in notebook_query notebook_get notebook_create source_list source_add audio_overview; do
    if ! grep -q "\"${cap}\"" "${MCP_SERVERS_DIR}/notebooklm.json" 2>/dev/null; then
      MISSING_CAPS="${MISSING_CAPS} ${cap}"
    fi
  done
  if [ -z "$MISSING_CAPS" ]; then
    test_pass "All 6 NotebookLM capabilities present"
  else
    test_fail "Missing NotebookLM capabilities:${MISSING_CAPS}"
  fi
else
  test_skip "NotebookLM capabilities check -- config missing"
fi

# -- Tavily MCP Config -------------------------------------------------------
echo ""
echo "Tavily MCP:"

if [ -f "${MCP_SERVERS_DIR}/tavily.json" ]; then
  test_pass "Tavily MCP config exists"
else
  test_fail "Tavily MCP config not found at ${MCP_SERVERS_DIR}/tavily.json"
fi

# Check TAVILY_API_KEY
if [ -n "${TAVILY_API_KEY:-}" ] && [ "${TAVILY_API_KEY}" != "your-tavily-api-key" ]; then
  test_pass "TAVILY_API_KEY is set"

  # Test Tavily search via REST API
  echo ""
  echo "Tavily API -- live test:"
  TAVILY_RESPONSE=$(curl -sf --connect-timeout 10 -m 15 -X POST "https://api.tavily.com/search" \
    -H "Content-Type: application/json" \
    -d "{
      \"api_key\": \"${TAVILY_API_KEY}\",
      \"query\": \"OpenClaw autonomous agent\",
      \"max_results\": 1,
      \"search_depth\": \"basic\"
    }" 2>/dev/null || echo "")

  if [ -n "$TAVILY_RESPONSE" ]; then
    if echo "$TAVILY_RESPONSE" | grep -qiE '"results"|"answer"' 2>/dev/null; then
      test_pass "Tavily search API returned results"
    elif echo "$TAVILY_RESPONSE" | grep -qiE '"error"' 2>/dev/null; then
      test_fail "Tavily API returned an error"
    else
      test_fail "Tavily API returned unexpected response"
    fi
  else
    test_fail "Tavily API unreachable or timed out"
  fi
else
  test_skip "TAVILY_API_KEY not configured -- deferred setup"
  test_skip "Tavily API live test -- no API key"
fi

# Check capabilities in config
if [ -f "${MCP_SERVERS_DIR}/tavily.json" ]; then
  MISSING_CAPS=""
  for cap in search search_context search_qna extract; do
    if ! grep -q "\"${cap}\"" "${MCP_SERVERS_DIR}/tavily.json" 2>/dev/null; then
      MISSING_CAPS="${MISSING_CAPS} ${cap}"
    fi
  done
  if [ -z "$MISSING_CAPS" ]; then
    test_pass "All 4 Tavily capabilities present"
  else
    test_fail "Missing Tavily capabilities:${MISSING_CAPS}"
  fi
else
  test_skip "Tavily capabilities check -- config missing"
fi

# Check search_depth in config
if [ -f "${MCP_SERVERS_DIR}/tavily.json" ]; then
  if grep -q '"search_depth".*"advanced"' "${MCP_SERVERS_DIR}/tavily.json" 2>/dev/null; then
    test_pass "Tavily search_depth set to advanced"
  else
    test_fail "Tavily search_depth not set to advanced"
  fi
else
  test_skip "Tavily search_depth check -- config missing"
fi

# -- Claude Code MCP Settings ------------------------------------------------
echo ""
echo "Claude Code MCP Settings:"

if [ -f "${CLAUDE_MCP_SETTINGS}" ]; then
  test_pass "mcp_settings.json exists"

  if grep -q '"notebooklm"' "${CLAUDE_MCP_SETTINGS}" 2>/dev/null; then
    test_pass "NotebookLM server registered in mcp_settings.json"
  else
    test_fail "NotebookLM server NOT found in mcp_settings.json"
  fi

  if grep -q '"tavily"' "${CLAUDE_MCP_SETTINGS}" 2>/dev/null; then
    test_pass "Tavily server registered in mcp_settings.json"
  else
    test_fail "Tavily server NOT found in mcp_settings.json"
  fi
else
  test_fail "mcp_settings.json not found at ${CLAUDE_MCP_SETTINGS}"
  test_skip "NotebookLM registration check -- settings file missing"
  test_skip "Tavily registration check -- settings file missing"
fi

# -- Summary ------------------------------------------------------------------
echo ""
echo "=== Research MCP Test Results ==="
echo "  PASS: ${PASS}"
echo "  FAIL: ${FAIL}"
echo "  SKIP: ${SKIP}"
echo "  TOTAL: $((PASS + FAIL + SKIP))"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "[RESULT] Some tests failed. Run setup scripts first:"
  echo "  bash setup/scripts/setup-notebooklm-mcp.sh"
  echo "  bash setup/scripts/setup-tavily-mcp.sh"
  exit 1
else
  echo "[RESULT] All tests passed -- ${SKIP} skipped due to deferred credentials."
  exit 0
fi
