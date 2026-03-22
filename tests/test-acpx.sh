#!/bin/bash
# test-acpx.sh — Integration tests for acpx configuration
# Uses safe counter pattern (no set -e, no ((PASS++)))

PASS=0
FAIL=0
SKIP=0

REPO_DIR="/mnt/ssd/openclaw-brain"
CONFIG_FILE="${REPO_DIR}/setup/configs/acpx-config.json"
DEPLOYED_CONFIG="${HOME}/.config/acpx/config.json"
SESSION_DIR="${REPO_DIR}/.acpx-sessions"

echo "============================================"
echo "  acpx Integration Tests"
echo "============================================"
echo ""

# ── Test 1: Config file exists ───────────────────────────────────────────────
echo "--- Test 1: Config file exists ---"
if [ -f "$CONFIG_FILE" ]; then
  echo "  [PASS] Config file exists: ${CONFIG_FILE}"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] Config file missing: ${CONFIG_FILE}"
  FAIL=$((FAIL + 1))
fi

# ── Test 2: Config is valid JSON ─────────────────────────────────────────────
echo "--- Test 2: Config is valid JSON ---"
if command -v node &>/dev/null; then
  if node -e "JSON.parse(require(\"fs\").readFileSync(process.argv[1],\"utf8\"))" "$CONFIG_FILE" 2>/dev/null; then
    echo "  [PASS] Config is valid JSON"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] Config is not valid JSON"
    FAIL=$((FAIL + 1))
  fi
elif command -v python3 &>/dev/null; then
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$CONFIG_FILE" 2>/dev/null; then
    echo "  [PASS] Config is valid JSON"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] Config is not valid JSON"
    FAIL=$((FAIL + 1))
  fi
elif command -v jq &>/dev/null; then
  if jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo "  [PASS] Config is valid JSON"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] Config is not valid JSON"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  [SKIP] No JSON validator available (need node, python3, or jq)"
  SKIP=$((SKIP + 1))
fi

# ── Test 3: All 3 agents configured ─────────────────────────────────────────
echo "--- Test 3: All 3 agents configured ---"
if command -v node &>/dev/null; then
  AGENT_COUNT=$(node -e "var c=JSON.parse(require(\"fs\").readFileSync(process.argv[1],\"utf8\")); console.log(Object.keys(c.agents||{}).length)" "$CONFIG_FILE" 2>/dev/null)
  if [ "$AGENT_COUNT" = "3" ]; then
    echo "  [PASS] 3 agents configured"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] Expected 3 agents, found: ${AGENT_COUNT}"
    FAIL=$((FAIL + 1))
  fi

  # Check each agent by name
  for AGENT_NAME in claude codex openclaw; do
    HAS_AGENT=$(node -e "var c=JSON.parse(require(\"fs\").readFileSync(process.argv[1],\"utf8\")); console.log(c.agents[process.argv[2]]?\"yes\":\"no\")" "$CONFIG_FILE" "$AGENT_NAME" 2>/dev/null)
    if [ "$HAS_AGENT" = "yes" ]; then
      echo "  [PASS] Agent \"${AGENT_NAME}\" configured"
      PASS=$((PASS + 1))
    else
      echo "  [FAIL] Agent \"${AGENT_NAME}\" missing"
      FAIL=$((FAIL + 1))
    fi
  done
else
  echo "  [SKIP] Node.js not available for JSON parsing"
  SKIP=$((SKIP + 1))
fi

# ── Test 4: Crash recovery enabled ──────────────────────────────────────────
echo "--- Test 4: Crash recovery enabled ---"
if command -v node &>/dev/null; then
  CRASH_RECOVERY=$(node -e "var c=JSON.parse(require(\"fs\").readFileSync(process.argv[1],\"utf8\")); console.log(c.defaults&&c.defaults.crashRecovery===true?\"true\":\"false\")" "$CONFIG_FILE" 2>/dev/null)
  if [ "$CRASH_RECOVERY" = "true" ]; then
    echo "  [PASS] Crash recovery enabled"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] Crash recovery not enabled"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  [SKIP] Node.js not available"
  SKIP=$((SKIP + 1))
fi

# ── Test 5: Session persistence enabled ──────────────────────────────────────
echo "--- Test 5: Session persistence enabled ---"
if command -v node &>/dev/null; then
  SESSION_PERSIST=$(node -e "var c=JSON.parse(require(\"fs\").readFileSync(process.argv[1],\"utf8\")); console.log(c.defaults&&c.defaults.sessionPersistence===true?\"true\":\"false\")" "$CONFIG_FILE" 2>/dev/null)
  if [ "$SESSION_PERSIST" = "true" ]; then
    echo "  [PASS] Session persistence enabled"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] Session persistence not enabled"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  [SKIP] Node.js not available"
  SKIP=$((SKIP + 1))
fi

# ── Test 6: Session directory exists ─────────────────────────────────────────
echo "--- Test 6: Session directory exists ---"
if [ -d "$SESSION_DIR" ]; then
  echo "  [PASS] Session directory exists: ${SESSION_DIR}"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] Session directory missing: ${SESSION_DIR}"
  FAIL=$((FAIL + 1))
fi

# ── Test 7: Deployed config exists ───────────────────────────────────────────
echo "--- Test 7: Deployed config exists ---"
if [ -f "$DEPLOYED_CONFIG" ]; then
  echo "  [PASS] Deployed config exists: ${DEPLOYED_CONFIG}"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] Deployed config missing: ${DEPLOYED_CONFIG}"
  FAIL=$((FAIL + 1))
fi

# ── Test 8: Claude Code CLI availability ─────────────────────────────────────
echo "--- Test 8: Claude Code CLI ---"
if command -v claude &>/dev/null; then
  echo "  [PASS] Claude Code CLI available: $(which claude)"
  PASS=$((PASS + 1))
else
  echo "  [SKIP] Claude Code CLI not installed (optional for config test)"
  SKIP=$((SKIP + 1))
fi

# ── Test 9: Codex CLI availability ───────────────────────────────────────────
echo "--- Test 9: Codex CLI ---"
if command -v codex &>/dev/null; then
  echo "  [PASS] Codex CLI available: $(which codex)"
  PASS=$((PASS + 1))
else
  echo "  [SKIP] Codex CLI not installed (optional for config test)"
  SKIP=$((SKIP + 1))
fi

# ── Test 10: Live delegation (only if ANTHROPIC_API_KEY set) ─────────────────
echo "--- Test 10: Live delegation test ---"
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  if command -v claude &>/dev/null; then
    echo "  [SKIP] Live delegation tests not implemented yet (API key present)"
    SKIP=$((SKIP + 1))
  else
    echo "  [SKIP] Claude CLI not available for live test"
    SKIP=$((SKIP + 1))
  fi
else
  echo "  [SKIP] No ANTHROPIC_API_KEY — skipping live delegation tests"
  SKIP=$((SKIP + 1))
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  acpx Tests: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
else
  exit 0
fi
