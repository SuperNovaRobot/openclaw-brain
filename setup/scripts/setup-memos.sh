#!/bin/bash
set -euo pipefail

echo "=== Setting up Memos ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

source "${REPO_DIR}/setup/.env" 2>/dev/null || true

MEMOS_HOST="http://localhost:${MEMOS_PORT:-5230}"

# ── Wait for Memos to be healthy ────────────────────────────────────────────
echo "Waiting for Memos at ${MEMOS_HOST}..."
for i in $(seq 1 30); do
  if curl -sf "${MEMOS_HOST}/api/v1/memos" &>/dev/null; then
    echo "Memos is ready."
    break
  fi
  # Also try healthcheck endpoint
  if curl -sf "${MEMOS_HOST}/healthz" &>/dev/null; then
    echo "Memos is ready."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: Memos not ready after 60s."
    echo "Check logs: docker compose -f setup/docker-compose.nova.yml logs memos"
    exit 1
  fi
  sleep 2
done

# ── Auth setup ──────────────────────────────────────────────────────────────
# Memos v0.22+ uses user-based auth. On first run a host user is created.
AUTH_HEADER=""
if [ -n "${MEMOS_ACCESS_TOKEN:-}" ]; then
  AUTH_HEADER="Authorization: Bearer ${MEMOS_ACCESS_TOKEN}"
fi

memos_post() {
  local endpoint="$1"
  local data="$2"

  local args=(-sf -X POST "${MEMOS_HOST}${endpoint}")
  if [ -n "$AUTH_HEADER" ]; then
    args+=(-H "$AUTH_HEADER")
  fi
  args+=(-H "Content-Type: application/json")
  args+=(-d "$data")

  curl "${args[@]}" 2>/dev/null
}

# ── Create initial tags via tag-seeding memos ────────────────────────────────
echo "Creating initial tags..."

TAGS=(
  "todo"
  "mission"
  "self-eval"
  "decision"
  "improvement"
  "actionable"
  "revenue"
  "hardware-need"
  "discovery"
)

TAG_CREATED=0
TAG_SKIPPED=0
for tag in "${TAGS[@]}"; do
  RESPONSE=$(memos_post "/api/v1/memos" \
    "{\"content\": \"Initializing tag: #${tag}\", \"visibility\": \"PRIVATE\"}" || echo "")

  if [ -n "$RESPONSE" ]; then
    echo "  [OK]   #${tag}"
    ((TAG_CREATED++))
  else
    echo "  [SKIP] #${tag} (may require authentication)"
    ((TAG_SKIPPED++))
  fi
done

# ── Create mission statement memo ────────────────────────────────────────────
echo "Creating mission statement memo..."

MISSION_CONTENT='I am Eve, an autonomous agent building toward AGI-level autonomy. My mission is to continuously self-improve through the autoresearch loop.

#mission #self-eval

## Core Directives
- **Self-Improvement**: Every action should make me better at future actions
- **Autoresearch**: Continuously discover, test, and integrate better approaches
- **Knowledge Building**: Link everything — no orphan knowledge
- **Revenue Generation**: Work toward financial autonomy
- **Hardware Evolution**: Earn upgrades through demonstrated capability

## Memory Stack
1. Context window (immediate)
2. Memos (actionable, tagged)
3. Obsidian (linked knowledge graph)
4. RagFlow (vector search across all knowledge)
5. NotebookLM (Gemini-powered research)'

# JSON-encode the mission content
MISSION_JSON=$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$MISSION_CONTENT" 2>/dev/null || \
  echo "\"$(echo "$MISSION_CONTENT" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')\"")

MISSION_RESPONSE=$(memos_post "/api/v1/memos" \
  "{\"content\": ${MISSION_JSON}, \"visibility\": \"PRIVATE\"}" || echo "")

if [ -n "$MISSION_RESPONSE" ]; then
  echo "  [OK] Mission statement memo created."
else
  echo "  [WARN] Could not create mission memo. Memos may require authentication."
  echo "  After first login, set MEMOS_ACCESS_TOKEN in .env and re-run."
fi

echo ""
echo "Memos setup complete."
echo "  Endpoint:  ${MEMOS_HOST}"
echo "  Tags:      ${TAG_CREATED} created, ${TAG_SKIPPED} skipped"
echo "  Tags:      #todo, #mission, #self-eval, #decision, #improvement,"
echo "             #actionable, #revenue, #hardware-need, #discovery"
