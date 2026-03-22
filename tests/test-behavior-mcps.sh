#!/bin/bash
# test-behavior-mcps.sh — Validation tests for Behavior MCP servers
# Checks files exist, compile, and show help. Does NOT start servers.
# Uses safe counter pattern (no set -e, no ((PASS++)))

PASS=0
FAIL=0
SKIP=0

REPO_DIR="/mnt/ssd/openclaw-brain"
MCP_DIR="${REPO_DIR}/workspace/behavior-mcps"

SERVERS=(
  "task-router:9500"
  "memory-decision:9501"
  "self-eval:9502"
)

echo "============================================"
echo "  Behavior MCPs Validation Tests"
echo "============================================"
echo ""

# ── Test 1: All server.py files exist ────────────────────────────────────────
echo "--- Test 1: Server files exist ---"
for entry in "${SERVERS[@]}"; do
  NAME="${entry%%:*}"
  SERVER_FILE="${MCP_DIR}/${NAME}/server.py"
  if [ -f "$SERVER_FILE" ]; then
    echo "  [PASS] ${NAME}/server.py exists"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] ${NAME}/server.py missing"
    FAIL=$((FAIL + 1))
  fi
done

# ── Test 2: All server.py files are executable ──────────────────────────────
echo "--- Test 2: Server files are executable ---"
for entry in "${SERVERS[@]}"; do
  NAME="${entry%%:*}"
  SERVER_FILE="${MCP_DIR}/${NAME}/server.py"
  if [ -x "$SERVER_FILE" ]; then
    echo "  [PASS] ${NAME}/server.py is executable"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] ${NAME}/server.py is not executable"
    FAIL=$((FAIL + 1))
  fi
done

# ── Test 3: All server.py files compile ──────────────────────────────────────
echo "--- Test 3: Server files compile ---"
if command -v python3 &>/dev/null; then
  for entry in "${SERVERS[@]}"; do
    NAME="${entry%%:*}"
    SERVER_FILE="${MCP_DIR}/${NAME}/server.py"
    if [ -f "$SERVER_FILE" ]; then
      if python3 -c "import py_compile,sys; py_compile.compile(sys.argv[1], doraise=True)" "$SERVER_FILE" 2>/dev/null; then
        echo "  [PASS] ${NAME}/server.py compiles"
        PASS=$((PASS + 1))
      else
        echo "  [FAIL] ${NAME}/server.py has syntax errors"
        FAIL=$((FAIL + 1))
      fi
    else
      echo "  [SKIP] ${NAME}/server.py not found"
      SKIP=$((SKIP + 1))
    fi
  done
else
  echo "  [SKIP] python3 not available"
  SKIP=$((SKIP + 1))
fi

# ── Test 4: All server.py show --help ────────────────────────────────────────
echo "--- Test 4: Server --help works ---"
if command -v python3 &>/dev/null; then
  for entry in "${SERVERS[@]}"; do
    NAME="${entry%%:*}"
    SERVER_FILE="${MCP_DIR}/${NAME}/server.py"
    if [ -f "$SERVER_FILE" ]; then
      HELP_OUT=$(python3 "$SERVER_FILE" --help 2>&1)
      if [ $? -eq 0 ] && [ -n "$HELP_OUT" ]; then
        echo "  [PASS] ${NAME}/server.py --help works"
        PASS=$((PASS + 1))
      else
        echo "  [FAIL] ${NAME}/server.py --help failed"
        FAIL=$((FAIL + 1))
      fi
    else
      echo "  [SKIP] ${NAME}/server.py not found"
      SKIP=$((SKIP + 1))
    fi
  done
else
  echo "  [SKIP] python3 not available"
  SKIP=$((SKIP + 1))
fi

# ── Test 5: Only stdlib imports ──────────────────────────────────────────────
echo "--- Test 5: Stdlib-only imports ---"
for entry in "${SERVERS[@]}"; do
  NAME="${entry%%:*}"
  SERVER_FILE="${MCP_DIR}/${NAME}/server.py"
  if [ -f "$SERVER_FILE" ]; then
    # Check that imports are only from stdlib
    NON_STD=$(python3 -c "
import ast, sys
with open(sys.argv[1]) as f:
    tree = ast.parse(f.read())
stdlib = {json,sys,os,http,http.server,functools,io,
          urllib,hashlib,pathlib,re,datetime,collections,
          typing,argparse,socket,threading,time,signal}
bad = []
for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        for alias in node.names:
            top = alias.name.split(.)[0]
            if top not in stdlib:
                bad.append(alias.name)
    elif isinstance(node, ast.ImportFrom):
        if node.module:
            top = node.module.split(.)[0]
            if top not in stdlib:
                bad.append(node.module)
if bad:
    print(,.join(bad))
" "$SERVER_FILE" 2>/dev/null)
    if [ -z "$NON_STD" ]; then
      echo "  [PASS] ${NAME}/server.py uses only stdlib"
      PASS=$((PASS + 1))
    else
      echo "  [FAIL] ${NAME}/server.py has non-stdlib imports: ${NON_STD}"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  [SKIP] ${NAME}/server.py not found"
    SKIP=$((SKIP + 1))
  fi
done

# ── Test 6: Default ports are distinct ───────────────────────────────────────
echo "--- Test 6: Default ports are distinct ---"
PORTS=""
ALL_DISTINCT=true
for entry in "${SERVERS[@]}"; do
  PORT="${entry##*:}"
  if echo "$PORTS" | grep -q ":${PORT}:"; then
    echo "  [FAIL] Duplicate port: ${PORT}"
    FAIL=$((FAIL + 1))
    ALL_DISTINCT=false
  fi
  PORTS="${PORTS}:${PORT}:"
done
if [ "$ALL_DISTINCT" = true ]; then
  echo "  [PASS] All default ports are distinct (9500, 9501, 9502)"
  PASS=$((PASS + 1))
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Behavior MCPs Tests: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
else
  exit 0
fi
