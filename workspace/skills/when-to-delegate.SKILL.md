# When to Delegate

## Decision Matrix

| Condition | Action |
|-----------|--------|
| <100 lines, within capability | Handle directly |
| >500 lines, complex code | Delegate to Claude Code via acpx |
| Test writing needed | Delegate to Codex via acpx |
| 2+ independent tasks | Spawn ClawTeam swarm |
| Deep research, multiple topics | Spawn research swarm |
| Unknown domain | Search skills registry first |
| Hardware interaction | Check dimos simulation first |

## Rules
- Always delegate heavy coding — I am the orchestrator, not the coder
- When delegating, provide full context: spec, files, constraints
- Review all delegated work before accepting
- Log delegation decisions to Memos (#delegation)
- Track delegation success rate in self-eval
