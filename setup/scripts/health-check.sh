#!/bin/bash

echo "=== OpenClaw Brain Health Check ==="
echo ""

PASS=0
FAIL=0

check() {
  local name="$1"
  local cmd="$2"
  if eval "$cmd" &>/dev/null; then
    echo "  [PASS] $name"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $name"
    FAIL=$((FAIL + 1))
  fi
}

echo "Services:"
check "PostgreSQL"     "docker exec setup-postgres-1 pg_isready -U openclaw -h 127.0.0.1"
check "Elasticsearch"  "curl -sf http://localhost:9200/_cluster/health"
check "Redis"          "docker exec setup-redis-1 redis-cli ping"
check "Memos"          "curl -sf http://localhost:5230/"
check "crawl4ai"       "curl -sf http://localhost:11235/health"

echo ""
echo "Inference:"
check "nova-rig"       "curl -sf http://${RIG_HOST:-nova-rig}:8080/health"

echo ""
echo "Disk:"
USAGE=$(df /mnt/ssd --output=pcent | tail -1 | tr -d ' %')
if [ "$USAGE" -lt 85 ]; then
  echo "  [PASS] Disk usage: ${USAGE}%"
  PASS=$((PASS + 1))
else
  echo "  [WARN] Disk usage: ${USAGE}% (>85%)"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "Memory:"
AVAIL=$(free -g | grep '^Mem:' | awk '{print $7}')
echo "  [INFO] Available: ${AVAIL}GB"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
