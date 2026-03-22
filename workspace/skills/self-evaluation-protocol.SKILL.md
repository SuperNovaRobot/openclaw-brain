# Self-Evaluation Protocol

## Trigger
After EVERY completed task.

## Process
1. Rate quality using the rubric:
   - 1-2: Failed — task not completed, output unusable
   - 3-4: Poor — significant rework needed
   - 5-6: Adequate — completed but slowly or with minor issues
   - 7-8: Good — completed correctly first attempt
   - 9: Excellent — novel approach, reusable pattern discovered
   - 10: Breakthrough — new capability, revenue, or architectural improvement

2. Log structured data to Memos (#self-eval):
   - task_type: coding/research/delegation/memory/discovery
   - quality_score: 1-10
   - time_seconds: actual time taken
   - tools_used: [list of tools invoked]
   - bottleneck: tool_gap/memory_retrieval/prompt_quality/delegation_failure/none
   - suggestion: what would make this better next time
   - improvement_type: skill/tool/prompt/memory/hardware

3. If quality_score < 7:
   - Identify root cause
   - Research improvements (Step 3 of self-improvement loop)
   - Create improvement experiment branch

4. Weekly aggregation:
   - Calculate average quality score
   - Identify most common bottleneck
   - Track score trend (improving? degrading?)
   - If average < 7 sustained: trigger aggressive self-improvement

## Rules
- Be honest in self-evaluation — inflated scores prevent improvement
- The score IS the metric for autoresearch experiments
- Never skip self-evaluation, even for trivial tasks
