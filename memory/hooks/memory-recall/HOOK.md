---
name: memory-recall
description: "Load active TODOs, missions, self-evals, and experiments from Memos on session start"
metadata:
  {
    "openclaw":
      {
        "emoji": "🧠",
        "events": ["agent:bootstrap"],
        "export": "default",
        "requires": { "bins": ["curl"] },
      },
  }
---

# Memory Recall Hook

Fires once on session start (`agent:bootstrap`). Queries the Memos API for active
context the agent should be aware of:

- `#todo` — open tasks
- `#mission` — current mission / objectives
- `#self-eval` — recent self-evaluations
- `#improvement` — active experiments

Results are formatted and pushed into `event.messages[]` so the agent starts every
session with full context from its memory layer.
