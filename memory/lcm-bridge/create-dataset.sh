#!/bin/bash
# Creates the lcm-summaries dataset in RagFlow
# Run once during setup. Idempotent — checks if dataset exists first.
set -euo pipefail

RAGFLOW_API="http://100.76.233.80:9380/api/v1"
RAGFLOW_KEY="ragflow-c5062fdd133375fcef53c7b91eca624c"

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
    exit 0
fi

# Create dataset
RESULT=$(curl -sf -X POST \
  -H "Authorization: Bearer $RAGFLOW_KEY" \
  -H "Content-Type: application/json" \
  "$RAGFLOW_API/datasets" \
  -d '{"name": "lcm-summaries", "description": "Lossless Claw DAG summaries — lossless conversation history indexed for semantic search"}')

echo "Created dataset: $RESULT"
