#!/bin/bash
set -euo pipefail

echo "=== Delegation Test ==="

PASS=0
FAIL=0

test_pass() { echo "  [PASS] $1"; ((PASS++)); }
test_fail() { echo "  [FAIL] $1"; ((FAIL++)); }

# Check acpx is installed
echo "Testing acpx..."
if command -v acpx &>/dev/null; then
  test_pass "acpx installed"
  
  # Check agent registry
  if [ -f ~/.acpx/registry.json ]; then
    test_pass "Agent registry exists"
  else
    test_fail "Agent registry missing"
  fi
  
  # Test basic connectivity (ping, don't actually run agents)
  acpx --version &>/dev/null && \
    test_pass "acpx responds" || test_fail "acpx not responding"
else
  test_fail "acpx not installed"
fi

# Check Claude Code available
if command -v claude &>/dev/null; then
  test_pass "Claude Code installed"
else
  echo "  [SKIP] Claude Code not installed (optional)"
fi

echo ""
echo "=== Delegation: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
