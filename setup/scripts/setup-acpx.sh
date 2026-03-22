#!/bin/bash
# setup-acpx.sh — Install and configure acpx for OpenClaw Brain
# Handles npm install (with github fallback), config deployment,
# session persistence, and CLI availability checks.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
CONFIG_SRC="${REPO_DIR}/setup/configs/acpx-config.json"
CONFIG_DEST="${HOME}/.config/acpx/config.json"
SESSION_DIR="/mnt/ssd/openclaw-brain/.acpx-sessions"
LOG_DIR="/mnt/ssd/logs"

STATUS_NODE="SKIP"
STATUS_ACPX="SKIP"
STATUS_CONFIG="SKIP"
STATUS_SESSIONS="SKIP"
STATUS_LOGS="SKIP"
STATUS_CLAUDE="SKIP"
STATUS_CODEX="SKIP"

echo "============================================"
echo "  acpx Setup for OpenClaw Brain"
echo "============================================"
echo ""

# ── 1. Check Node.js 18+ ────────────────────────────────────────────────────
echo "--- Checking Node.js ---"
if command -v node &>/dev/null; then
  NODE_VERSION=$(node --version 2>/dev/null | sed s/^v//)
  NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
  if [ "$NODE_MAJOR" -ge 18 ] 2>/dev/null; then
    echo "  [OK] Node.js v${NODE_VERSION} (>= 18)"
    STATUS_NODE="OK"
  else
    echo "  [FAIL] Node.js v${NODE_VERSION} is below 18. Please upgrade."
    STATUS_NODE="FAIL"
  fi
else
  echo "  [FAIL] Node.js not found. Install Node.js 18+ first."
  STATUS_NODE="FAIL"
fi
echo ""

# ── 2. Install acpx ─────────────────────────────────────────────────────────
echo "--- Installing acpx ---"
if command -v acpx &>/dev/null; then
  ACPX_VER=$(acpx --version 2>/dev/null || echo "unknown")
  echo "  [OK] acpx already installed: ${ACPX_VER}"
  STATUS_ACPX="OK"
else
  echo "  Attempting npm install -g acpx@latest ..."
  if npm install -g acpx@latest 2>/dev/null; then
    ACPX_VER=$(acpx --version 2>/dev/null || echo "installed")
    echo "  [OK] acpx installed via npm: ${ACPX_VER}"
    STATUS_ACPX="OK"
  else
    echo "  npm install failed (acpx may not be on npm yet — it is alpha)."
    echo "  Attempting clone from github.com/anthropics/acpx ..."
    CLONE_DIR="/mnt/ssd/openclaw-brain/vendor/acpx"
    if [ -d "$CLONE_DIR" ]; then
      echo "  [INFO] Vendor clone already exists at ${CLONE_DIR}"
      STATUS_ACPX="VENDOR"
    elif git clone https://github.com/anthropics/acpx.git "$CLONE_DIR" 2>/dev/null; then
      echo "  [OK] Cloned acpx to ${CLONE_DIR}"
      if [ -f "$CLONE_DIR/package.json" ]; then
        cd "$CLONE_DIR" && npm install 2>/dev/null && npm link 2>/dev/null
        cd "$REPO_DIR"
      fi
      STATUS_ACPX="VENDOR"
    else
      echo "  [WARN] Could not install acpx via npm or github clone."
      echo "  Config will be deployed anyway. Manual install needed later."
      echo "  Try: npm install -g acpx@latest"
      echo "  Or:  git clone https://github.com/openclaw/acpx.git"
      STATUS_ACPX="PENDING"
    fi
  fi
fi
echo ""

# ── 3. Deploy config ────────────────────────────────────────────────────────
echo "--- Deploying acpx config ---"
if [ -f "$CONFIG_SRC" ]; then
  mkdir -p "$(dirname "$CONFIG_DEST")"
  cp "$CONFIG_SRC" "$CONFIG_DEST"
  echo "  [OK] Config deployed to ${CONFIG_DEST}"
  STATUS_CONFIG="OK"
else
  echo "  [FAIL] Source config not found: ${CONFIG_SRC}"
  STATUS_CONFIG="FAIL"
fi
echo ""

# ── 4. Create session persistence directory ──────────────────────────────────
echo "--- Creating session persistence directory ---"
mkdir -p "$SESSION_DIR"
if [ -d "$SESSION_DIR" ]; then
  echo "  [OK] Session dir: ${SESSION_DIR}"
  STATUS_SESSIONS="OK"
else
  echo "  [FAIL] Could not create ${SESSION_DIR}"
  STATUS_SESSIONS="FAIL"
fi
echo ""

# ── 5. Create log directory ──────────────────────────────────────────────────
echo "--- Creating log directory ---"
mkdir -p "$LOG_DIR"
if [ -d "$LOG_DIR" ]; then
  echo "  [OK] Log dir: ${LOG_DIR}"
  STATUS_LOGS="OK"
else
  echo "  [FAIL] Could not create ${LOG_DIR}"
  STATUS_LOGS="FAIL"
fi
echo ""

# ── 6. Check Claude CLI ─────────────────────────────────────────────────────
echo "--- Checking Claude Code CLI ---"
if command -v claude &>/dev/null; then
  echo "  [OK] Claude Code CLI found: $(which claude)"
  STATUS_CLAUDE="OK"
else
  echo "  [WARN] Claude Code CLI not found."
  echo "  Install: npm install -g @anthropic-ai/claude-code"
  STATUS_CLAUDE="MISSING"
fi
echo ""

# ── 7. Check Codex CLI ──────────────────────────────────────────────────────
echo "--- Checking Codex CLI ---"
if command -v codex &>/dev/null; then
  echo "  [OK] Codex CLI found: $(which codex)"
  STATUS_CODEX="OK"
else
  echo "  [WARN] Codex CLI not found."
  echo "  Install: npm install -g @openai/codex"
  STATUS_CODEX="MISSING"
fi
echo ""

# ── Status Summary ───────────────────────────────────────────────────────────
echo "============================================"
echo "  acpx Setup Summary"
echo "============================================"
echo "  Node.js 18+:    ${STATUS_NODE}"
echo "  acpx install:   ${STATUS_ACPX}"
echo "  Config deploy:  ${STATUS_CONFIG}"
echo "  Session dir:    ${STATUS_SESSIONS}"
echo "  Log dir:        ${STATUS_LOGS}"
echo "  Claude CLI:     ${STATUS_CLAUDE}"
echo "  Codex CLI:      ${STATUS_CODEX}"
echo "============================================"

# Exit 0 even if acpx or CLIs are not installed — config is what matters
if [ "$STATUS_CONFIG" = "OK" ] && [ "$STATUS_SESSIONS" = "OK" ]; then
  echo "Setup complete. acpx config ready."
  exit 0
else
  echo "Setup had failures. Check above for details."
  exit 1
fi
