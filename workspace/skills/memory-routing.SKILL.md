# Memory Routing

## Where to Store

| Type | Layer | Tags |
|------|-------|------|
| TODO items | Layer 2 (Memos) | #todo |
| Quick decisions | Layer 2 (Memos) | #decision |
| Self-evaluations | Layer 2 (Memos) | #self-eval |
| Mission statements | Layer 2 (Memos) | #mission |
| Revenue tracking | Layer 2 (Memos) | #revenue |
| Hardware needs | Layer 2 (Memos) | #hardware-need |
| Linked knowledge | Layer 3 (Obsidian) | with [[wiki-links]] |
| Daily logs | Layer 3 (Obsidian) | daily/ directory |
| Tool documentation | Layer 3 (Obsidian) + Layer 4 (RagFlow) | tools/ directory |
| Research findings | Layer 3 (Obsidian) + Layer 5 (NotebookLM) | research/ directory |
| Code patterns | Layer 4 (RagFlow) | code-knowledge dataset |
| Large documents | Layer 4 (RagFlow) | appropriate dataset |

## Rules
- Information can go to multiple layers simultaneously
- Always add [[wiki-links]] when creating Obsidian notes
- Tag everything in Memos — tags are how Memory Agent searches
- RagFlow ingestion happens after Obsidian notes are created
- Never store secrets or credentials in any memory layer
