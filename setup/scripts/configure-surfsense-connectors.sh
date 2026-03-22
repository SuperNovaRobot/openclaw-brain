#!/bin/bash
# Configure SurfSense connectors for OpenClaw Brain
# SurfSense runs on nova-rig — connectors link it to Obsidian, Memos, and GitHub

echo "=== SurfSense Connector Configuration ==="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

source "${REPO_DIR}/setup/.env" 2>/dev/null || true

SURFSENSE_HOST="${SURFSENSE_HOST:-nova-rig}"
SURFSENSE_PORT="${SURFSENSE_PORT:-8000}"
SURFSENSE_BACKEND="http://${SURFSENSE_HOST}:${SURFSENSE_PORT}"
SURFSENSE_FRONTEND="http://${SURFSENSE_HOST}:3000"

# ── Wait for SurfSense backend ──────────────────────────────────────────────
echo "Waiting for SurfSense backend at ${SURFSENSE_BACKEND}..."
READY=0
for i in $(seq 1 30); do
  if curl -sf "${SURFSENSE_BACKEND}/health" &>/dev/null; then
    echo "SurfSense backend is ready."
    READY=1
    break
  fi
  if curl -sf "${SURFSENSE_BACKEND}/" &>/dev/null; then
    echo "SurfSense backend is ready (root endpoint responding)."
    READY=1
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "WARNING: SurfSense backend not ready after 60s."
    echo "  Check logs on nova-rig: docker compose logs surfsense-backend"
    echo "  Continuing with connector instructions anyway..."
  fi
  sleep 2
done

# ── Test reachability of connector targets ───────────────────────────────────
echo ""
echo "Testing connector target reachability..."
echo ""

# Obsidian vault (local to nova — cross-machine consideration)
OBSIDIAN_VAULT="${OBSIDIAN_VAULT_PATH:-/mnt/ssd/obsidian-vault}"
echo "1. Obsidian Vault:"
if [ -d "$OBSIDIAN_VAULT" ]; then
  NOTE_COUNT=$(find "$OBSIDIAN_VAULT" -name "*.md" -not -path "*/.git/*" -not -path "*/.obsidian/*" 2>/dev/null | wc -l)
  echo "   [OK]   Local vault exists at ${OBSIDIAN_VAULT} (${NOTE_COUNT} notes)"
  echo "   [NOTE] Vault is on nova, SurfSense is on nova-rig."
  echo "          Options for cross-machine access:"
  echo "          a) NFS mount: export /mnt/ssd/obsidian-vault from nova, mount on nova-rig"
  echo "          b) API sync: use obsidian-git to push to remote, SurfSense pulls from git"
  echo "          c) crawl4ai: crawl local markdown files via http file server on nova"
else
  echo "   [SKIP] Vault not found at ${OBSIDIAN_VAULT}"
fi

echo ""
echo "2. Memos:"
MEMOS_EXTERNAL="http://${SURFSENSE_HOST}:${MEMOS_PORT:-5230}"
if curl -sf "${MEMOS_EXTERNAL}/api/v1/workspace/profile" &>/dev/null; then
  echo "   [OK]   Memos reachable at ${MEMOS_EXTERNAL}"
  echo "          Internal docker network: http://memos:5230"
elif curl -sf "http://nova-rig:5230/api/v1/workspace/profile" &>/dev/null; then
  echo "   [OK]   Memos reachable at http://nova-rig:5230"
else
  echo "   [WARN] Memos not reachable at ${MEMOS_EXTERNAL}"
  echo "          Ensure Memos container is running on nova-rig"
fi

echo ""
echo "3. GitHub:"
if [ -n "${GITHUB_TOKEN:-}" ]; then
  GH_USER=$(curl -sf -H "Authorization: token ${GITHUB_TOKEN}" \
    "https://api.github.com/user" 2>/dev/null | grep -o '"login":"[^"]*"' || echo "")
  if [ -n "$GH_USER" ]; then
    echo "   [OK]   GitHub token valid -- ${GH_USER}"
  else
    echo "   [WARN] GitHub token set but could not validate"
  fi
else
  echo "   [SKIP] GITHUB_TOKEN not set in .env"
  echo "          Add GITHUB_TOKEN=ghp_... to setup/.env for GitHub connector"
fi

# ── Print connector configuration instructions ──────────────────────────────
echo ""
echo "============================================================"
echo "  SurfSense Connector Configuration Instructions"
echo "============================================================"
echo ""
echo "Open the SurfSense web UI:"
echo "  ${SURFSENSE_FRONTEND}"
echo ""
echo "Navigate to Settings > Connectors and configure:"
echo ""
echo "-- 1. Obsidian Connector -----------------------------------------"
echo "  Type:   Local Files / Obsidian"
echo "  Path:   ${OBSIDIAN_VAULT}"
echo ""
echo "  IMPORTANT: SurfSense runs on nova-rig but the vault is on nova."
echo "  To make this work, choose ONE of these approaches:"
echo ""
echo "  Option A -- NFS Mount (recommended):"
echo "    On nova:     echo '/mnt/ssd/obsidian-vault nova-rig(ro,sync,no_subtree_check)' >> /etc/exports"
echo "    On nova:     exportfs -ra"
echo "    On nova-rig: mkdir -p /mnt/nova/obsidian-vault"
echo "    On nova-rig: mount nova:/mnt/ssd/obsidian-vault /mnt/nova/obsidian-vault"
echo "    Then configure SurfSense with path: /mnt/nova/obsidian-vault"
echo ""
echo "  Option B -- Git Sync:"
echo "    The vault already has obsidian-git configured."
echo "    Point SurfSense to the same git remote and let it clone/pull."
echo ""
echo "-- 2. Memos Connector --------------------------------------------"
echo "  Type:     REST API"
echo "  Endpoint: http://memos:5230  (docker internal, if same compose network)"
echo "            ${MEMOS_EXTERNAL}  (external, from host)"
echo "  Auth:     None required for local instance (or use API token if configured)"
echo "  Sync:     Every 5 minutes"
echo ""
echo "-- 3. GitHub Connector -------------------------------------------"
echo "  Type:     GitHub"
echo "  Token:    GITHUB_TOKEN from .env"
echo "  Repos:    openclaw/openclaw-brain (add more as needed)"
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo ""
  echo "  ACTION REQUIRED: Set GITHUB_TOKEN in setup/.env first"
fi
echo ""
echo "============================================================"
echo ""

# ── Summary ──────────────────────────────────────────────────────────────────
if [ "$READY" -eq 1 ]; then
  STATUS_MSG="Backend responding"
else
  STATUS_MSG="Backend not yet responding"
fi
echo "SurfSense connector configuration guide complete."
echo "  Backend:  ${SURFSENSE_BACKEND}"
echo "  Frontend: ${SURFSENSE_FRONTEND}"
echo "  Status:   ${STATUS_MSG}"
echo ""
echo "After configuring connectors, verify with:"
echo "  curl -sf ${SURFSENSE_BACKEND}/api/v1/connectors | jq ."
