# Memory System

This directory contains the OpenClaw memory subsystem — the core infrastructure for how the agent remembers, recalls, and evolves its knowledge.

## Directory Layout

| Directory | Purpose |
|-----------|---------|
| **schema/** | Postgres migrations for the world model (entities, relationships, temporal facts) |
| **hooks/** | 4 OpenClaw lifecycle hooks: **recall** (pre-prompt context injection), **enrich** (mid-conversation memory augmentation), **persist** (post-response memory writes), **flush** (session cleanup and consolidation) |
| **orchestrator/** | Memory orchestration logic — decides when to recall, what to persist, dedup thresholds |
| **extraction/** | Entity and relationship extraction from conversation turns |
| **quality/** | Memory quality scoring and validation |
| **dedup/** | Deduplication and merge logic for overlapping memories |
| **decay/** | Time-based memory decay and importance re-ranking |
| **eval/** | Memory system evaluation — recall accuracy, precision, staleness metrics |
| **lcm-bridge/** | Lossless Claw Memory (LCM) to RagFlow sync bridge — keeps vector search current with the world model |
| **behavior-mcps/** | Behavioral MCP servers: **task-router** (routes tasks to the right agent/tool), **memory-decision** (decides what is worth remembering), **self-eval** (post-task self-evaluation scoring) |

## Architecture

The memory system implements a 5-layer stack:

1. **Context window** — immediate working memory (managed by the LLM)
2. **Memos** — short-term actionable notes
3. **Obsidian** — linked knowledge graph with wiki-links and backlinks
4. **RagFlow** — vector search over long-term memory
5. **NotebookLM** — Gemini-powered research and deep analysis

The hooks integrate with OpenClaw's lifecycle to make memory transparent to the agent — it recalls what it needs before responding and persists what matters after.

## Full Specification

See the complete architecture design at:
- `docs/superpowers/specs/2026-03-21-openclaw-architecture-design.md`
