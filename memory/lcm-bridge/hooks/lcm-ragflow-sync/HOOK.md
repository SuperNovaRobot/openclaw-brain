---
name: lcm-ragflow-sync
description: "Sync new LCM leaf summaries to RagFlow after each turn for semantic search over conversation history"
metadata:
  {
    "openclaw":
      {
        "emoji": "🔄",
        "events": ["message:sent"],
        "export": "default",
        "requires": { "bins": ["curl", "python3"] },
      },
  }
---

# LCM → RagFlow Sync Hook

Fires after every outbound message (`message:sent`). Checks if Lossless Claw
created a new summary during this turn and syncs it to RagFlow for semantic
search.

This is the real-time complement to the batch sync script at
`memory/lcm-bridge/sync-to-ragflow.sh`. The batch script handles historical
backfill; this hook keeps RagFlow current turn-by-turn.

## How It Works

1. Query `~/.openclaw/lcm.db` for the most recent summary (by rowid)
2. Compare against `.last-sync-id` file to detect new summaries
3. If new: write a markdown document and POST to RagFlow `lcm-summaries` dataset
4. Trigger RagFlow document parsing
5. Update `.last-sync-id`
