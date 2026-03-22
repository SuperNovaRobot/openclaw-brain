#!/bin/bash
set -euo pipefail
echo "=== Running Health Test ==="
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$REPO_DIR/setup/scripts/health-check.sh"
