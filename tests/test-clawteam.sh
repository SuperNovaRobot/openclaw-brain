#!/bin/bash
# test-clawteam.sh — Validate ClawTeam swarm orchestration deployment
# Checks team templates, spawn wrapper, and required dependencies.

REPO_DIR="/mnt/ssd/openclaw-brain"
TEAMS_DIR="${REPO_DIR}/workspace/teams"
SCRIPTS_DIR="${REPO_DIR}/workspace/scripts"
SETUP_DIR="${REPO_DIR}/setup/scripts"

PASS=0
FAIL=0
WARN=0

pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  [WARN] $1"; WARN=$((WARN + 1)); }

echo "============================================"
echo "  ClawTeam Swarm Orchestration Tests"
echo "============================================"
echo ""

# ── 1. Team templates exist ──────────────────────────────────────────────────
echo "--- Team Templates ---"

for TEMPLATE in full-stack research-swarm improvement-swarm; do
  TFILE="${TEAMS_DIR}/${TEMPLATE}.toml"
  if [ -f "$TFILE" ]; then
    pass "${TEMPLATE}.toml exists"
  else
    fail "${TEMPLATE}.toml not found at ${TFILE}"
  fi
done

# ── 2. TOML files have required fields ───────────────────────────────────────
echo "--- TOML Validation ---"

for TFILE in "$TEAMS_DIR"/*.toml; do
  [ -f "$TFILE" ] || continue
  BASENAME=$(basename "$TFILE")

  # Check [team] section
  if grep -q '^\[team\]' "$TFILE"; then
    pass "${BASENAME}: has [team] section"
  else
    fail "${BASENAME}: missing [team] section"
  fi

  # Check [[workers]] section
  if grep -q '^\[\[workers\]\]' "$TFILE"; then
    WORKER_COUNT=$(grep -c '^\[\[workers\]\]' "$TFILE")
    pass "${BASENAME}: has ${WORKER_COUNT} [[workers]] block(s)"
  else
    fail "${BASENAME}: missing [[workers]] section"
  fi

  # Check name field in [team]
  if grep -q '^name\s*=' "$TFILE"; then
    pass "${BASENAME}: has name field"
  else
    fail "${BASENAME}: missing name field"
  fi

  # Check [messaging] section
  if grep -q '^\[messaging\]' "$TFILE"; then
    pass "${BASENAME}: has [messaging] section"
  else
    fail "${BASENAME}: missing [messaging] section"
  fi
done

# ── 3. spawn-team.sh exists and is executable ────────────────────────────────
echo "--- Spawn Wrapper ---"

SPAWN="${SCRIPTS_DIR}/spawn-team.sh"
if [ -f "$SPAWN" ]; then
  pass "spawn-team.sh exists"
else
  fail "spawn-team.sh not found at ${SPAWN}"
fi

if [ -x "$SPAWN" ]; then
  pass "spawn-team.sh is executable"
else
  fail "spawn-team.sh is not executable"
fi

# ── 4. setup-clawteam.sh exists and is executable ────────────────────────────
echo "--- Setup Script ---"

SETUP="${SETUP_DIR}/setup-clawteam.sh"
if [ -f "$SETUP" ]; then
  pass "setup-clawteam.sh exists"
else
  fail "setup-clawteam.sh not found at ${SETUP}"
fi

if [ -x "$SETUP" ]; then
  pass "setup-clawteam.sh is executable"
else
  fail "setup-clawteam.sh is not executable"
fi

# ── 5. tmux availability ─────────────────────────────────────────────────────
echo "--- Dependencies ---"

if command -v tmux &>/dev/null; then
  pass "tmux is available"
else
  warn "tmux not found (required for swarm orchestration)"
fi

# ── 6. acpx availability ─────────────────────────────────────────────────────
if command -v acpx &>/dev/null; then
  pass "acpx is available"
else
  warn "acpx not found (required for agent spawning)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Results: ${PASS} passed, ${FAIL} failed, ${WARN} warnings"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
