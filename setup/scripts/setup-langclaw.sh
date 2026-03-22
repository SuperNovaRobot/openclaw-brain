#!/bin/bash
# setup-langclaw.sh — Install and configure langclaw LangChain bridge for OpenClaw
# langclaw (tisu19021997/langclaw) routes LangChain calls through OpenClaw gateway.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
DEPS_DIR="${REPO_DIR}/setup/deps"
CONFIG_DIR="${HOME}/.openclaw/langclaw"
CONFIG_FILE="${CONFIG_DIR}/config.json"

STATUS_PIP="SKIP"
STATUS_CLONE="SKIP"
STATUS_CONFIG="SKIP"
STATUS_STUB="SKIP"

LANGCLAW_AVAILABLE=false

echo "============================================"
echo "  langclaw LangChain Bridge Setup"
echo "============================================"
echo ""

# ── 1. Attempt pip install ───────────────────────────────────────────────────
echo "--- Attempting pip install langclaw ---"
if command -v pip3 &>/dev/null; then
  if pip3 install langclaw 2>/dev/null; then
    echo "  [OK] langclaw installed via pip"
    STATUS_PIP="OK"
    LANGCLAW_AVAILABLE=true
  else
    echo "  [INFO] pip install langclaw failed (package may not be on PyPI yet)"
    STATUS_PIP="NOT_ON_PYPI"
  fi
elif command -v pip &>/dev/null; then
  if pip install langclaw 2>/dev/null; then
    echo "  [OK] langclaw installed via pip"
    STATUS_PIP="OK"
    LANGCLAW_AVAILABLE=true
  else
    echo "  [INFO] pip install langclaw failed (package may not be on PyPI yet)"
    STATUS_PIP="NOT_ON_PYPI"
  fi
else
  echo "  [WARN] pip not found"
  STATUS_PIP="NO_PIP"
fi
echo ""

# ── 2. If pip failed, clone from GitHub ──────────────────────────────────────
if [ "$LANGCLAW_AVAILABLE" = false ]; then
  echo "--- Attempting GitHub clone ---"
  CLONE_DIR="${DEPS_DIR}/langclaw"
  if [ -d "$CLONE_DIR" ]; then
    echo "  [OK] langclaw already cloned at ${CLONE_DIR}"
    STATUS_CLONE="EXISTS"
    LANGCLAW_AVAILABLE=true
  elif git clone https://github.com/tisu19021997/langclaw.git "$CLONE_DIR" 2>/dev/null; then
    echo "  [OK] Cloned langclaw to ${CLONE_DIR}"
    STATUS_CLONE="OK"
    LANGCLAW_AVAILABLE=true
    # Attempt local install if setup.py or pyproject.toml exists
    if [ -f "$CLONE_DIR/setup.py" ] || [ -f "$CLONE_DIR/pyproject.toml" ]; then
      echo "  Attempting local install from clone..."
      if pip3 install -e "$CLONE_DIR" 2>/dev/null || pip install -e "$CLONE_DIR" 2>/dev/null; then
        echo "  [OK] langclaw installed from local clone"
      else
        echo "  [INFO] Local install failed — will use as source reference"
      fi
    fi
  else
    echo "  [WARN] GitHub clone failed (network issue or repo not public yet)"
    STATUS_CLONE="FAIL"
  fi
  echo ""
fi

# ── 3. Deploy configuration ─────────────────────────────────────────────────
echo "--- Deploying langclaw config ---"
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_FILE" << CONFIG_EOF
{
  "gateway": "http://localhost:18789",
  "middleware": {
    "rbac": {"enabled": false, "config_path": ""},
    "rate_limiting": {"enabled": true, "max_requests_per_minute": 60},
    "pii_redaction": {"enabled": false}
  },
  "session_persistence": {
    "backend": "postgresql",
    "connection": "postgresql://openclaw:changeme@nova-rig:5432/openclaw"
  },
  "message_bus": {
    "backend": "asyncio",
    "production_backend": "rabbitmq"
  }
}
CONFIG_EOF

if [ -f "$CONFIG_FILE" ]; then
  echo "  [OK] Config deployed to ${CONFIG_FILE}"
  STATUS_CONFIG="OK"
else
  echo "  [FAIL] Could not create config at ${CONFIG_FILE}"
  STATUS_CONFIG="FAIL"
fi
echo ""

# ── 4. If langclaw not available, create integration stub ────────────────────
if [ "$LANGCLAW_AVAILABLE" = false ]; then
  echo "--- Creating integration stub ---"
  STUB_DIR="${DEPS_DIR}/langclaw"
  mkdir -p "$STUB_DIR"
  cat > "$STUB_DIR/README.md" << STUB_EOF
# langclaw Integration Stub

langclaw (tisu19021997/langclaw) could not be installed via pip or cloned from GitHub.

## Integration Plan

1. **Monitor PyPI** for `langclaw` package availability
2. **Monitor GitHub** at https://github.com/tisu19021997/langclaw for public release
3. **Once available**, re-run `setup/scripts/setup-langclaw.sh`

## What langclaw Does

langclaw is a LangChain-to-OpenClaw routing bridge that:
- Intercepts LangChain chain/agent calls
- Routes them through the OpenClaw gateway (port 18789)
- Applies middleware (RBAC, rate limiting, PII redaction)
- Persists sessions to PostgreSQL
- Communicates via asyncio message bus (upgradable to RabbitMQ)

## Manual Install (when available)

```bash
pip install langclaw
# or
git clone https://github.com/tisu19021997/langclaw.git setup/deps/langclaw
pip install -e setup/deps/langclaw
```

## Config Location

~/.openclaw/langclaw/config.json
STUB_EOF

  cat > "$STUB_DIR/__init__.py" << INIT_EOF
"""
langclaw stub — LangChain-to-OpenClaw routing bridge.

This stub exists because the real langclaw package could not be installed.
Once tisu19021997/langclaw is available on PyPI or GitHub, re-run:
    setup/scripts/setup-langclaw.sh

Config location: ~/.openclaw/langclaw/config.json
Gateway endpoint: http://localhost:18789
"""

__version__ = "0.0.0-stub"
__status__ = "pending_install"

def route_chain(*args, **kwargs):
    raise NotImplementedError(
        "langclaw is not installed. Run setup/scripts/setup-langclaw.sh "
        "after the package becomes available."
    )
INIT_EOF
  echo "  [OK] Integration stub created at ${STUB_DIR}/"
  STATUS_STUB="OK"
  echo ""
fi

# ── Status Summary ───────────────────────────────────────────────────────────
echo "============================================"
echo "  langclaw Setup Summary"
echo "============================================"
echo "  pip install:     ${STATUS_PIP}"
echo "  GitHub clone:    ${STATUS_CLONE}"
echo "  Config deploy:   ${STATUS_CONFIG}"
if [ "$LANGCLAW_AVAILABLE" = false ]; then
  echo "  Integration stub: ${STATUS_STUB}"
fi
echo "  langclaw ready:  ${LANGCLAW_AVAILABLE}"
echo ""
echo "  Config: ${CONFIG_FILE}"
echo "  Gateway: http://localhost:18789"
echo "  Session DB: postgresql://openclaw:***@nova-rig:5432/openclaw"
echo "============================================"

if [ "$STATUS_CONFIG" = "OK" ]; then
  echo "Setup complete. Config deployed."
  exit 0
else
  echo "Setup had failures. Check above for details."
  exit 1
fi
