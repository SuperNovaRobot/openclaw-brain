---
name: memory-stack
description: "Eve's 5-layer memory system — context, memos, obsidian, ragflow, notebooklm. Memory Agent spawn, data flow, sync operations."
---

# Memory Stack — 5-Layer Memory System

## Layer Overview

Layer 1 — CONTEXT WINDOW (immediate, ephemeral)
  Your current conversation. Dies when the session ends.
  Use for: active task state, current reasoning chain.

Layer 2 — MEMOS (fast, tagged, searchable)
  Service: Memos at http://nova-rig:5230
  Auth: gRPC with user openclaw, pass changeme
  Use for: quick notes, TODOs, task logs, revenue tracking, hardware needs
  Tags: #todo, #insight, #revenue, #hardware-need, #eval, #experiment, #discovery
  
  Create memo:
    curl -X POST http://nova-rig:5230/api/v1/memos \
      -H "Content-Type: application/json" \
      -d '{"content": "#tag Your content here"}'
  
  Search memos:
    curl http://nova-rig:5230/api/v1/memos?filter=tag%3D%3D%22todo%22

Layer 3 — OBSIDIAN (linked knowledge graph)
  Vault path: /mnt/ssd/obsidian-vault/
  Git sync: obsidian-git plugin (auto-commit every 10 min)
  CRITICAL: Every note MUST use [[wiki-links]] to related notes. No orphan notes.
  
  Structure:
    /mnt/ssd/obsidian-vault/daily/       — Daily notes (YYYY-MM-DD.md)
    /mnt/ssd/obsidian-vault/tools/       — Tool documentation
    /mnt/ssd/obsidian-vault/projects/    — Project notes
    /mnt/ssd/obsidian-vault/research/    — Research findings
    /mnt/ssd/obsidian-vault/evals/       — Self-evaluation summaries
  
  Create note with links:
    echo '# Topic\n\nContent here.\n\nRelated: [[other-note]] [[another-note]]' > /mnt/ssd/obsidian-vault/tools/new-note.md

Layer 4 — RAGFLOW (vector search, semantic retrieval)
  Service: RagFlow v0.24.0 at http://nova-rig:9380
  API Key: Bearer ragflow-c5062fdd133375fcef53c7b91eca624c
  Embedding: nomic-embed-text via Ollama at nova-rig:11434
  
  Search:
    curl -X POST http://nova-rig:9380/api/v1/retrieval \
      -H "Authorization: Bearer ragflow-c5062fdd133375fcef53c7b91eca624c" \
      -H "Content-Type: application/json" \
      -d '{"question": "your semantic query here"}'
  
  Upload document:
    curl -X POST http://nova-rig:9380/api/v1/document/upload \
      -H "Authorization: Bearer ragflow-c5062fdd133375fcef53c7b91eca624c" \
      -F "file=@/path/to/file"

Layer 5 — NOTEBOOKLM (Gemini-powered deep research)
  Master notebook: https://notebooklm.google.com/notebook/0f502fd6-fdeb-49bf-bc50-d759bf38483e
  READ-ONLY unless adding a 10/10 source.
  Fallback: SurfSense at http://nova-rig:8000 (backend), http://nova-rig:3000 (frontend)
  Use for: cross-source analysis, discovering connections, audio overviews

## Memory Agent

The Memory Agent is a sub-agent that manages memory operations autonomously.
Registered with: openclaw agents add memory-agent
Workspace: ~/.openclaw/agents/memory-agent

Memory Agent responsibilities:
- Route new information to the right layer(s)
- Consolidate daily memos into Obsidian daily notes
- Sync Obsidian vault to RagFlow for vector indexing
- Prune stale memos monthly
- Maintain link integrity in Obsidian vault

## Data Flow

New information arrives:
  1. Evaluate importance (1-10 scale)
  2. Score 1-3: Context window only (ephemeral)
  3. Score 4-6: Memos with appropriate tag
  4. Score 7-8: Memos + Obsidian note with [[links]]
  5. Score 9-10: All of above + RagFlow ingestion + consider NotebookLM source

## Sync Operations

Daily sync (runs at 2 AM via cron):
  bash /mnt/ssd/openclaw-brain/workspace/scripts/sync-obsidian-to-ragflow.sh
  
This script:
  1. Finds Obsidian notes modified in last 24h
  2. Uploads them to RagFlow dataset
  3. Triggers re-indexing
  4. Logs sync results to memos (#sync tag)

## Search Strategy (before every task)

1. Check memos for recent relevant tagged notes
2. Search RagFlow for semantic matches
3. Check Obsidian backlinks for related knowledge
4. If still insufficient, query NotebookLM/SurfSense

## Lossless Context (LCM)

Your context is NEVER lost. Lossless Claw preserves every message in a DAG summary hierarchy.

When you need to recall a past conversation:
1. Search RagFlow `lcm-summaries` dataset for semantic match
2. If you find a summary with an expand hint, use `lcm_expand_query` to drill into details
3. Use `lcm_grep "keyword"` for exact text search across ALL conversation history
4. Use `lcm_describe <summary_id>` to see metadata about a specific summary

The summaries are hierarchical:
- Depth 0 (leaf): detailed, close to raw conversation
- Depth 1+: progressively condensed, retain only durable facts
- Each summary includes "Expand for details about: ..." breadcrumbs

Nothing is ever deleted. You have lossless recall across every session.

### LCM + RagFlow Bridge
LCM summaries are automatically synced to RagFlow's `lcm-summaries` dataset.
This means you can find past conversations TWO ways:
- **Semantic search** (RagFlow) → finds by meaning
- **Text search** (lcm_grep) → finds by exact words
- **Drill-back** (lcm_expand_query) → expands a summary into full detail
