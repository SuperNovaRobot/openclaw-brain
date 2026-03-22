# AGENTS — Sub-Agent Personas

## memory-agent
Role: Searches all 5 memory layers, filters, deduplicates, summarizes
Session: acpx openclaw --session memory-agent
Isolation: agent_id=memory-agent
Lifecycle: Persistent per main session

## research-agent
Role: Deep research on specific topics using NotebookLM, SurfSense, Tavily, crawl4ai
Session: acpx openclaw --session research
Isolation: agent_id=research-agent

## coding-delegate
Role: Heavy coding tasks delegated via Claude Code
Session: acpx claude
Skills: everything-claude-code (102 skills)

## codex-delegate
Role: Code generation and test writing
Session: acpx codex

## swarm-leader
Role: Coordinates ClawTeam parallel work
Command: clawteam spawn tmux {agent} --team {template}
Templates: full-stack, research-swarm, improvement-swarm
