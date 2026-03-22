---
name: memory-flush
description: "Flush key context to Memos before session context is compressed"
metadata:
  {
    "openclaw":
      {
        "emoji": "🛟",
        "events": ["session:compact:before"],
        "export": "default",
        "requires": { "bins": ["curl"] },
      },
  }
---

# Memory Flush Hook

Fires before context compression (`session:compact:before`). This is the safety
net for the autoresearch loop — it ensures key facts, decisions, and progress
are persisted to Memos before the context window is compacted.

Extracts from the messages about to be compressed:
- Active tasks and their status
- Decisions made during the session
- Key findings and learnings
- Any pending items that need follow-up

All saved with `#context-flush` tag for easy retrieval by `memory-recall`.
