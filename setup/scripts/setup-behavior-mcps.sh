#!/bin/bash
# setup-behavior-mcps.sh — Validate and prepare Behavior MCP servers for OpenClaw
# Creates directories, validates Python scripts compile, prints startup instructions.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
MCP_DIR="${REPO_DIR}/workspace/behavior-mcps"

SERVERS=(
  "task-router:9500"
  "memory-decision:9501"
  "self-eval:9502"
)

STATUS_DIRS="SKIP"
STATUS_COMPILE="SKIP"
STATUS_PERMS="SKIP"
COMPILE_PASS=0
COMPILE_FAIL=0

echo "============================================"
echo "  Behavior MCPs Setup"
echo "============================================"
echo ""

# ── 1. Create directories ───────────────────────────────────────────────────
echo "--- Creating directories ---"
ALL_DIRS_OK=true
for entry in "${SERVERS[@]}"; do
  NAME="${entry%%:*}"
  DIR="${MCP_DIR}/${NAME}"
  mkdir -p "$DIR"
  if [ -d "$DIR" ]; then
    echo "  [OK] ${DIR}"
  else
    echo "  [FAIL] Could not create ${DIR}"
    ALL_DIRS_OK=false
  fi
done
if [ "$ALL_DIRS_OK" = true ]; then
  STATUS_DIRS="OK"
else
  STATUS_DIRS="FAIL"
fi
echo ""

# ── 2. Check Python3 available ──────────────────────────────────────────────
echo "--- Checking Python3 ---"
if command -v python3 &>/dev/null; then
  PY_VER=$(python3 --version 2>&1)
  echo "  [OK] ${PY_VER}"
else
  echo "  [FAIL] python3 not found. Install Python 3.8+"
  echo ""
  echo "============================================"
  echo "  Setup FAILED: Python3 required"
  echo "============================================"
  exit 1
fi
echo ""

# ── 3. Validate scripts compile ─────────────────────────────────────────────
echo "--- Validating Python scripts ---"
for entry in "${SERVERS[@]}"; do
  NAME="${entry%%:*}"
  SERVER_FILE="${MCP_DIR}/${NAME}/server.py"
  if [ -f "$SERVER_FILE" ]; then
    if python3 -c "import py_compile,sys; py_compile.compile(sys.argv[1], doraise=True)" "$SERVER_FILE" 2>/dev/null; then
      echo "  [OK] ${NAME}/server.py compiles"
      COMPILE_PASS=$((COMPILE_PASS + 1))
    else
      echo "  [FAIL] ${NAME}/server.py has syntax errors"
      COMPILE_FAIL=$((COMPILE_FAIL + 1))
    fi
  else
    echo "  [FAIL] ${NAME}/server.py not found"
    COMPILE_FAIL=$((COMPILE_FAIL + 1))
  fi
done
if [ "$COMPILE_FAIL" -eq 0 ]; then
  STATUS_COMPILE="OK"
else
  STATUS_COMPILE="FAIL"
fi
echo ""

# ── 4. Ensure executable permissions ────────────────────────────────────────
echo "--- Setting executable permissions ---"
ALL_PERMS_OK=true
for entry in "${SERVERS[@]}"; do
  NAME="${entry%%:*}"
  SERVER_FILE="${MCP_DIR}/${NAME}/server.py"
  if [ -f "$SERVER_FILE" ]; then
    chmod +x "$SERVER_FILE"
    if [ -x "$SERVER_FILE" ]; then
      echo "  [OK] ${NAME}/server.py is executable"
    else
      echo "  [FAIL] Could not set executable on ${NAME}/server.py"
      ALL_PERMS_OK=false
    fi
  fi
done
if [ "$ALL_PERMS_OK" = true ]; then
  STATUS_PERMS="OK"
else
  STATUS_PERMS="FAIL"
fi
echo ""

# ── Status Summary ───────────────────────────────────────────────────────────
echo "============================================"
echo "  Behavior MCPs Setup Summary"
echo "============================================"
echo "  Directories:    ${STATUS_DIRS}"
echo "  Compilation:    ${STATUS_COMPILE} (${COMPILE_PASS}/3 passed)"
echo "  Permissions:    ${STATUS_PERMS}"
echo ""
echo "  How to start the servers:"
echo ""
for entry in "${SERVERS[@]}"; do
  NAME="${entry%%:*}"
  PORT="${entry##*:}"
  echo "    python3 ${MCP_DIR}/${NAME}/server.py --port ${PORT} &"
done
echo ""
echo "  Or start all at once:"
echo ""
echo "    for s in task-router:9500 memory-decision:9501 self-eval:9502; do"
echo "      NAME=\${s%%:*}; PORT=\${s##*:}"
echo "      python3 ${MCP_DIR}/\${NAME}/server.py --port \${PORT} &"
echo "    done"
echo ""
echo "  Health check endpoints:"
for entry in "${SERVERS[@]}"; do
  NAME="${entry%%:*}"
  PORT="${entry##*:}"
  echo "    curl http://localhost:${PORT}/health"
done
echo ""
echo "  Note: These can be Dockerized later with a"
echo "  docker-compose.yml in workspace/behavior-mcps/"
echo "============================================"

if [ "$STATUS_COMPILE" = "OK" ] && [ "$STATUS_DIRS" = "OK" ]; then
  echo "Setup complete. All servers validated."
  exit 0
else
  echo "Setup had failures. Check above for details."
  exit 1
fi
