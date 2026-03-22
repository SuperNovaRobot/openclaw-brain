#!/bin/bash
set -euo pipefail

echo "=== OpenClaw Brain Health Check ==="
echo ""

PASS=0
FAIL=0

check() {
  local name="$1"
  local cmd="$2"
  if eval "$cmd" &>/dev/null; then
    echo "  [PASS] $name"
    ((PASS++))
  else
    echo "  [FAIL] $name"
    ((FAIL++))
  fi
}

echo "Services:"
check "PostgreSQL"     "docker compose -f setup/docker-compose.nova.yml exec -T postgres pg_isready -U openclaw"
check "Elasticsearch"  "curl -sf http://localhost:9200/_cluster/health"
check "Redis"          "docker compose -f setup/docker-compose.nova.yml exec -T redis redis-cli ping"
check "RagFlow"        "curl -sf http://localhost:9380/api/v1/datasets"
check "Memos"          "curl -sf http://localhost:5230/api/v1/memos"
check "SurfSense"      "curl -sf http://localhost:8000/health"
check "crawl4ai"       "curl -sf http://localhost:11235/health"

echo ""
echo "Inference:"
check "vLLM"           "curl -sf http://${RIG_HOST:-nova-rig}:8080/health"

echo ""
echo "MCP Servers:"
check "obsidian-cli"   "obsidian-cli info"

echo ""
echo "Agent:"
check "OpenClaw Gateway" "curl -sf http://localhost:18789/health"

echo ""
echo "Disk:"
USAGE=$(df /mnt/ssd --output=pcent | tail -1 | tr -d ' %')
if [ "$USAGE" -lt 80 ]; then
  echo "  [PASS] Disk usage: ${USAGE}%"
  ((PASS++))
else
  echo "  [WARN] Disk usage: ${USAGE}% (>80%)"
  ((FAIL++))
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
