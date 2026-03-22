#!/bin/bash
set -euo pipefail

echo "=== Setting up SurfSense ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

source "${REPO_DIR}/setup/.env" 2>/dev/null || true

SURFSENSE_HOST="http://localhost:${SURFSENSE_PORT:-8000}"
OBSIDIAN_VAULT="${OBSIDIAN_VAULT_PATH:-/mnt/ssd/obsidian-vault}"

# ── Wait for SurfSense to be healthy ────────────────────────────────────────
echo "Waiting for SurfSense at ${SURFSENSE_HOST}..."
for i in $(seq 1 30); do
  if curl -sf "${SURFSENSE_HOST}/health" &>/dev/null; then
    echo "SurfSense is ready."
    break
  fi
  # Try root endpoint as fallback health check
  if curl -sf "${SURFSENSE_HOST}/" &>/dev/null; then
    echo "SurfSense is ready (root endpoint responding)."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: SurfSense not ready after 60s."
    echo "Check logs: docker compose -f setup/docker-compose.nova.yml logs surfsense"
    exit 1
  fi
  sleep 2
done

# ── Configure connectors ────────────────────────────────────────────────────
echo "Configuring SurfSense connectors..."

# Obsidian vault connector
if [ -d "$OBSIDIAN_VAULT" ]; then
  echo "  Configuring Obsidian vault connector..."
  OBSIDIAN_RESPONSE=$(curl -sf -X POST "${SURFSENSE_HOST}/api/v1/connectors" \
    -H "Content-Type: application/json" \
    -d "{
      \"type\": \"obsidian\",
      \"name\": \"openclaw-vault\",
      \"config\": {
        \"vault_path\": \"${OBSIDIAN_VAULT}\",
        \"watch\": true,
        \"include_patterns\": [\"*.md\"],
        \"exclude_patterns\": [\".obsidian/*\", \".git/*\"]
      }
    }" 2>/dev/null || echo "")

  if [ -n "$OBSIDIAN_RESPONSE" ]; then
    echo "  [OK]   Obsidian vault connector configured"
  else
    echo "  [SKIP] Obsidian connector — API may not support this yet"
  fi
else
  echo "  [SKIP] Obsidian vault not found at ${OBSIDIAN_VAULT}"
fi

# Memos connector
MEMOS_ENDPOINT="http://localhost:${MEMOS_PORT:-5230}"
echo "  Configuring Memos connector..."
MEMOS_RESPONSE=$(curl -sf -X POST "${SURFSENSE_HOST}/api/v1/connectors" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"memos\",
    \"name\": \"openclaw-memos\",
    \"config\": {
      \"endpoint\": \"${MEMOS_ENDPOINT}\",
      \"sync_interval\": 300
    }
  }" 2>/dev/null || echo "")

if [ -n "$MEMOS_RESPONSE" ]; then
  echo "  [OK]   Memos connector configured"
else
  echo "  [SKIP] Memos connector — API may not support this yet"
fi

# GitHub connector (if token available)
if [ -n "${GITHUB_TOKEN:-}" ]; then
  echo "  Configuring GitHub connector..."
  GITHUB_RESPONSE=$(curl -sf -X POST "${SURFSENSE_HOST}/api/v1/connectors" \
    -H "Content-Type: application/json" \
    -d "{
      \"type\": \"github\",
      \"name\": \"openclaw-github\",
      \"config\": {
        \"token\": \"${GITHUB_TOKEN}\",
        \"repos\": [\"openclaw/openclaw-brain\"]
      }
    }" 2>/dev/null || echo "")

  if [ -n "$GITHUB_RESPONSE" ]; then
    echo "  [OK]   GitHub connector configured"
  else
    echo "  [SKIP] GitHub connector — API may not support this yet"
  fi
else
  echo "  [SKIP] GitHub connector — no GITHUB_TOKEN set"
fi

echo ""
echo "SurfSense setup complete."
echo "  Endpoint:    ${SURFSENSE_HOST}"
echo "  Connectors:  Configured (Obsidian, Memos, GitHub if available)"
echo "  Note:        SurfSense is the self-hosted fallback for NotebookLM."
echo "               Research findings flow into RagFlow and Obsidian."
