#!/bin/bash
# Creates the lcm-summaries dataset in RagFlow
# Run once during setup. Idempotent — checks if dataset exists first.
set -euo pipefail

RAGFLOW_API="${RAGFLOW_API:-http://100.76.233.80:9380/api/v1}"
RAGFLOW_KEY="${RAGFLOW_KEY:-ragflow-c5062fdd133375fcef53c7b91eca624c}"
EMBEDDING_MODEL="${RAGFLOW_EMBEDDING_MODEL:-nomic-embed-text@Ollama}"

# Check if dataset already exists
EXISTING=$(curl -sf -H "Authorization: Bearer $RAGFLOW_KEY" "$RAGFLOW_API/datasets" | python3 -c "
import sys, json
datasets = json.load(sys.stdin).get('data', [])
for d in datasets:
    if d.get('name') == 'lcm-summaries':
        print(d['id'])
        break
" 2>/dev/null || true)

if [ -n "$EXISTING" ]; then
    echo "Dataset lcm-summaries already exists: $EXISTING"

    # Ensure embedding model is set
    curl -sf -X PUT \
      -H "Authorization: Bearer $RAGFLOW_KEY" \
      -H "Content-Type: application/json" \
      "$RAGFLOW_API/datasets/$EXISTING" \
      -d "{\"embedding_model\": \"$EMBEDDING_MODEL\"}" > /dev/null 2>&1

    echo "Embedding model set to: $EMBEDDING_MODEL"
    exit 0
fi

# Create dataset with embedding model
RESULT=$(curl -sf -X POST \
  -H "Authorization: Bearer $RAGFLOW_KEY" \
  -H "Content-Type: application/json" \
  "$RAGFLOW_API/datasets" \
  -d "{\"name\": \"lcm-summaries\", \"description\": \"Lossless Claw DAG summaries — lossless conversation history indexed for semantic search. Synced from LCM via afterTurn hook and daily cron.\", \"embedding_model\": \"$EMBEDDING_MODEL\"}")

echo "Created dataset: $RESULT"
