#!/bin/bash
set -euo pipefail

echo "=== Setting up Obsidian Git Auto-Sync ==="

source "$(dirname "$0")/../../setup/.env" 2>/dev/null || true

VAULT_PATH="${OBSIDIAN_VAULT_PATH:-/mnt/ssd/obsidian-vault}"
LOG_DIR="/mnt/ssd/logs"

mkdir -p "$LOG_DIR"

# Initialize vault git if needed
if [ ! -d "$VAULT_PATH/.git" ]; then
  echo "Initializing git in vault..."
  cd "$VAULT_PATH"
  git init
  git add -A
  git commit -m "Initial vault setup" 2>/dev/null || true
fi

# Add remote if configured and not already set
if [ -n "${OBSIDIAN_GIT_REMOTE:-}" ]; then
  cd "$VAULT_PATH"
  git remote get-url origin 2>/dev/null || git remote add origin "$OBSIDIAN_GIT_REMOTE"
  echo "Git remote: $OBSIDIAN_GIT_REMOTE"
fi

# Write the sync script
cat > "$VAULT_PATH/.git-sync.sh" << 'SYNC'
#!/bin/bash
cd /mnt/ssd/obsidian-vault
git add -A
git diff-index --quiet HEAD 2>/dev/null || git commit -m "auto-sync $(date +%Y-%m-%d_%H:%M)"
git push origin main 2>/dev/null || true
SYNC
chmod +x "$VAULT_PATH/.git-sync.sh"

# Add cron job (every 10 minutes) — idempotent
CRON_ENTRY="*/10 * * * * $VAULT_PATH/.git-sync.sh >> $LOG_DIR/obsidian-sync.log 2>&1"
(crontab -l 2>/dev/null | grep -v "obsidian-vault/.git-sync" ; echo "$CRON_ENTRY") | crontab -

echo ""
echo "Obsidian git auto-sync configured."
echo "  Sync script: $VAULT_PATH/.git-sync.sh"
echo "  Cron: every 10 minutes"
echo "  Log: $LOG_DIR/obsidian-sync.log"
echo "  Verify: crontab -l | grep obsidian"
