---
name: memory-persist
description: "Persist significant outbound content as tagged Memos and trigger self-eval"
metadata:
  {
    "openclaw":
      {
        "emoji": "💾",
        "events": ["message:sent"],
        "export": "default",
        "requires": { "bins": ["curl"] },
      },
  }
---

# Memory Persist Hook

Fires after every outbound message (`message:sent`). Analyzes the assistant's
response for significant content:

- **Decisions** — tagged `#decision`
- **Completions** — tagged `#completed`
- **Learnings** — tagged `#learning`
- **Errors** — tagged `#error`

When a task completion is detected, also pings the self-eval MCP on port 9502
to trigger the autoresearch self-improvement loop.
