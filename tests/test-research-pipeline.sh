#!/bin/bash
# Research Pipeline Integration Test
# Verifies all components of the research pipeline are accessible

echo "=== Research Pipeline Integration Test ==="
echo ""

PASS=0
FAIL=0
SKIP=0

RIG="nova-rig"

test_pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
test_fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
test_skip() { echo "  [SKIP] $1"; SKIP=$((SKIP + 1)); }

# 1. Input Sources
echo "Input Sources:"
# crawl4ai
if curl -sf --connect-timeout 5 "http://$RIG:11235/health" >/dev/null 2>&1; then
  test_pass "crawl4ai (web → markdown)"
else
  test_skip "crawl4ai not reachable on $RIG:11235"
fi

# Tavily
if [ -f "$HOME/.openclaw/mcp-servers/tavily.json" ]; then
  test_pass "Tavily MCP configured"
else
  test_fail "Tavily MCP config missing"
fi

# NotebookLM
if [ -f "$HOME/.openclaw/mcp-servers/notebooklm.json" ]; then
  test_pass "NotebookLM MCP configured"
else
  test_fail "NotebookLM MCP config missing"
fi

# SurfSense
if curl -sf --connect-timeout 5 "http://$RIG:3000" >/dev/null 2>&1; then
  test_pass "SurfSense (hybrid search)"
else
  test_skip "SurfSense not reachable on $RIG:3000"
fi

# gws
if [ -f "$HOME/.openclaw/mcp-servers/gws.json" ]; then
  test_pass "Google Workspace configured"
else
  test_fail "Google Workspace config missing"
fi

# 2. Processing (Skills)
echo ""
echo "Processing Skills:"
BRAIN="/mnt/ssd/openclaw-brain"
for skill in when-to-research memory-routing research-pipeline; do
  if [ -f "$BRAIN/workspace/skills/${skill}.SKILL.md" ]; then
    test_pass "${skill}.SKILL.md"
  else
    test_fail "${skill}.SKILL.md missing"
  fi
done

# 3. Memory Destinations
echo ""
echo "Memory Destinations:"
# Memos (Layer 2)
if curl -sf --connect-timeout 5 "http://$RIG:5230/api/v1/workspace/profile" >/dev/null 2>&1; then
  test_pass "Layer 2: Memos"
else
  test_skip "Memos not reachable"
fi

# Obsidian (Layer 3 — local on nova)
if [ -d "/mnt/ssd/obsidian-vault" ] || [ -d "$BRAIN/obsidian-vault" ]; then
  test_pass "Layer 3: Obsidian vault"
else
  test_skip "Obsidian vault not deployed yet"
fi

# RagFlow (Layer 4)
if curl -sf --connect-timeout 5 "http://$RIG:9380" >/dev/null 2>&1; then
  test_pass "Layer 4: RagFlow"
else
  test_skip "RagFlow not reachable"
fi

# Ingestion scripts
if [ -x "$BRAIN/setup/scripts/ingest-to-ragflow.sh" ]; then
  test_pass "Ingestion script (ingest-to-ragflow.sh)"
else
  test_fail "Ingestion script missing or not executable"
fi

if [ -x "$BRAIN/setup/scripts/sync-obsidian-to-ragflow.sh" ]; then
  test_pass "Sync script (sync-obsidian-to-ragflow.sh)"
else
  test_fail "Sync script missing or not executable"
fi

# 4. TOOLS.md completeness
echo ""
echo "TOOLS.md Registry:"
TOOLS="$BRAIN/workspace/TOOLS.md"
for tool in notebooklm tavily crawl4ai surfsense gws; do
  if grep -qi "$tool" "$TOOLS" 2>/dev/null; then
    test_pass "TOOLS.md has $tool"
  else
    test_fail "TOOLS.md missing $tool"
  fi
done

echo ""
echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
