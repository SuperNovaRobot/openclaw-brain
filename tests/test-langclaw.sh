#!/bin/bash
# test-langclaw.sh — Integration tests for langclaw LangChain bridge
# Uses safe counter pattern (no set -e, no ((PASS++)))

PASS=0
FAIL=0
SKIP=0

REPO_DIR="/mnt/ssd/openclaw-brain"
CONFIG_FILE="${HOME}/.openclaw/langclaw/config.json"

echo "============================================"
echo "  langclaw Integration Tests"
echo "============================================"
echo ""

# ── Test 1: Config file exists ───────────────────────────────────────────────
echo "--- Test 1: Config file exists ---"
if [ -f "$CONFIG_FILE" ]; then
  echo "  [PASS] Config file exists: ${CONFIG_FILE}"
  PASS=$((PASS + 1))
else
  echo "  [FAIL] Config file missing: ${CONFIG_FILE}"
  echo "  Run: setup/scripts/setup-langclaw.sh"
  FAIL=$((FAIL + 1))
fi

# ── Test 2: Config is valid JSON ─────────────────────────────────────────────
echo "--- Test 2: Config is valid JSON ---"
if [ -f "$CONFIG_FILE" ]; then
  if command -v python3 &>/dev/null; then
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
    echo "  [SKIP] No JSON validator available (need python3 or jq)"
    SKIP=$((SKIP + 1))
  fi
else
  echo "  [SKIP] Config file not present"
  SKIP=$((SKIP + 1))
fi

# Helper: extract a JSON field using python3
# Usage: json_get <file> <dotted.key.path>
json_get() {
  python3 - "$1" "$2" << 'PYHELPER'
import json, sys
data = json.load(open(sys.argv[1]))
keys = sys.argv[2].split(".")
val = data
for k in keys:
    if isinstance(val, dict):
        val = val.get(k, "")
    else:
        val = ""
        break
print(val)
PYHELPER
}

# ── Test 3: Config has gateway field ─────────────────────────────────────────
echo "--- Test 3: Config has gateway endpoint ---"
if [ -f "$CONFIG_FILE" ] && command -v python3 &>/dev/null; then
  GATEWAY=$(json_get "$CONFIG_FILE" "gateway" 2>/dev/null)
  if [ -n "$GATEWAY" ]; then
    echo "  [PASS] Gateway configured: ${GATEWAY}"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] Gateway not configured"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  [SKIP] Cannot check gateway (config or python3 missing)"
  SKIP=$((SKIP + 1))
fi

# ── Test 4: Config has middleware section ─────────────────────────────────────
echo "--- Test 4: Config has middleware ---"
if [ -f "$CONFIG_FILE" ] && command -v python3 &>/dev/null; then
  HAS_MW=$(python3 - "$CONFIG_FILE" << 'PYHELPER'
import json, sys
c = json.load(open(sys.argv[1]))
print("yes" if "middleware" in c else "no")
PYHELPER
  )
  if [ "$HAS_MW" = "yes" ]; then
    echo "  [PASS] Middleware section present"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] Middleware section missing"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  [SKIP] Cannot check middleware"
  SKIP=$((SKIP + 1))
fi

# ── Test 5: Rate limiting enabled ────────────────────────────────────────────
echo "--- Test 5: Rate limiting enabled ---"
if [ -f "$CONFIG_FILE" ] && command -v python3 &>/dev/null; then
  RL_ENABLED=$(python3 - "$CONFIG_FILE" << 'PYHELPER'
import json, sys
c = json.load(open(sys.argv[1]))
rl = c.get("middleware", {}).get("rate_limiting", {})
print("yes" if rl.get("enabled") else "no")
PYHELPER
  )
  if [ "$RL_ENABLED" = "yes" ]; then
    echo "  [PASS] Rate limiting enabled"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] Rate limiting not enabled"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  [SKIP] Cannot check rate limiting"
  SKIP=$((SKIP + 1))
fi

# ── Test 6: langclaw Python package available ────────────────────────────────
echo "--- Test 6: langclaw importable ---"
if command -v python3 &>/dev/null; then
  if python3 -c "import langclaw" 2>/dev/null; then
    echo "  [PASS] langclaw is importable"
    PASS=$((PASS + 1))
  else
    echo "  [SKIP] langclaw not importable (package not yet available — expected)"
    SKIP=$((SKIP + 1))
  fi
else
  echo "  [SKIP] python3 not available"
  SKIP=$((SKIP + 1))
fi

# ── Test 7: PostgreSQL reachable for session persistence ─────────────────────
echo "--- Test 7: PostgreSQL reachable ---"
if [ -f "$CONFIG_FILE" ] && command -v python3 &>/dev/null; then
  PG_HOST=$(python3 - "$CONFIG_FILE" << 'PYHELPER'
import json, sys
c = json.load(open(sys.argv[1]))
conn = c.get("session_persistence", {}).get("connection", "")
if "@" in conn:
    hostport = conn.split("@")[1].split("/")[0]
    host = hostport.split(":")[0]
    port = hostport.split(":")[1] if ":" in hostport else "5432"
    print(host + ":" + port)
PYHELPER
  )

  if [ -n "$PG_HOST" ]; then
    PG_HOSTONLY=$(echo "$PG_HOST" | cut -d: -f1)
    PG_PORT=$(echo "$PG_HOST" | cut -d: -f2)
    if command -v pg_isready &>/dev/null; then
      if pg_isready -h "$PG_HOSTONLY" -p "$PG_PORT" -t 5 &>/dev/null; then
        echo "  [PASS] PostgreSQL reachable at ${PG_HOST}"
        PASS=$((PASS + 1))
      else
        echo "  [FAIL] PostgreSQL not reachable at ${PG_HOST}"
        FAIL=$((FAIL + 1))
      fi
    elif command -v nc &>/dev/null; then
      if nc -z -w 5 "$PG_HOSTONLY" "$PG_PORT" 2>/dev/null; then
        echo "  [PASS] PostgreSQL port reachable at ${PG_HOST}"
        PASS=$((PASS + 1))
      else
        echo "  [FAIL] PostgreSQL port not reachable at ${PG_HOST}"
        FAIL=$((FAIL + 1))
      fi
    elif bash -c "echo >/dev/tcp/${PG_HOSTONLY}/${PG_PORT}" 2>/dev/null; then
      echo "  [PASS] PostgreSQL port reachable at ${PG_HOST}"
      PASS=$((PASS + 1))
    else
      echo "  [FAIL] PostgreSQL not reachable at ${PG_HOST} (no pg_isready or nc)"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  [SKIP] Could not parse PostgreSQL connection from config"
    SKIP=$((SKIP + 1))
  fi
else
  echo "  [SKIP] Cannot check PostgreSQL (config or python3 missing)"
  SKIP=$((SKIP + 1))
fi

# ── Test 8: Session persistence backend configured ───────────────────────────
echo "--- Test 8: Session persistence backend ---"
if [ -f "$CONFIG_FILE" ] && command -v python3 &>/dev/null; then
  SP_BACKEND=$(json_get "$CONFIG_FILE" "session_persistence.backend" 2>/dev/null)
  if [ "$SP_BACKEND" = "postgresql" ]; then
    echo "  [PASS] Session persistence backend: ${SP_BACKEND}"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] Expected postgresql, got: ${SP_BACKEND}"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  [SKIP] Cannot check session persistence"
  SKIP=$((SKIP + 1))
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  langclaw Tests: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
else
  exit 0
fi
