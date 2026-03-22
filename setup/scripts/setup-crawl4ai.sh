#!/bin/bash
set -euo pipefail

echo "=== Setting up crawl4ai ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

source "${REPO_DIR}/setup/.env" 2>/dev/null || true

CRAWL4AI_HOST="http://localhost:${CRAWL4AI_PORT:-11235}"

# ── Wait for crawl4ai to be healthy ─────────────────────────────────────────
echo "Waiting for crawl4ai at ${CRAWL4AI_HOST}..."
for i in $(seq 1 30); do
  if curl -sf "${CRAWL4AI_HOST}/health" &>/dev/null; then
    echo "crawl4ai is ready."
    break
  fi
  # Try root endpoint as fallback
  if curl -sf "${CRAWL4AI_HOST}/" &>/dev/null; then
    echo "crawl4ai is ready (root endpoint responding)."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: crawl4ai not ready after 60s."
    echo "Check logs: docker compose -f setup/docker-compose.nova.yml logs crawl4ai"
    exit 1
  fi
  sleep 2
done

# ── Verify basic crawl capability ───────────────────────────────────────────
echo "Running test crawl..."

TEST_URL="https://httpbin.org/html"
CRAWL_RESPONSE=$(curl -sf -X POST "${CRAWL4AI_HOST}/crawl" \
  -H "Content-Type: application/json" \
  -d "{
    \"urls\": [\"${TEST_URL}\"],
    \"word_count_threshold\": 10,
    \"extraction_strategy\": \"NoExtractionStrategy\"
  }" 2>/dev/null || echo "")

if [ -n "$CRAWL_RESPONSE" ]; then
  # Check if response contains crawled content or a task ID
  if echo "$CRAWL_RESPONSE" | grep -qiE '"success"|"task_id"|"result"|"content"|"html"' 2>/dev/null; then
    echo "  [OK] Test crawl succeeded."
  else
    echo "  [WARN] Test crawl returned unexpected response."
    echo "  Response preview: $(echo "$CRAWL_RESPONSE" | head -c 200)"
  fi
else
  echo "  [WARN] Test crawl got no response. Trying alternative endpoint..."

  # Try async crawl endpoint
  ASYNC_RESPONSE=$(curl -sf -X POST "${CRAWL4AI_HOST}/crawl_async" \
    -H "Content-Type: application/json" \
    -d "{\"urls\": [\"${TEST_URL}\"]}" 2>/dev/null || echo "")

  if [ -n "$ASYNC_RESPONSE" ]; then
    echo "  [OK] Async crawl endpoint responding."
  else
    echo "  [WARN] Crawl endpoints not responding. Service may still be initializing."
    echo "  This is normal on first start — Chromium needs to download."
  fi
fi

# ── Print crawl4ai info ─────────────────────────────────────────────────────
echo ""
echo "crawl4ai setup complete."
echo "  Endpoint:    ${CRAWL4AI_HOST}"
echo "  Test URL:    ${TEST_URL}"
echo "  Usage:       POST ${CRAWL4AI_HOST}/crawl with {\"urls\": [\"...\"]}"
echo "  Docs:        Already available at ~/sickGit/crawl4ai"
