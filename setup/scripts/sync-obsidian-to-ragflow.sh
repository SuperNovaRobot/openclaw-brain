#!/bin/bash
set -euo pipefail

# Syncs all modified Obsidian notes to RagFlow
# Run this daily via HEARTBEAT cron

source "$(dirname "$0")/../../setup/.env" 2>/dev/null || true

VAULT_PATH="${OBSIDIAN_VAULT_PATH:-/mnt/ssd/obsidian-vault}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAST_SYNC_FILE="/tmp/ragflow-last-sync"

# Find files modified since last sync
if [ -f "$LAST_SYNC_FILE" ]; then
  MODIFIED=$(find "$VAULT_PATH" -name "*.md" -newer "$LAST_SYNC_FILE" \
    -not -path "*/.obsidian/*" -not -path "*/.git/*" -not -name "_index.md" -not -name ".git-sync.sh" 2>/dev/null || true)
else
  # First run — sync everything
  MODIFIED=$(find "$VAULT_PATH" -name "*.md" \
    -not -path "*/.obsidian/*" -not -path "*/.git/*" -not -name "_index.md" -not -name ".git-sync.sh" 2>/dev/null || true)
fi

if [ -z "$MODIFIED" ]; then
  echo "No modified notes to sync."
  touch "$LAST_SYNC_FILE"
  exit 0
fi

COUNT=$(echo "$MODIFIED" | grep -c "." 2>/dev/null || echo "0")
echo "=== Syncing $COUNT modified notes to RagFlow ==="

echo "$MODIFIED" | while read -r filepath; do
  [ -z "$filepath" ] && continue

  # Determine dataset based on directory
  RELPATH="${filepath#$VAULT_PATH/}"
  DIR=$(dirname "$RELPATH")

  case "$DIR" in
    tools*) DATASET="tool-docs" ;;
    research*) DATASET="research" ;;
    robots*) DATASET="robotics" ;;
    improvements*) DATASET="agent-memory" ;;
    daily*) DATASET="agent-memory" ;;
    projects*) DATASET="code-knowledge" ;;
    *) DATASET="agent-memory" ;;
  esac

  echo "  $RELPATH → $DATASET"
  "$SCRIPT_DIR/ingest-to-ragflow.sh" "$DATASET" "$filepath" 2>/dev/null || echo "    (skipped — RagFlow may not be running)"
done

# Update last sync timestamp
touch "$LAST_SYNC_FILE"
echo "Sync complete."
