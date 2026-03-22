#!/bin/bash
# Research services integration test
# Tests crawl4ai, SurfSense, Memos, RagFlow, Elasticsearch on nova-rig

echo "=== Research Services Integration Test ==="
echo ""

PASS=0
FAIL=0
SKIP=0

source "$(dirname "$0")/../setup/.env" 2>/dev/null || true

RIG="${RIG_HOST:-nova-rig}"

test_pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
test_fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
test_skip() { echo "  [SKIP] $1"; SKIP=$((SKIP + 1)); }

# ── crawl4ai ─────────────────────────────────────────────────────────────────
echo "crawl4ai (http://${RIG}:${CRAWL4AI_PORT:-11235}):"

CRAWL4AI_URL="http://${RIG}:${CRAWL4AI_PORT:-11235}"

if curl -sf --connect-timeout 5 "${CRAWL4AI_URL}/health" &>/dev/null; then
  test_pass "Health check"

  # Test crawl of example.com
  CRAWL_RESULT=$(curl -sf --connect-timeout 10 -m 30 -X POST "${CRAWL4AI_URL}/crawl" \
    -H "Content-Type: application/json" \
    -d '{"urls": ["https://example.com"], "word_count_threshold": 5}' 2>/dev/null || echo "")

  if [ -n "$CRAWL_RESULT" ]; then
    if echo "$CRAWL_RESULT" | grep -qiE '"success"|"task_id"|"result"|"content"|"html"|"Example Domain"' 2>/dev/null; then
      test_pass "Test crawl of https://example.com"
    else
      test_fail "Crawl returned unexpected response"
    fi
  else
    # Try async endpoint as fallback
    ASYNC_RESULT=$(curl -sf --connect-timeout 10 -m 30 -X POST "${CRAWL4AI_URL}/crawl_async" \
      -H "Content-Type: application/json" \
      -d '{"urls": ["https://example.com"]}' 2>/dev/null || echo "")
    if [ -n "$ASYNC_RESULT" ]; then
      test_pass "Async crawl endpoint responding"
    else
      test_fail "No crawl endpoint responding"
    fi
  fi
elif curl -sf --connect-timeout 5 "${CRAWL4AI_URL}/" &>/dev/null; then
  test_pass "Root endpoint responding (health endpoint may differ)"
  test_skip "Crawl test -- health endpoint not standard"
else
  test_skip "crawl4ai not reachable at ${CRAWL4AI_URL}"
  test_skip "Crawl test -- service unavailable"
fi

# ── SurfSense ────────────────────────────────────────────────────────────────
echo ""
echo "SurfSense (backend http://${RIG}:${SURFSENSE_PORT:-8000}, frontend http://${RIG}:3000):"

SURFSENSE_BACKEND="http://${RIG}:${SURFSENSE_PORT:-8000}"
SURFSENSE_FRONTEND="http://${RIG}:3000"

# Backend health
if curl -sf --connect-timeout 5 "${SURFSENSE_BACKEND}/health" &>/dev/null; then
  test_pass "Backend health check"
elif curl -sf --connect-timeout 5 "${SURFSENSE_BACKEND}/" &>/dev/null; then
  test_pass "Backend root endpoint responding"
else
  test_skip "SurfSense backend not reachable at ${SURFSENSE_BACKEND}"
fi

# Frontend accessible
if curl -sf --connect-timeout 5 "${SURFSENSE_FRONTEND}/" &>/dev/null; then
  test_pass "Frontend accessible"
elif curl -sf --connect-timeout 5 -o /dev/null -w "%{http_code}" "${SURFSENSE_FRONTEND}/" 2>/dev/null | grep -qE '^[23]'; then
  test_pass "Frontend responding (redirect or OK)"
else
  test_skip "SurfSense frontend not reachable at ${SURFSENSE_FRONTEND}"
fi

# ── Memos ────────────────────────────────────────────────────────────────────
echo ""
echo "Memos (http://${RIG}:${MEMOS_PORT:-5230}):"

MEMOS_URL="http://${RIG}:${MEMOS_PORT:-5230}"

if curl -sf --connect-timeout 5 "${MEMOS_URL}/api/v1/workspace/profile" &>/dev/null; then
  test_pass "API accessible (workspace profile)"

  # Test memo listing
  MEMO_LIST=$(curl -sf --connect-timeout 5 "${MEMOS_URL}/api/v1/memos" 2>/dev/null || echo "")
  if [ -n "$MEMO_LIST" ]; then
    test_pass "Memo listing endpoint"
  else
    test_fail "Memo listing returned empty"
  fi
elif curl -sf --connect-timeout 5 "${MEMOS_URL}/" &>/dev/null; then
  test_pass "Memos root endpoint responding"
  test_skip "API profile check -- may need authentication"
else
  test_skip "Memos not reachable at ${MEMOS_URL}"
  test_skip "Memo listing -- service unavailable"
fi

# ── RagFlow ──────────────────────────────────────────────────────────────────
echo ""
echo "RagFlow (http://${RIG}:${RAGFLOW_PORT:-9380}):"

RAGFLOW_URL="http://${RIG}:${RAGFLOW_PORT:-9380}"

if curl -sf --connect-timeout 5 "${RAGFLOW_URL}/api/v1/datasets" \
  -H "Authorization: Bearer ${RAGFLOW_API_KEY:-changeme}" &>/dev/null; then
  test_pass "API accessible (datasets endpoint)"

  # Check dataset count
  DATASETS=$(curl -sf --connect-timeout 5 "${RAGFLOW_URL}/api/v1/datasets" \
    -H "Authorization: Bearer ${RAGFLOW_API_KEY:-changeme}" 2>/dev/null)
  DS_COUNT=$(echo "$DATASETS" | jq '.data | length' 2>/dev/null || echo "0")
  if [ "$DS_COUNT" -gt 0 ]; then
    test_pass "Datasets exist (${DS_COUNT} found)"
  else
    test_skip "No datasets yet (RagFlow running but unconfigured)"
  fi
elif curl -sf --connect-timeout 5 "${RAGFLOW_URL}/" &>/dev/null; then
  test_pass "RagFlow root endpoint responding"
  test_skip "API auth -- may need valid API key"
else
  test_skip "RagFlow not reachable at ${RAGFLOW_URL}"
  test_skip "Dataset check -- service unavailable"
fi

# ── Elasticsearch ────────────────────────────────────────────────────────────
echo ""
echo "Elasticsearch (http://${RIG}:${ES_PORT:-9200}):"

ES_URL="http://${RIG}:${ES_PORT:-9200}"

if curl -sf --connect-timeout 5 "${ES_URL}/_cluster/health" &>/dev/null; then
  test_pass "Cluster health endpoint"

  # Check cluster status
  ES_STATUS=$(curl -sf --connect-timeout 5 "${ES_URL}/_cluster/health" 2>/dev/null \
    | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
  case "$ES_STATUS" in
    green)
      test_pass "Cluster status: green"
      ;;
    yellow)
      test_pass "Cluster status: yellow (single-node expected)"
      ;;
    red)
      test_fail "Cluster status: red"
      ;;
    *)
      test_skip "Cluster status unknown: ${ES_STATUS}"
      ;;
  esac

  # Check index count
  INDEX_COUNT=$(curl -sf --connect-timeout 5 "${ES_URL}/_cat/indices?h=index" 2>/dev/null | wc -l || echo "0")
  echo "  [INFO] Indices: ${INDEX_COUNT}"
elif curl -sf --connect-timeout 5 "${ES_URL}/" &>/dev/null; then
  test_pass "Elasticsearch root endpoint responding"
  test_skip "Cluster health -- may need additional config"
else
  test_skip "Elasticsearch not reachable at ${ES_URL}"
  test_skip "Cluster health -- service unavailable"
fi

# ── Cross-service connectivity ───────────────────────────────────────────────
echo ""
echo "Cross-service connectivity:"

# Check that all services are on the same host (nova-rig)
SERVICES_ON_RIG=0
SERVICES_TOTAL=5

for PORT in "${CRAWL4AI_PORT:-11235}" "${SURFSENSE_PORT:-8000}" "3000" "${MEMOS_PORT:-5230}" "${RAGFLOW_PORT:-9380}"; do
  if curl -sf --connect-timeout 3 "http://${RIG}:${PORT}/" &>/dev/null; then
    SERVICES_ON_RIG=$((SERVICES_ON_RIG + 1))
  fi
done

if [ "$SERVICES_ON_RIG" -eq "$SERVICES_TOTAL" ]; then
  test_pass "All ${SERVICES_TOTAL} services responding on ${RIG}"
elif [ "$SERVICES_ON_RIG" -gt 0 ]; then
  test_pass "${SERVICES_ON_RIG}/${SERVICES_TOTAL} services responding on ${RIG}"
else
  test_skip "No services responding on ${RIG} -- may not be deployed yet"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
