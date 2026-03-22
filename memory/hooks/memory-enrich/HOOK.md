---
name: memory-enrich
description: "Enrich inbound messages with relevant memories from Memos"
metadata:
  {
    "openclaw":
      {
        "emoji": "🔍",
        "events": ["message:received"],
        "export": "default",
        "requires": { "bins": ["curl"] },
      },
  }
---

# Memory Enrich Hook

Fires on every inbound message (`message:received`). Extracts keywords from the
incoming message, searches Memos for matching content, and injects relevant
memories (capped at ~500 tokens) into context.

This gives the agent access to its accumulated knowledge without needing to
explicitly search — memories surface automatically when relevant.
