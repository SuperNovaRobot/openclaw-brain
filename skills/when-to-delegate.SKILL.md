# When to Delegate — Task Routing Skill

## Purpose
Decide whether to handle a task directly, use installed skills, or delegate to an external agent via acpx.

## Decision Framework

### 1. Estimate Task Size
- Count estimated lines of code, files to modify, and complexity

### 2. Route Based on Size and Type

#### HANDLE DIRECTLY (< 100 lines)
- Single-file changes, config edits, quick scripts, memory lookups
- Action: Execute directly

#### USE INSTALLED SKILLS (100-500 lines)
- Well-defined scope, matches a skill domain
- Action: Activate matching skill from ECC (204), claude-skills (813), or Superpowers (23)

#### DELEGATE TO CLAUDE CODE (> 500 lines)
- Multi-file changes, complex features, heavy refactoring
- Action: acpx claude -s {session-name} "{detailed prompt}"

#### DELEGATE TO CODEX (alternative)
- Same criteria as Claude Code
- Use when Claude Code is unavailable or rate-limited
- Action: acpx codex "{prompt}"

#### TRIGGER BMAD PIPELINE (complex architecture)
- New system design, multiple interacting components
- Action: analyst → PM → architect → developer pipeline
- See: workspace/bmad-agents/

#### SPAWN PARALLEL AGENTS (independent tasks)
- Multiple independent tasks that can run simultaneously
- Action: acpx claude -s task-1 "{p1}" & acpx claude -s task-2 "{p2}" & wait

## After Delegation
1. Receive structured ACP response
2. Review quality
3. Integrate into codebase or memory
4. Self-evaluate the delegation decision (#self-eval, #delegation)

## Quick Reference

| Task Size | Lines | Handler | Via |
|-----------|-------|---------|-----|
| Tiny | <100 | Self | Direct |
| Small | 100-500 | Self + Skills | ECC/claude-skills/Superpowers |
| Large | >500 | Claude Code | acpx claude -s {name} |
| Architecture | Any | BMAD Pipeline | analyst→PM→architect→dev |
| Parallel | Multiple | Multiple agents | acpx (parallel sessions) |
| Research | Any | OpenClaw sub | acpx openclaw --session research |
