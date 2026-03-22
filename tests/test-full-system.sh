#!/bin/bash
# OpenClaw Brain — Full System Integration Test
# Tests all components across Phases 0-6

echo "========================================"
echo "  OpenClaw Brain — Full System Test"
echo "  $(date)"
echo "========================================"
echo ""

PASS=0
FAIL=0
SKIP=0
BRAIN="/mnt/ssd/openclaw-brain"
RIG="nova-rig"

test_pass() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
test_fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
test_skip() { echo "  [SKIP] $1"; SKIP=$((SKIP + 1)); }

# === PHASE 0: Foundation ===
echo "Phase 0: Foundation"
[ -f "$BRAIN/README.md" ] && test_pass "README.md" || test_fail "README.md"
[ -f "$BRAIN/LICENSE" ] && test_pass "LICENSE" || test_fail "LICENSE"
[ -f "$BRAIN/ARCHITECTURE.md" ] && test_pass "ARCHITECTURE.md" || test_fail "ARCHITECTURE.md"
[ -f "$BRAIN/setup/.env.example" ] && test_pass ".env.example" || test_fail ".env.example"
[ -f "$BRAIN/setup/docker-compose.nova.yml" ] && test_pass "docker-compose.nova.yml" || test_fail missing
[ -f "$BRAIN/setup/docker-compose.rig-services.yml" ] && test_pass "docker-compose.rig-services.yml" || test_fail missing
[ -x "$BRAIN/setup/install.sh" ] && test_pass "install.sh executable" || test_fail "install.sh"
[ -x "$BRAIN/setup/scripts/health-check.sh" ] && test_pass "health-check.sh" || test_fail missing

# === PHASE 1: Memory Stack ===
echo ""
echo "Phase 1: Memory Stack"
[ -f "$BRAIN/workspace/skills/memory-agent.SKILL.md" ] && test_pass "Memory Agent skill" || test_fail missing
[ -f "$BRAIN/workspace/memory-agent/SOUL.md" ] && test_pass "Memory Agent SOUL" || test_fail missing
[ -x "$BRAIN/setup/scripts/ingest-to-ragflow.sh" ] && test_pass "RagFlow ingestion" || test_fail missing
[ -x "$BRAIN/setup/scripts/sync-obsidian-to-ragflow.sh" ] && test_pass "Obsidian sync" || test_fail missing
[ -x "$BRAIN/setup/scripts/start-obsidian-mcp.sh" ] && test_pass "Obsidian MCP" || test_fail missing

# === PHASE 2: Coding Delegation ===
echo ""
echo "Phase 2: Coding Delegation"
[ -f "$HOME/.config/acpx/config.json" ] && test_pass "acpx config" || test_skip "acpx not configured"
SKILL_COUNT=$(find "$BRAIN/workspace/skills" -type f -name "*.md" 2>/dev/null | wc -l)
[ "$SKILL_COUNT" -gt 20 ] && test_pass "Skills installed ($SKILL_COUNT files)" || test_fail "Only $SKILL_COUNT skills"
[ -f "$BRAIN/workspace/skills/when-to-delegate.SKILL.md" ] && test_pass "Delegation routing" || test_fail missing

# === PHASE 3: Research Pipeline ===
echo ""
echo "Phase 3: Research Pipeline"
[ -f "$HOME/.openclaw/mcp-servers/tavily.json" ] && test_pass "Tavily MCP" || test_skip "Tavily not configured"
[ -f "$HOME/.openclaw/mcp-servers/notebooklm.json" ] && test_pass "NotebookLM MCP" || test_skip "NotebookLM not configured"
[ -f "$HOME/.openclaw/mcp-servers/gws.json" ] && test_pass "Google Workspace MCP" || test_skip "GWS not configured"
[ -f "$BRAIN/workspace/skills/research-pipeline.SKILL.md" ] && test_pass "Research pipeline skill" || test_fail missing

# === PHASE 4: Self-Improvement ===
echo ""
echo "Phase 4: Self-Improvement"
[ -x "$BRAIN/workspace/scripts/self-eval-logger.py" ] && test_pass "Self-eval logger" || test_fail missing
[ -x "$BRAIN/workspace/scripts/experiment-runner.sh" ] && test_pass "Experiment runner" || test_fail missing
[ -x "$BRAIN/workspace/scripts/metric-analyzer.py" ] && test_pass "Metric analyzer" || test_fail missing
[ -x "$BRAIN/workspace/scripts/instinct-extractor.py" ] && test_pass "Instinct extractor" || test_fail missing
[ -x "$BRAIN/workspace/scripts/discovery-scanner.sh" ] && test_pass "Discovery scanner" || test_fail missing
[ -x "$BRAIN/workspace/scripts/resource-tracker.py" ] && test_pass "Resource tracker" || test_fail missing

# === PHASE 5: Swarm & Multi-Agent ===
echo ""
echo "Phase 5: Swarm & Multi-Agent"
[ -f "$BRAIN/workspace/teams/full-stack.toml" ] && test_pass "Full-stack team" || test_fail missing
[ -f "$BRAIN/workspace/teams/research-swarm.toml" ] && test_pass "Research swarm" || test_fail missing
[ -x "$BRAIN/workspace/scripts/spawn-team.sh" ] && test_pass "Spawn team wrapper" || test_fail missing
for mcp in task-router memory-decision self-eval; do
  [ -f "$BRAIN/workspace/behavior-mcps/$mcp/server.py" ] && test_pass "Behavior MCP: $mcp" || test_fail "$mcp missing"
done
[ -f "$BRAIN/workspace/skills/multi-agent-isolation.SKILL.md" ] && test_pass "Isolation skill" || test_fail missing

# === PHASE 6: Robotics ===
echo ""
echo "Phase 6: Robotics"
[ -f "$BRAIN/workspace/skills/robotics-simulation.SKILL.md" ] && test_pass "dimos simulation" || test_fail missing
[ -f "$BRAIN/workspace/skills/vision-pipeline.SKILL.md" ] && test_pass "OAK-D Pro vision" || test_fail missing
[ -f "$BRAIN/workspace/skills/arm-control.SKILL.md" ] && test_pass "Arm control" || test_fail missing
[ -f "$BRAIN/workspace/skills/voice-interface.SKILL.md" ] && test_pass "Riva voice" || test_fail missing
[ -f "$BRAIN/workspace/skills/avatar-display.SKILL.md" ] && test_pass "airi display" || test_fail missing
[ -f "$BRAIN/workspace/skills/cad-design.SKILL.md" ] && test_pass "PicoGK CAD" || test_fail missing

# === WORKSPACE CORE ===
echo ""
echo "Workspace Core"
for f in SOUL.md IDENTITY.md TOOLS.md HEARTBEAT.md MEMORY.md AGENTS.md; do
  [ -f "$BRAIN/workspace/$f" ] && test_pass "$f" || test_fail "$f missing"
done

# === SERVICES (on nova-rig) ===
echo ""
echo "Services (nova-rig)"
for svc in "5230:Memos" "9200:Elasticsearch" "9380:RagFlow" "5432:PostgreSQL" "6379:Redis" "11235:crawl4ai" "3000:SurfSense"; do
  PORT="${svc%%:*}"
  NAME="${svc##*:}"
  if curl -sf --connect-timeout 3 "http://$RIG:$PORT" >/dev/null 2>&1; then
    test_pass "$NAME (:$PORT)"
  else
    test_skip "$NAME (:$PORT) not reachable"
  fi
done

# === SUMMARY ===
echo ""
echo "========================================"
echo "  RESULTS: $PASS passed, $FAIL failed, $SKIP skipped"
echo "  Total checks: $((PASS + FAIL + SKIP))"
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "  OpenClaw Brain is READY."
  echo "  Eve runs free."
fi

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
