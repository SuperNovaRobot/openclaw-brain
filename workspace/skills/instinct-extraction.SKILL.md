---
name: instinct-extraction
version: 1.0.0
trigger: session_end
tags: [autoresearch, learning, core]
---

# Instinct Extraction

## Purpose
Extract reusable patterns ("instincts") from completed sessions and evolve them into permanent skills.

## When to Trigger
- At the end of every session (via hook)
- On demand with /evolve command
- Weekly during HEARTBEAT aggregation

## Process

### 1. Record (During Session)
As the agent works, it naturally generates patterns:
- Tool sequences that worked well
- Decisions that led to good outcomes (score >= 8)
- Error recovery approaches that succeeded
- Memory retrieval strategies that found relevant context

### 2. Extract (Session End)
Analyze the session log and extract "When X, do Y" rules:
```
INSTINCT FORMAT:
  trigger: "When [condition]"
  action: "Do [action]"
  evidence: "Worked in session [id], task [desc], score [N]"
  confidence: float (0.0 - 1.0, based on repetition count)
```

### 3. Cluster (Periodic)
Group related instincts by domain:
- memory_instincts: patterns about when/how to search memory
- delegation_instincts: patterns about routing to sub-agents
- tool_instincts: patterns about tool selection and sequencing
- research_instincts: patterns about research strategy
- quality_instincts: patterns about code/output quality

### 4. Evolve (Threshold Reached)
When a cluster has 5+ instincts with confidence > 0.7:
1. Synthesize instincts into a coherent SKILL.md
2. Save to workspace/skills/evolved/
3. Log evolution to Obsidian improvements/ with [[wiki-links]]
4. Log to Memos #instinct #evolved

## Storage
- Raw instincts: Memos (#instinct tag)
- Evolved skills: workspace/skills/evolved/*.SKILL.md
- Evolution log: Obsidian improvements/instinct-evolution-{date}.md

## Integration

### With Self-Evaluation
After each self-eval (score >= 8), the agent should reflect on what worked and call
`instinct-extractor.py` with the session data to capture the pattern.

### With HEARTBEAT
Weekly HEARTBEAT runs `evolve-instincts.sh` to check if any instinct cluster
is ready for skill evolution.

### With Experiment Runner
If an evolved skill underperforms, use `experiment-runner.sh` to A/B test
the old instinct set against the new skill.
