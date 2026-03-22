---
name: self-evaluation-protocol
version: 2.0.0
trigger: post_task
description: Structured self-evaluation after every task with autoresearch triggers
---

# Self-Evaluation Protocol

## Trigger
After EVERY completed task (trigger: post_task).

## Quality Rubric (1-10)

| Score | Level        | Criteria                                                                 |
|-------|-------------|--------------------------------------------------------------------------|
| 1     | Catastrophic | Task failed completely. Output caused harm or data loss.                |
| 2     | Failed       | Task not completed. Output unusable, requires full redo.                |
| 3     | Very Poor    | Major errors. Significant rework needed, >50% of output wrong.         |
| 4     | Poor         | Multiple issues. Partially completed but key requirements missed.       |
| 5     | Below Average| Completed with notable issues. Works but with bugs or gaps.            |
| 6     | Adequate     | Completed but slowly, with minor issues or suboptimal approach.        |
| 7     | Good         | Completed correctly on first attempt. Clean, meets requirements.       |
| 8     | Very Good    | Completed efficiently. Well-structured, anticipates edge cases.        |
| 9     | Excellent    | Novel approach discovered. Reusable pattern or significant optimization.|
| 10    | Breakthrough | New capability unlocked, revenue generated, or architectural leap.     |

## Evaluation Procedure

After completing any task, execute these steps in order:

1. **Rate** — Assign a quality score 1-10 using the rubric above. Be brutally honest.
2. **Measure** — Record time taken (seconds), tokens consumed, and tools used.
3. **Identify Bottleneck** — Classify the primary bottleneck from:
   - `tool_gap` — needed a tool that doesn't exist
   - `memory_retrieval` — couldn't find information known to exist
   - `prompt_quality` — ambiguous or poor prompt led to wasted work
   - `delegation_failure` — sub-agent failed or returned poor results
   - `context_overflow` — ran out of context window
   - `api_failure` — external API unreliable or down
   - `skill_gap` — agent lacked knowledge for the task
   - `none` — no significant bottleneck
4. **Write Suggestion** — One concrete, actionable improvement for next time.
5. **Log** — Post structured eval to Memos via `self-eval-logger.py`.

## Structured Eval Format (JSON)

```json
{
  "task_type": "coding|research|delegation|memory|discovery|planning|debugging",
  "description": "Brief description of what was done",
  "quality_score": 7,
  "time_seconds": 120,
  "tokens_used": 4500,
  "tools_used": ["tool1", "tool2"],
  "delegated_to": "claude-code|codex|none",
  "bottleneck": "none",
  "suggestion": "Actionable improvement for next time",
  "improvement_type": "skill|tool|prompt|memory|hardware|workflow"
}
```

## Threshold Actions

| Condition                              | Action                                           |
|----------------------------------------|--------------------------------------------------|
| Average score below 7 (last 10 evals)  | Trigger autoresearch: agent researches better approaches |
| Score 1-2 on any task                  | Trigger failure analysis: root cause + remediation plan  |
| Score 10 on any task                   | Log as breakthrough: document what made it exceptional   |
| 3+ evals with same bottleneck          | Create experiment: targeted improvement branch           |

## Autoresearch Integration

When thresholds are triggered:
1. Use `experiment-runner.sh` to create an improvement branch
2. Research better approaches via NotebookLM / Tavily
3. Apply changes to the target (skill, tool, prompt, workflow)
4. Measure with `--measure` flag to compare against baseline
5. Merge if improved, revert if not
6. Log experiment outcome to Memos (#experiment)

## Rules
- Be honest in self-evaluation — inflated scores prevent improvement
- The score IS the metric for autoresearch experiments
- Never skip self-evaluation, even for trivial tasks
- Every eval feeds the self-improvement loop
- Use `metric-analyzer.py` weekly to spot trends
