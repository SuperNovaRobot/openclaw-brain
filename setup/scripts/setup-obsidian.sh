#!/bin/bash
set -euo pipefail

echo "=== Setting up Obsidian Vault ==="

VAULT_PATH="${OBSIDIAN_VAULT_PATH:-/mnt/ssd/obsidian-vault}"

# Copy vault template
cp -r obsidian-vault/* "$VAULT_PATH/" 2>/dev/null || true

# Initialize git in vault
cd "$VAULT_PATH"
git init
git add -A
git commit -m "Initial vault setup"

# Add remote if configured
if [ -n "${OBSIDIAN_GIT_REMOTE:-}" ]; then
  git remote add origin "$OBSIDIAN_GIT_REMOTE"
  echo "Git remote configured: $OBSIDIAN_GIT_REMOTE"
fi

# Install obsidian-cli
if ! command -v obsidian-cli &> /dev/null; then
  echo "Installing obsidian-cli..."
  cargo install obsidian-cli 2>/dev/null || echo "Install obsidian-cli manually: https://github.com/jwhonce/obsidian-cli"
fi

# Configure obsidian-cli
mkdir -p ~/.config/obsidian-cli
cat > ~/.config/obsidian-cli/config.toml <<TOML
vault_path = "$VAULT_PATH"
blacklist = [".obsidian", ".git", "node_modules"]
TOML

echo "Obsidian vault ready at: $VAULT_PATH"
echo "Start MCP server: obsidian-cli serve"
