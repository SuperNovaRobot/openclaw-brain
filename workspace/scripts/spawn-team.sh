#!/bin/bash
# spawn-team.sh — Spawn a team of parallel agents
# Works with or without clawteam installed.
# Uses acpx + tmux directly when clawteam is not available.
#
# Usage: ./spawn-team.sh <template-name> [--task-1 "prompt"] [--task-2 "prompt"] ...
# Example: ./spawn-team.sh full-stack --task-1 "Build REST API" --task-2 "Build React UI"
#
# Tasks are assigned to workers in order. If fewer tasks than workers,
# remaining workers use their default task from the template.

set -euo pipefail

TEMPLATE="${1:?Usage: spawn-team.sh <template-name> [--task-1 \"prompt\"] [--task-2 \"prompt\"] ...}"
shift

TEAMS_DIR="/mnt/ssd/openclaw-brain/workspace/teams"
TEMPLATE_FILE="$TEAMS_DIR/${TEMPLATE}.toml"
LOGS_DIR="/mnt/ssd/logs/clawteam"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "ERROR: Template not found: $TEMPLATE_FILE"
  echo "Available templates:"
  for t in "$TEAMS_DIR"/*.toml 2>/dev/null; do
    [ -f "$t" ] && echo "  - $(basename "$t" .toml)"
  done
  exit 1
fi

# ── Parse CLI task overrides ──────────────────────────────────────────────────
declare -A TASK_OVERRIDES
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-*)
      TASK_NUM="${1#--task-}"
      shift
      TASK_OVERRIDES["$TASK_NUM"]="${1:?Missing task prompt for --task-${TASK_NUM}}"
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# ── Preflight checks ─────────────────────────────────────────────────────────
if ! command -v tmux &>/dev/null; then
  echo "ERROR: tmux is required for swarm orchestration."
  echo "       Install with: sudo apt install tmux"
  exit 1
fi

# ── Parse TOML template (basic grep-based parser) ────────────────────────────
TEAM_NAME=$(grep -m1 '^name\s*=' "$TEMPLATE_FILE" | sed 's/.*=\s*"\(.*\)"/\1/')
TEAM_DESC=$(grep -m1 '^description\s*=' "$TEMPLATE_FILE" | sed 's/.*=\s*"\(.*\)"/\1/')

# Extract worker blocks
declare -a WORKER_NAMES=()
declare -a WORKER_AGENTS=()
declare -a WORKER_SESSIONS=()
declare -a WORKER_TASKS=()
declare -a WORKER_BLOCKED_BY=()

WORKER_IDX=-1
while IFS= read -r line; do
  # Trim whitespace
  line="$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"

  if [[ "$line" == "[[workers]]" ]]; then
    WORKER_IDX=$((WORKER_IDX + 1))
    WORKER_NAMES[$WORKER_IDX]=""
    WORKER_AGENTS[$WORKER_IDX]=""
    WORKER_SESSIONS[$WORKER_IDX]=""
    WORKER_TASKS[$WORKER_IDX]=""
    WORKER_BLOCKED_BY[$WORKER_IDX]=""
    continue
  fi

  if [[ $WORKER_IDX -lt 0 ]]; then
    continue
  fi

  case "$line" in
    name\ =*)
      WORKER_NAMES[$WORKER_IDX]="$(echo "$line" | sed 's/.*=\s*"\(.*\)"/\1/')"
      ;;
    agent\ =*)
      WORKER_AGENTS[$WORKER_IDX]="$(echo "$line" | sed 's/.*=\s*"\(.*\)"/\1/')"
      ;;
    session\ =*)
      WORKER_SESSIONS[$WORKER_IDX]="$(echo "$line" | sed 's/.*=\s*"\(.*\)"/\1/')"
      ;;
    task\ =*)
      WORKER_TASKS[$WORKER_IDX]="$(echo "$line" | sed 's/.*=\s*"\([^"]*\)".*/\1/')"
      ;;
    blocked_by\ =*)
      WORKER_BLOCKED_BY[$WORKER_IDX]="$(echo "$line" | sed 's/.*=\s*\[//;s/\].*//;s/"//g;s/,/ /g')"
      ;;
  esac
done < "$TEMPLATE_FILE"

WORKER_COUNT=$((WORKER_IDX + 1))

echo "============================================"
echo "  Spawning Team: ${TEAM_NAME}"
echo "  ${TEAM_DESC}"
echo "  Workers: ${WORKER_COUNT}"
echo "============================================"
echo ""

# ── Apply task overrides ──────────────────────────────────────────────────────
for i in $(seq 1 $WORKER_COUNT); do
  if [[ -n "${TASK_OVERRIDES[$i]:-}" ]]; then
    IDX=$((i - 1))
    WORKER_TASKS[$IDX]="${TASK_OVERRIDES[$i]}"
  fi
done

# ── Create log directory ─────────────────────────────────────────────────────
mkdir -p "$LOGS_DIR"

# ── Try native clawteam first ────────────────────────────────────────────────
if command -v clawteam &>/dev/null; then
  echo "[clawteam] Native clawteam detected — delegating to clawteam CLI."
  exec clawteam spawn "$TEMPLATE_FILE" "$@"
fi

echo "[acpx+tmux] Using acpx + tmux fallback (clawteam not installed)."
echo ""

# ── Determine launch order (respect blocked_by dependencies) ──────────────────
declare -A LAUNCHED
declare -a LAUNCH_ORDER=()
declare -a DEFERRED=()

# First pass: launch workers with no blockers
for i in $(seq 0 $((WORKER_COUNT - 1))); do
  if [[ -z "${WORKER_BLOCKED_BY[$i]}" ]]; then
    LAUNCH_ORDER+=("$i")
    LAUNCHED["${WORKER_NAMES[$i]}"]="1"
  else
    DEFERRED+=("$i")
  fi
done

# Subsequent passes: launch deferred workers whose blockers are all launched
MAX_PASSES=10
PASS=0
while [[ ${#DEFERRED[@]} -gt 0 && $PASS -lt $MAX_PASSES ]]; do
  PASS=$((PASS + 1))
  STILL_DEFERRED=()
  for i in "${DEFERRED[@]}"; do
    ALL_MET=true
    for blocker in ${WORKER_BLOCKED_BY[$i]}; do
      if [[ -z "${LAUNCHED[$blocker]:-}" ]]; then
        ALL_MET=false
        break
      fi
    done
    if $ALL_MET; then
      LAUNCH_ORDER+=("$i")
      LAUNCHED["${WORKER_NAMES[$i]}"]="1"
    else
      STILL_DEFERRED+=("$i")
    fi
  done
  DEFERRED=("${STILL_DEFERRED[@]}")
done

if [[ ${#DEFERRED[@]} -gt 0 ]]; then
  echo "WARNING: Circular dependency detected. Launching remaining workers anyway."
  for i in "${DEFERRED[@]}"; do
    LAUNCH_ORDER+=("$i")
  done
fi

# ── Create tmux session for the team ──────────────────────────────────────────
TMUX_SESSION="clawteam-${TEAM_NAME}-${TIMESTAMP}"
tmux new-session -d -s "$TMUX_SESSION" -n "orchestrator"
echo "[tmux] Created session: $TMUX_SESSION"

# ── Launch workers ────────────────────────────────────────────────────────────
ACPX_CMD="acpx"
if ! command -v acpx &>/dev/null; then
  echo "[WARN] acpx not in PATH — will use echo placeholders."
  echo "       Install acpx first: run setup-acpx.sh"
  ACPX_CMD="echo [DRY-RUN] acpx"
fi

for i in "${LAUNCH_ORDER[@]}"; do
  WNAME="${WORKER_NAMES[$i]}"
  WAGENT="${WORKER_AGENTS[$i]}"
  WSESSION="${WORKER_SESSIONS[$i]}"
  WTASK="${WORKER_TASKS[$i]}"
  WBLOCKED="${WORKER_BLOCKED_BY[$i]}"
  LOG_FILE="${LOGS_DIR}/${TEAM_NAME}-${WNAME}-${TIMESTAMP}.log"

  echo "  Launching: ${WNAME} (agent=${WAGENT}, session=${WSESSION})"

  if [[ -n "$WBLOCKED" ]]; then
    echo "    blocked_by: [${WBLOCKED}] (predecessors already launched)"
  fi

  if [[ -z "$WTASK" ]]; then
    echo "    [SKIP] No task assigned to ${WNAME}. Use --task-$((i+1)) to assign."
    continue
  fi

  # Create a tmux window for this worker
  tmux new-window -t "$TMUX_SESSION" -n "$WNAME"

  # Launch acpx in the tmux window
  tmux send-keys -t "${TMUX_SESSION}:${WNAME}" \
    "${ACPX_CMD} session start --agent ${WAGENT} --name ${WSESSION} --prompt '${WTASK}' 2>&1 | tee ${LOG_FILE}" Enter

  echo "    [OK] ${WNAME} launched in tmux window, logging to ${LOG_FILE}"
done

echo ""
echo "============================================"
echo "  Team ${TEAM_NAME} spawned successfully"
echo "============================================"
echo "  tmux session: ${TMUX_SESSION}"
echo "  Attach with:  tmux attach -t ${TMUX_SESSION}"
echo "  List windows: tmux list-windows -t ${TMUX_SESSION}"
echo "  Logs:         ${LOGS_DIR}/"
echo "============================================"
