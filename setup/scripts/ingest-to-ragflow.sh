#!/bin/bash
set -euo pipefail

# Usage: ./ingest-to-ragflow.sh <dataset-name> <file-path>
# Example: ./ingest-to-ragflow.sh tool-docs /tmp/autoresearch-readme.md

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <dataset-name> <file-path>"
  echo "Datasets: agent-memory, tool-docs, code-knowledge, research, robotics, ops-reference"
  exit 1
fi

DATASET="$1"
FILE_PATH="$2"

source "$(dirname "$0")/../../setup/.env" 2>/dev/null || true

RAGFLOW_URL="http://${RIG_HOST:-nova-rig}:${RAGFLOW_PORT:-9380}"
API_KEY="${RAGFLOW_API_KEY:-changeme}"

if [ ! -f "$FILE_PATH" ]; then
  echo "ERROR: File not found: $FILE_PATH"
  exit 1
fi

FILENAME=$(basename "$FILE_PATH")
echo "Ingesting '$FILENAME' into RagFlow dataset '$DATASET'..."

# Get dataset ID by name
DATASET_ID=$(curl -sf "$RAGFLOW_URL/api/v1/datasets" \
  -H "Authorization: Bearer $API_KEY" | \
  jq -r ".data[] | select(.name == \"$DATASET\") | .id // empty" 2>/dev/null || echo "")

if [ -z "$DATASET_ID" ]; then
  echo "ERROR: Dataset '$DATASET' not found. Available datasets:"
  curl -sf "$RAGFLOW_URL/api/v1/datasets" \
    -H "Authorization: Bearer $API_KEY" | jq -r '.data[].name' 2>/dev/null || echo "  (RagFlow may not be running)"
  exit 1
fi

# Upload document
RESULT=$(curl -sf -X POST "$RAGFLOW_URL/api/v1/datasets/$DATASET_ID/documents" \
  -H "Authorization: Bearer $API_KEY" \
  -F "file=@$FILE_PATH")

DOC_ID=$(echo "$RESULT" | jq -r '.data.id // .data[0].id // empty' 2>/dev/null)

if [ -n "$DOC_ID" ]; then
  echo "  Document uploaded: $DOC_ID"
  echo "  Triggering parsing..."
  curl -sf -X POST "$RAGFLOW_URL/api/v1/datasets/$DATASET_ID/chunks" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"document_ids\": [\"$DOC_ID\"]}" > /dev/null 2>&1 || true
  echo "  Parsing triggered. Document will be searchable after processing."
else
  echo "  WARNING: Upload may have failed."
  echo "$RESULT" | jq . 2>/dev/null || echo "$RESULT"
fi
