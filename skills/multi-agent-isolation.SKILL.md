---
name: multi-agent-isolation
version: 1.0.0
tags: [memory, multi-agent, isolation]
---

# Multi-Agent Memory Isolation

## Principle
Each sub-agent has isolated memory via agent_id scoping through the MemOS plugin.
Shared knowledge (Obsidian vault, RagFlow datasets) is accessible to ALL agents.

## Isolation Rules

### Private to Each Agent (via agent_id)
- MemOS Cloud conversations: scoped by agent_id parameter
- Local Memos: tagged with agent-specific prefix (#agent:{agent_id})
- Self-eval data: each agent evaluates its OWN performance

### Shared Across All Agents
- Obsidian vault: all agents can read/write (with wiki-links)
- RagFlow datasets: shared knowledge base
- TOOLS.md: shared capability registry
- HEARTBEAT.md: shared proactive behaviors

## Agent IDs
| Agent | agent_id | Purpose |
|-------|----------|---------|
| Main (Eve) | openclaw-main | Primary orchestrator |
| Memory Agent | memory-agent | 5-layer search + curation |
| Research Agent | research-agent | Deep research tasks |
| Coding Delegate | coding-delegate-{n} | Claude Code sessions |
| Swarm Worker | swarm-{team}-{worker} | ClawTeam members |

## Verification
- Main agent should NOT see sub-agent private memos
- Sub-agents should NOT see each other's private memos  
- ALL agents should see Obsidian notes and RagFlow search results
- Memory Agent returns curated results from all layers (not raw dumps)
