#!/bin/bash
set -euo pipefail

echo "=== Setting up vLLM Inference ==="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

source "${REPO_DIR}/setup/.env" 2>/dev/null || true

RIG_HOST="${RIG_HOST:-nova-rig}"
VLLM_MODEL="${VLLM_MODEL:-nemotron-122b-awq}"
MODEL_PATH="/mnt/ssd/models/${VLLM_MODEL}"

# ── Check model availability on nova-rig ────────────────────────────────────
echo "Checking model at ${RIG_HOST}:${MODEL_PATH}..."
if ssh "${RIG_HOST}" "test -d '${MODEL_PATH}' || test -f '${MODEL_PATH}'" 2>/dev/null; then
  echo "Model found at ${MODEL_PATH} on ${RIG_HOST}."
else
  echo ""
  echo "WARNING: Model not found at ${MODEL_PATH} on ${RIG_HOST}."
  echo ""
  echo "To download the model, run on ${RIG_HOST}:"
  echo ""
  echo "  # Option 1: HuggingFace CLI"
  echo "  pip install huggingface-hub"
  echo "  huggingface-cli download nvidia/${VLLM_MODEL} --local-dir ${MODEL_PATH}"
  echo ""
  echo "  # Option 2: Git LFS"
  echo "  git lfs install"
  echo "  git clone https://huggingface.co/nvidia/${VLLM_MODEL} ${MODEL_PATH}"
  echo ""
  echo "Models are too large to auto-download. Please download manually and re-run."
  exit 1
fi

# ── Start vLLM container on nova-rig ────────────────────────────────────────
echo "Starting vLLM container via docker compose..."
cd "$REPO_DIR"
docker compose --env-file "${REPO_DIR}/setup/.env" -f "${REPO_DIR}/setup/docker-compose.rig.yml" up -d

# ── Wait for vLLM health endpoint ───────────────────────────────────────────
echo "Waiting for vLLM at http://${RIG_HOST}:8080/health..."
for i in $(seq 1 60); do
  if curl -sf "http://${RIG_HOST}:8080/health" &>/dev/null; then
    echo "vLLM is ready."
    break
  fi
  if [ "$i" -eq 60 ]; then
    echo "ERROR: vLLM not ready after 120s."
    echo "Check logs: docker compose -f setup/docker-compose.rig.yml logs vllm"
    exit 1
  fi
  sleep 2
done

# ── Verify model is serving ─────────────────────────────────────────────────
echo "Verifying model endpoint..."
MODELS_RESPONSE=$(curl -sf "http://${RIG_HOST}:8080/v1/models" \
  -H "Authorization: Bearer ${INFERENCE_API_KEY:-changeme}" 2>/dev/null || echo "")

if [ -n "$MODELS_RESPONSE" ]; then
  echo "Models endpoint responding."
  echo "$MODELS_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$MODELS_RESPONSE"
else
  echo "WARNING: Models endpoint not responding yet. vLLM may still be loading the model."
  echo "This is normal for large models — check logs: docker compose -f setup/docker-compose.rig.yml logs -f vllm"
fi

echo ""
echo "vLLM setup complete."
echo "  Endpoint:  http://${RIG_HOST}:8080"
echo "  Model:     ${VLLM_MODEL}"
echo "  Health:    http://${RIG_HOST}:8080/health"
echo "  Models:    http://${RIG_HOST}:8080/v1/models"
