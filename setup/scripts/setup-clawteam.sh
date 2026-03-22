#!/bin/bash
# setup-clawteam.sh — Install and configure ClawTeam swarm orchestration
# Creates team templates, workspace directories, and the spawn-team wrapper.
# If clawteam CLI is not available (alpha), falls back to acpx + tmux.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEAMS_DIR="${REPO_DIR}/workspace/teams"
SCRIPTS_DIR="${REPO_DIR}/workspace/scripts"

STATUS_TMUX="SKIP"
STATUS_ACPX="SKIP"
STATUS_CLAWTEAM="SKIP"
STATUS_TEAMS="SKIP"
STATUS_SPAWN="SKIP"

echo "============================================"
echo "  ClawTeam Swarm Orchestration Setup"
echo "============================================"
echo ""

# ── 1. Check tmux ────────────────────────────────────────────────────────────
echo "--- Checking tmux ---"
if command -v tmux &>/dev/null; then
  TMUX_VERSION=$(tmux -V 2>/dev/null)
  echo "  [OK] ${TMUX_VERSION}"
  STATUS_TMUX="OK"
else
  echo "  [WARN] tmux not found. Install with: sudo apt install tmux"
  echo "         Swarm orchestration requires tmux for parallel sessions."
  STATUS_TMUX="WARN"
fi

# ── 2. Check acpx ────────────────────────────────────────────────────────────
echo "--- Checking acpx ---"
if command -v acpx &>/dev/null; then
  echo "  [OK] acpx found at $(which acpx)"
  STATUS_ACPX="OK"
else
  echo "  [WARN] acpx not found in PATH."
  echo "         Run setup-acpx.sh first or add acpx to PATH."
  STATUS_ACPX="WARN"
fi

# ── 3. Check clawteam (alpha — may not exist yet) ────────────────────────────
echo "--- Checking clawteam ---"
if command -v clawteam &>/dev/null; then
  echo "  [OK] clawteam found at $(which clawteam)"
  STATUS_CLAWTEAM="OK"
elif pip3 show clawteam &>/dev/null 2>&1; then
  echo "  [OK] clawteam installed via pip (not in PATH)"
  STATUS_CLAWTEAM="OK"
else
  echo "  [INFO] clawteam not installed (alpha package — this is expected)."
  echo "         The spawn-team.sh wrapper provides equivalent functionality"
  echo "         using acpx + tmux directly."
  STATUS_CLAWTEAM="SKIP"
fi

# ── 4. Ensure team templates directory exists ─────────────────────────────────
echo "--- Checking team templates ---"
mkdir -p "$TEAMS_DIR"
TEMPLATE_COUNT=$(ls "$TEAMS_DIR"/*.toml 2>/dev/null | wc -l)
if [ "$TEMPLATE_COUNT" -gt 0 ]; then
  echo "  [OK] ${TEMPLATE_COUNT} team template(s) found in ${TEAMS_DIR}/"
  for f in "$TEAMS_DIR"/*.toml; do
    TNAME=$(grep -m1 names*= "$f" 2>/dev/null | head -1 | sed s/.*=s*\(.*\)/1/)
    echo "        - $(basename "$f"): ${TNAME}"
  done
  STATUS_TEAMS="OK"
else
  echo "  [WARN] No team templates found in ${TEAMS_DIR}/"
  echo "         Expected: full-stack.toml, research-swarm.toml, improvement-swarm.toml"
  STATUS_TEAMS="WARN"
fi

# ── 5. Ensure spawn-team.sh wrapper exists and is executable ──────────────────
echo "--- Checking spawn-team.sh wrapper ---"
SPAWN_SCRIPT="${SCRIPTS_DIR}/spawn-team.sh"
if [ -f "$SPAWN_SCRIPT" ] && [ -x "$SPAWN_SCRIPT" ]; then
  echo "  [OK] spawn-team.sh exists and is executable"
  STATUS_SPAWN="OK"
else
  if [ -f "$SPAWN_SCRIPT" ]; then
    chmod +x "$SPAWN_SCRIPT"
    echo "  [FIXED] spawn-team.sh made executable"
    STATUS_SPAWN="OK"
  else
    echo "  [WARN] spawn-team.sh not found at ${SPAWN_SCRIPT}"
    echo "         This script should be created as part of the ClawTeam deployment."
    STATUS_SPAWN="WARN"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  ClawTeam Setup Summary"
echo "============================================"
echo "  tmux:       ${STATUS_TMUX}"
echo "  acpx:       ${STATUS_ACPX}"
echo "  clawteam:   ${STATUS_CLAWTEAM}"
echo "  templates:  ${STATUS_TEAMS}"
echo "  spawn-team: ${STATUS_SPAWN}"
echo "============================================"

if [ "$STATUS_TMUX" = "WARN" ]; then
  echo ""
  echo "NOTE: tmux is required for swarm orchestration."
  echo "      Install it with: sudo apt install tmux"
fi

if [ "$STATUS_CLAWTEAM" = "SKIP" ]; then
  echo ""
  echo "NOTE: clawteam is not yet available (alpha). spawn-team.sh"
  echo "      provides equivalent functionality using acpx + tmux."
  echo "      When clawteam is released, run: pip install clawteam"
fi
