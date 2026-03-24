#!/usr/bin/env bash
# save-research.sh — Atomic research saver (4 destinations, fail-safe)
# Part of OpenClaw Brain Task 10
#
# Usage:
#   save-research.sh --topic "Topic Name" --synthesis "Research text..." --links "Link1,Link2,Link3"
#
# Each destination is fail-safe: errors are logged but do not block the others.

set -u  # no -e: we handle errors per-destination

# ─── Config ──────────────────────────────────────────────────────────────────

OBSIDIAN_VAULT="/mnt/ssd/obsidian-vault"
RAGFLOW_HOST="http://100.76.233.80:9380"
RAGFLOW_TOKEN="ragflow-c5062fdd133375fcef53c7b91eca624c"
MEMOS_HOST="http://100.76.233.80:5230"
MEMOS_USER="openclaw"
MEMOS_PASS="changeme"
TODAY="$(date +%Y-%m-%d)"

TOPIC=""
SYNTHESIS=""
LINKS=""

# ─── Arg Parsing ─────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --topic)
      TOPIC="$2"; shift 2 ;;
    --synthesis)
      SYNTHESIS="$2"; shift 2 ;;
    --links)
      LINKS="$2"; shift 2 ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$TOPIC" || -z "$SYNTHESIS" || -z "$LINKS" ]]; then
  echo "ERROR: --topic, --synthesis, and --links are all required" >&2
  exit 1
fi

# ─── Helpers ─────────────────────────────────────────────────────────────────

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 -]//g' | sed 's/ \+/-/g' | sed 's/^-\+\|-\+$//g'
}

# JSON-encode a string safely (handles newlines, quotes, backslashes)
json_encode() {
  python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$1"
}

SLUG="$(slugify "$TOPIC")"

SUCCESSES=0
FAILURES=0

# ─── Build Obsidian note content (reused by destinations 1, 2) ──────────────

WIKI_LINKS=""
IFS=',' read -ra LINK_ARRAY <<< "$LINKS"
for link in "${LINK_ARRAY[@]}"; do
  link="$(echo "$link" | sed 's/^ *//;s/ *$//')"
  WIKI_LINKS="${WIKI_LINKS}- [[${link}]]
"
done

OBSIDIAN_NOTE="---
title: \"Research — ${TOPIC}\"
date: ${TODAY}
tags: [research, ${SLUG}]
---

# Research — ${TOPIC}

${SYNTHESIS}

## Related
${WIKI_LINKS}"

# ─── Destination 1: Obsidian Note ────────────────────────────────────────────

echo ">>> [1/4] Obsidian research note..."

if mkdir -p "${OBSIDIAN_VAULT}/research" && \
   printf '%s\n' "$OBSIDIAN_NOTE" > "${OBSIDIAN_VAULT}/research/${SLUG}.md"; then
  echo "    OK: ${OBSIDIAN_VAULT}/research/${SLUG}.md"
  SUCCESSES=$((SUCCESSES + 1))
else
  echo "WARN: Obsidian note failed" >&2
  FAILURES=$((FAILURES + 1))
fi

# ─── Destination 2: RagFlow ──────────────────────────────────────────────────

echo ">>> [2/4] RagFlow document upload..."

ragflow_upload() {
  # List datasets to find the right ID
  local datasets_resp
  datasets_resp="$(curl -sf --max-time 10 \
    -H "Authorization: Bearer ${RAGFLOW_TOKEN}" \
    "${RAGFLOW_HOST}/api/v1/datasets" 2>&1)" || {
    echo "WARN: RagFlow dataset list request failed" >&2
    return 1
  }

  # Find agent-memory dataset ID (or fall back to first dataset)
  local dataset_id
  dataset_id="$(echo "$datasets_resp" | python3 -c "
import sys, json
data = json.load(sys.stdin)
datasets = data.get('data', [])
for ds in datasets:
    name = ds.get('name','').lower()
    if 'agent' in name or 'memory' in name:
        print(ds['id']); sys.exit(0)
if datasets:
    print(datasets[0]['id']); sys.exit(0)
sys.exit(1)
" 2>/dev/null)" || {
    echo "WARN: RagFlow no suitable dataset found — response: ${datasets_resp}" >&2
    return 1
  }

  echo "    Using dataset ID: ${dataset_id}"

  # Write content to a temp file and upload via multipart form
  local tmpfile="/tmp/ragflow-research-${SLUG}.md"
  printf '%s\n' "$OBSIDIAN_NOTE" > "$tmpfile"

  local upload_resp
  upload_resp="$(curl -sf --max-time 15 \
    -X POST \
    -H "Authorization: Bearer ${RAGFLOW_TOKEN}" \
    -F "file=@${tmpfile}" \
    "${RAGFLOW_HOST}/api/v1/datasets/${dataset_id}/documents" 2>&1)" || {
    rm -f "$tmpfile"
    echo "WARN: RagFlow upload request failed" >&2
    return 1
  }
  rm -f "$tmpfile"

  # Check response code
  local code
  code="$(echo "$upload_resp" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code',999))" 2>/dev/null)" || code="999"

  if [[ "$code" == "0" ]]; then
    echo "    OK: RagFlow document uploaded to dataset ${dataset_id}"
    return 0
  else
    echo "WARN: RagFlow upload returned code ${code} — ${upload_resp}" >&2
    return 1
  fi
}

if ragflow_upload; then
  SUCCESSES=$((SUCCESSES + 1))
else
  FAILURES=$((FAILURES + 1))
fi

# ─── Destination 3: Memos ────────────────────────────────────────────────────

echo ">>> [3/4] Memos..."

memos_post() {
  # Authenticate
  local auth_payload
  auth_payload="{\"passwordCredentials\":{\"username\":\"${MEMOS_USER}\",\"password\":\"${MEMOS_PASS}\"}}"

  local auth_resp
  auth_resp="$(curl -sf --max-time 10 \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$auth_payload" \
    "${MEMOS_HOST}/memos.api.v1.AuthService/SignIn" 2>&1)" || {
    echo "WARN: Memos auth request failed" >&2
    return 1
  }

  local token
  token="$(echo "$auth_resp" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for key in ('accessToken', 'token', 'access_token'):
    if key in data:
        print(data[key]); sys.exit(0)
sys.exit(1)
" 2>/dev/null)" || {
    echo "WARN: Memos token extraction failed — response: ${auth_resp}" >&2
    return 1
  }

  # Build memo content (first 500 chars of synthesis)
  local short_synthesis
  short_synthesis="$(printf '%s' "$SYNTHESIS" | head -c 500)"

  local memo_content
  memo_content="$(printf '## Research: %s\n\n%s\n\n#research #%s #autoresearch' "$TOPIC" "$short_synthesis" "$SLUG")"

  # Build JSON payload safely using python3
  local json_payload
  json_payload="$(python3 -c "
import json, sys
content = sys.stdin.read()
print(json.dumps({'content': content}))
" <<< "$memo_content")" || {
    echo "WARN: Memos JSON encoding failed" >&2
    return 1
  }

  local memo_resp
  memo_resp="$(curl -sf --max-time 10 \
    -X POST \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "$json_payload" \
    "${MEMOS_HOST}/api/v1/memos" 2>&1)" || {
    echo "WARN: Memos post request failed" >&2
    return 1
  }

  echo "    OK: Memo created"
  return 0
}

if memos_post; then
  SUCCESSES=$((SUCCESSES + 1))
else
  FAILURES=$((FAILURES + 1))
fi

# ─── Destination 4: Daily Note ───────────────────────────────────────────────

echo ">>> [4/4] Obsidian daily note..."

daily_note_append() {
  local daily_dir="${OBSIDIAN_VAULT}/daily"
  local daily_file="${daily_dir}/${TODAY}.md"

  mkdir -p "$daily_dir" || return 1

  # Create daily note with header if it doesn't exist
  if [[ ! -f "$daily_file" ]]; then
    printf '# %s\n' "$TODAY" > "$daily_file"
  fi

  # Truncate synthesis to 200 chars
  local short_synthesis
  short_synthesis="$(printf '%s' "$SYNTHESIS" | head -c 200)"

  # Append research entry
  printf '\n## Research: %s\n\n%s...\n\n→ [[Research — %s]]\n' \
    "$TOPIC" "$short_synthesis" "$TOPIC" >> "$daily_file"

  return 0
}

if daily_note_append; then
  echo "    OK: ${OBSIDIAN_VAULT}/daily/${TODAY}.md"
  SUCCESSES=$((SUCCESSES + 1))
else
  echo "WARN: Daily note failed" >&2
  FAILURES=$((FAILURES + 1))
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "=== save-research complete: ${SUCCESSES}/4 succeeded, ${FAILURES}/4 failed ==="
echo "    Topic: ${TOPIC}"
echo "    Slug:  ${SLUG}"

if [[ "$FAILURES" -gt 0 ]]; then
  exit 1
fi
exit 0
