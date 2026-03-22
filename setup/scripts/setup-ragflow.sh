#!/bin/bash
set -euo pipefail

echo "=== Setting up RagFlow ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

source "${REPO_DIR}/setup/.env" 2>/dev/null || true

RAGFLOW_HOST="http://localhost:${RAGFLOW_PORT:-9380}"
RAGFLOW_API_KEY="${RAGFLOW_API_KEY:-changeme}"

# ── Wait for RagFlow to be healthy ──────────────────────────────────────────
echo "Waiting for RagFlow at ${RAGFLOW_HOST}..."
for i in $(seq 1 30); do
  if curl -sf "${RAGFLOW_HOST}/api/v1/datasets" \
    -H "Authorization: Bearer ${RAGFLOW_API_KEY}" &>/dev/null; then
    echo "RagFlow is ready."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: RagFlow not ready after 60s."
    echo "Check logs: docker compose -f setup/docker-compose.nova.yml logs ragflow"
    exit 1
  fi
  sleep 2
done

# ── Create initial datasets ─────────────────────────────────────────────────
echo "Creating initial datasets..."

create_dataset() {
  local name="$1"
  local description="$2"

  # Check if dataset already exists
  if echo "$EXISTING_DATASETS" | grep -q "\"name\":\"${name}\"" 2>/dev/null; then
    echo "  [SKIP] ${name} (already exists)"
    return 1
  fi

  RESPONSE=$(curl -sf -X POST "${RAGFLOW_HOST}/api/v1/datasets" \
    -H "Authorization: Bearer ${RAGFLOW_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"${name}\", \"description\": \"${description}\", \"language\": \"English\", \"embedding_model\": \"\"}" \
    2>/dev/null || echo '{"code": -1}')

  if echo "$RESPONSE" | grep -qE '"code"\s*:\s*0' 2>/dev/null; then
    echo "  [OK]   ${name}"
    return 0
  else
    echo "  [WARN] ${name} — may already exist or API error"
    return 1
  fi
}

# Get existing datasets
EXISTING_DATASETS=$(curl -sf "${RAGFLOW_HOST}/api/v1/datasets" \
  -H "Authorization: Bearer ${RAGFLOW_API_KEY}" 2>/dev/null || echo '{"data":[]}')

CREATED=0
SKIPPED=0

create_dataset "agent-memory" "Core agent memory — decisions, reflections, self-evaluations" && ((CREATED++)) || ((SKIPPED++))
create_dataset "tool-docs" "Documentation for tools, APIs, and integrations" && ((CREATED++)) || ((SKIPPED++))
create_dataset "code-knowledge" "Code snippets, patterns, and architecture knowledge" && ((CREATED++)) || ((SKIPPED++))
create_dataset "research" "Research papers, articles, and findings from autoresearch loop" && ((CREATED++)) || ((SKIPPED++))
create_dataset "robotics" "Robotics-specific knowledge — kinematics, control, perception" && ((CREATED++)) || ((SKIPPED++))
create_dataset "ops-reference" "Operational runbooks, deployment guides, troubleshooting" && ((CREATED++)) || ((SKIPPED++))

echo ""
echo "RagFlow setup complete."
echo "  Endpoint:  ${RAGFLOW_HOST}"
echo "  Created:   ${CREATED} datasets"
echo "  Skipped:   ${SKIPPED} datasets"
echo "  Datasets:  agent-memory, tool-docs, code-knowledge, research, robotics, ops-reference"
