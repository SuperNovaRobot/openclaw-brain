#!/bin/bash
# sync-to-ragflow.sh — Batch sync LCM DAG summaries to RagFlow
# Reads summaries from Lossless Claw's SQLite database and uploads them
# as documents to the RagFlow lcm-summaries dataset for semantic search.
#
# Usage: bash sync-to-ragflow.sh [--force]
#   --force  Re-sync all summaries, ignoring previous sync state
#
# Designed to run via cron (daily-consolidate) or manually.
set -euo pipefail

###############################################################################
# Configuration
###############################################################################
LCM_DB="${LCM_DB:-$HOME/.openclaw/lcm.db}"
RAGFLOW_API="${RAGFLOW_API:-http://100.76.233.80:9380/api/v1}"
RAGFLOW_KEY="${RAGFLOW_KEY:-ragflow-c5062fdd133375fcef53c7b91eca624c}"
DATASET_ID="${RAGFLOW_DATASET_ID:-4a543fc0263e11f1b983a57a35761573}"
SYNC_STATE_DIR="$HOME/.openclaw/lcm-ragflow-sync"
SYNC_STATE_FILE="$SYNC_STATE_DIR/synced-ids.txt"
STAGING_DIR="$(mktemp -d /tmp/lcm-ragflow-sync.XXXXXX)"
FORCE=0

if [[ "${1:-}" == "--force" ]]; then
    FORCE=1
fi

mkdir -p "$SYNC_STATE_DIR"
touch "$SYNC_STATE_FILE"

cleanup() { rm -rf "$STAGING_DIR"; }
trap cleanup EXIT

###############################################################################
# Preflight
###############################################################################
if [ ! -f "$LCM_DB" ]; then
    echo "[lcm-bridge] ERROR: LCM database not found at $LCM_DB"
    exit 1
fi

echo "[lcm-bridge] Starting batch sync — $(date -Iseconds)"
echo "[lcm-bridge] LCM database: $LCM_DB"

###############################################################################
# Extract and sync summaries from LCM via Python
###############################################################################
python3 - "$LCM_DB" "$SYNC_STATE_FILE" "$STAGING_DIR" "$FORCE" \
         "$RAGFLOW_API" "$RAGFLOW_KEY" "$DATASET_ID" << 'PYEOF'
import sqlite3
import json
import subprocess
import os
import sys

db_path = sys.argv[1]
sync_file = sys.argv[2]
staging_dir = sys.argv[3]
force = sys.argv[4] == "1"
ragflow_api = sys.argv[5]
ragflow_key = sys.argv[6]
dataset_id = sys.argv[7]

# Connect to LCM database
conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row
c = conn.cursor()

# Get all summaries with conversation context
c.execute("""
    SELECT
        s.summary_id,
        s.conversation_id,
        s.kind,
        s.depth,
        s.content,
        s.token_count,
        s.earliest_at,
        s.latest_at,
        s.descendant_count,
        s.descendant_token_count,
        s.source_message_token_count,
        s.model,
        s.created_at,
        c.session_id,
        c.title AS conversation_title
    FROM summaries s
    JOIN conversations c ON s.conversation_id = c.conversation_id
    ORDER BY s.created_at ASC
""")

summaries = []
for row in c.fetchall():
    c2 = conn.cursor()
    c2.execute(
        "SELECT COUNT(*) FROM summary_messages WHERE summary_id = ?",
        (row["summary_id"],),
    )
    msg_count = c2.fetchone()[0]

    summaries.append({
        "summary_id": row["summary_id"],
        "conversation_id": row["conversation_id"],
        "session_id": row["session_id"],
        "conversation_title": row["conversation_title"] or "untitled",
        "kind": row["kind"],
        "depth": row["depth"],
        "content": row["content"],
        "token_count": row["token_count"],
        "earliest_at": row["earliest_at"] or "",
        "latest_at": row["latest_at"] or "",
        "descendant_count": row["descendant_count"],
        "descendant_token_count": row["descendant_token_count"],
        "source_message_token_count": row["source_message_token_count"],
        "model": row["model"],
        "created_at": row["created_at"],
        "message_count": msg_count,
    })

conn.close()

total = len(summaries)
print(f"[lcm-bridge] Found {total} summaries in LCM database")

if total == 0:
    print("[lcm-bridge] Nothing to sync")
    sys.exit(0)

# Load already-synced IDs
synced_ids = set()
if not force and os.path.exists(sync_file):
    with open(sync_file) as f:
        synced_ids = set(line.strip() for line in f if line.strip())

synced = 0
skipped = 0
failed = 0

for s in summaries:
    sid = s["summary_id"]

    if sid in synced_ids:
        skipped += 1
        continue

    # Build markdown document for RagFlow
    title = s["conversation_title"]
    kind_label = "Leaf Summary" if s["kind"] == "leaf" else "Condensed Summary"
    time_range = ""
    if s["earliest_at"] and s["latest_at"]:
        time_range = f"{s['earliest_at']} to {s['latest_at']}"
    elif s["earliest_at"]:
        time_range = f"from {s['earliest_at']}"

    doc_content = f"""# {kind_label}: {title}

## Metadata
- **Summary ID:** {sid}
- **Conversation:** {title} (ID: {s['conversation_id']}, Session: {s['session_id']})
- **Type:** {s['kind']} (depth {s['depth']})
- **Time Range:** {time_range or 'unknown'}
- **Messages Covered:** {s['message_count']}
- **Tokens:** {s['token_count']} (source messages: {s['source_message_token_count']})
- **Descendants:** {s['descendant_count']} ({s['descendant_token_count']} tokens)
- **Model:** {s['model']}
- **Created:** {s['created_at']}

## Content

{s['content']}

---
*Synced from Lossless Claw (LCM) — use lcm:recall with summary_id {sid} to drill into full conversation*
"""

    # Write to temp file
    safe_name = f"lcm-{sid[:16]}.md"
    doc_path = os.path.join(staging_dir, safe_name)
    with open(doc_path, "w") as f:
        f.write(doc_content)

    # Upload to RagFlow
    try:
        result = subprocess.run(
            [
                "curl", "-sf", "--max-time", "15",
                "-X", "POST",
                "-H", f"Authorization: Bearer {ragflow_key}",
                "-F", f"file=@{doc_path}",
                f"{ragflow_api}/datasets/{dataset_id}/documents",
            ],
            capture_output=True, text=True, timeout=20,
        )
        resp = json.loads(result.stdout)
        if resp.get("code") == 0:
            doc_id = resp["data"][0]["id"]
            # Trigger parsing
            subprocess.run(
                [
                    "curl", "-sf", "--max-time", "10",
                    "-X", "POST",
                    "-H", f"Authorization: Bearer {ragflow_key}",
                    "-H", "Content-Type: application/json",
                    f"{ragflow_api}/datasets/{dataset_id}/chunks",
                    "-d", json.dumps({"document_ids": [doc_id]}),
                ],
                capture_output=True, text=True, timeout=15,
            )
            # Record as synced
            with open(sync_file, "a") as f:
                f.write(sid + "\n")
            synced += 1
            print(
                f"  [OK] {sid[:16]}... "
                f"({kind_label}, depth {s['depth']}, {s['message_count']} msgs)"
            )
        else:
            failed += 1
            msg = resp.get("message", "unknown error")
            print(f"  [FAIL] {sid[:16]}... — {msg}", file=sys.stderr)
    except Exception as e:
        failed += 1
        print(f"  [FAIL] {sid[:16]}... — {e}", file=sys.stderr)

print(
    f"\n[lcm-bridge] Sync complete: "
    f"{synced} synced, {skipped} skipped (already synced), {failed} failed"
)
PYEOF

echo "[lcm-bridge] Finished — $(date -Iseconds)"
