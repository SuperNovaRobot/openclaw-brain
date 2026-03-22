# Self-Improvement Loop

The self-improvement loop is the heart of OpenClaw Brain. Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) concept, it enables the agent to continuously evaluate its own performance and make itself better. This document explains every component of the loop in detail.

---

## The Core Concept

Most AI agents execute tasks. OpenClaw Brain executes tasks AND evaluates how it executed them, researches better approaches, applies improvements, and evolves -- permanently. The agent that completes task #100 is measurably better than the agent that completed task #1.

The loop applies to everything:
- **Code quality** -- writing better code, choosing better patterns
- **Memory retrieval** -- finding the right information faster
- **Tool selection** -- using the right tool for the job
- **Delegation** -- knowing when to delegate vs. handle directly
- **Prompt quality** -- writing better prompts for sub-agents
- **Context management** -- using the context window more efficiently
- **Hardware utilization** -- identifying and resolving bottlenecks

---

## The 5-Step Loop

```
STEP 1: COMPLETE ──> STEP 2: EVALUATE ──> STEP 3: RESEARCH
                                                    |
STEP 5: EVOLVE  <── STEP 4: APPLY    <─────────────┘
    |
    └──> Back to STEP 1 (agent is now better)
```

### Step 1: Complete a Task

The agent does work -- coding, research, tool use, delegation, or any combination. Every task, no matter how small, feeds into the loop.

### Step 2: Self-Evaluate

After every task, the `self-evaluation-protocol.SKILL.md` triggers automatically.

The agent:

1. **Rates quality** using the calibrated rubric (see below)
2. **Measures performance:** time taken, tokens consumed, tools invoked
3. **Identifies bottlenecks:** what was slow? what failed? what was missing?
4. **Compares alternatives:** was delegation faster? was memory recall good?
5. **Logs everything** to Memos with the `#self-eval` tag as structured data:

```
task_type: coding
quality_score: 7
time_seconds: 340
tools_used: [acpx-claude, ragflow, obsidian-cli]
bottleneck: memory_retrieval
suggestion: RagFlow returned irrelevant chunks for this query type
improvement_type: memory
```

### Step 3: Research Improvements

Based on the bottleneck identified in Step 2, the agent researches a better approach:

| Bottleneck | Research Action |
|------------|----------------|
| `tool_gap` | Scan GitHub Ranking, search Tavily, query NotebookLM for better tools |
| `memory_retrieval` | Analyze RagFlow chunking strategy, crawl missing docs, re-index |
| `prompt_quality` | Review SKILL.md files, A/B test prompt variations |
| `delegation_failure` | Analyze acpx logs, adjust routing thresholds in when-to-delegate |
| `context_overflow` | Review pinned files, optimize `/compact` behavior |
| `slow_inference` | Research quantization methods, check vLLM configuration |

Research results are stored in Obsidian (`improvements/` directory) with `[[wiki-links]]` to related notes, and ingested into RagFlow for future retrieval.

### Step 4: Apply Improvements

The agent applies improvements to its own "editable files" -- the markdown configuration that defines its behavior:

| Target File | What Changes | Metric |
|-------------|-------------|--------|
| `*.SKILL.md` files | Better judgment rules, refined processes | Task quality score |
| `TOOLS.md` | New tool entries, updated capabilities | Tool discovery rate |
| `SOUL.md` | Adjusted values, refined decision framework | User satisfaction (manual gate) |
| `HEARTBEAT.md` | New scheduled tasks, adjusted frequencies | Proactive task value |
| Behavior MCPs | Better routing logic, refined scoring | Routing accuracy |
| Memory routing | Adjusted layer decisions, better tagging | Retrieval relevance |

**Process for applying an improvement:**

1. **Branch:** `git checkout -b improvement/YYYY-MM-DD-description`
2. **Edit:** Modify the target file with the improvement
3. **Test:** Run N tasks with the change active
4. **Measure:** Compare metrics against baseline
5. **If improved:** Merge to main, log success in Obsidian
6. **If not improved:** Revert the branch, log failure in Memos
7. **Either way:** Log the experiment for future reference

### Step 5: Evolve (Instincts Become Skills)

The most powerful part of the loop. Patterns extracted from successful sessions become permanent capabilities.

```
Session data (ECC hooks)
    -> Extract successful patterns ("instincts")
    -> Cluster related instincts
    -> When cluster is large enough, promote to SKILL.md
    -> Deploy to workspace/skills/
    -> Agent now has a permanent learned capability
```

This is the `everything-claude-code` continuous learning system applied to OpenClaw Brain. The agent does not just get better at one task -- it builds reusable skills that improve entire categories of work.

---

## Quality Rubric

The quality rubric ensures consistent, honest self-evaluation. Inflated scores prevent improvement, so the rubric is calibrated with specific criteria:

| Score | Label | Criteria | Example |
|-------|-------|----------|---------|
| 1 | Failed | Task not completed. Errors not resolved. Output unusable. | Agent crashed mid-task, no output produced. |
| 2 | Failed | Task attempted but fundamentally wrong. Major misunderstanding of requirements. | Built the wrong feature entirely. |
| 3 | Poor | Task completed but output has significant issues requiring rework. | Code works but has multiple bugs found in review. |
| 4 | Poor | Task completed but with important omissions or quality issues. | Documentation written but missing key sections. |
| 5 | Adequate | Task completed correctly but took significantly longer than expected. | Simple task took 30 minutes instead of 5. |
| 6 | Adequate | Task completed with minor issues requiring small fixes. | Code works but edge case handling is missing. |
| 7 | Good | Task completed correctly on first attempt. Clean, efficient execution. | Feature implemented, tested, documented in expected time. |
| 8 | Good | Task completed with above-average quality. Good tool selection and delegation. | Used the optimal tool combination, clean code, good tests. |
| 9 | Excellent | Novel approach discovered. Reusable pattern identified. Faster than baseline. | Found a new library that speeds up inference 2x. |
| 10 | Breakthrough | New capability unlocked, revenue generated, or architecture permanently improved. | Discovered CLI-Anything can auto-generate MCP wrappers, added 5 new tools. |

### Score Trends

The agent tracks score trends over time:

- **Improving trend** (rolling average increasing): the self-improvement loop is working
- **Flat trend** (rolling average stable): the agent has plateaued; research more aggressive improvements
- **Declining trend** (rolling average decreasing): something is degrading; investigate immediately
- **Sustained average below 7:** triggers aggressive self-improvement (more frequent research, broader tool scanning)

---

## Instinct Extraction

Instincts are patterns extracted from successful sessions. They are the raw material for skill evolution.

### How Instincts Are Extracted

The `everything-claude-code` system uses ECC (Extended Claude Code) hooks to observe the agent's behavior:

1. **Session monitoring:** Every tool call, delegation, memory search, and decision is logged.
2. **Pattern detection:** After N sessions, the system scans logs for recurring successful patterns.
3. **Instinct formulation:** Each pattern is formulated as a conditional rule:
   ```
   WHEN [condition] THEN [action] BECAUSE [evidence from N sessions]
   ```

### Example Instincts

```
WHEN task involves Docker configuration
THEN search RagFlow ops-reference dataset first
BECAUSE 8/10 Docker tasks scored higher when preceded by ops-reference search

WHEN delegating to Claude Code
THEN include the full file path and 50 lines of surrounding context
BECAUSE delegation quality score averaged 8.2 with context vs 5.7 without

WHEN self-eval score is below 5
THEN research the specific bottleneck before proceeding to next task
BECAUSE immediate research after failure prevents repeated poor scores
```

### From Instincts to Skills

When enough related instincts accumulate (typically 5-10 around a common theme), they are promoted to a permanent SKILL.md file:

1. **Cluster:** Group related instincts by theme (e.g., "Docker operations", "delegation quality")
2. **Synthesize:** Combine the cluster into a coherent process with rules
3. **Write:** Create a new `.SKILL.md` file in `workspace/skills/`
4. **Deploy:** The agent automatically discovers and uses the new skill
5. **Track:** The skill's effectiveness is measured through future self-evaluations

---

## Resource Acquisition Loop

The self-improvement loop does not stop at software. If the agent identifies a hardware limitation, it can plan and execute strategies to acquire better resources.

### The Cycle

```
IDENTIFY BOTTLENECK
  "I cannot run 122B model because I only have 1 GPU"
    |
    v
RESEARCH SOLUTIONS
  "8x RTX 3090 rig would solve this. Cost: ~$6,000"
  "Alternatively, cloud GPU at $12/hr for A100 cluster"
    |
    v
GENERATE REVENUE
  The agent uses its capabilities to earn:
  - Coding services via platform integrations
  - Technical documentation and reports
  - Automation workflow development
  - Research reports using NotebookLM
  - 3D part design (leap71/PicoGK + bambu-cli)
    |
    v
ACQUIRE HARDWARE
  Agent presents purchase recommendation to operator:
  "Recommend purchasing 2x RTX 3090 for $1,400.
   Expected improvement: unlock 70B models, 3x context window.
   ROI: enables higher-quality coding services."
  WAIT for operator approval (mandatory safety gate)
    |
    v
INTEGRATE
  New hardware -> update docker-compose -> update TOOLS.md
  -> test capabilities -> log improvement to Obsidian
    |
    v
REPEAT (agent is now more capable -> more revenue -> more hardware)
```

### Safety Gates

- ALL purchases require operator approval -- no autonomous spending
- Revenue tracking is fully transparent in Memos (`#revenue` tag)
- Budget limits are configurable in HEARTBEAT.md
- Agent presents ROI analysis before any purchase request

---

## Experiment Branching

Every self-improvement attempt is an experiment. Experiments are tracked in git branches.

### Branch Naming Convention

```
improvement/YYYY-MM-DD-description
```

Examples:
```
improvement/2026-03-21-better-ragflow-chunking
improvement/2026-03-22-refined-delegation-thresholds
improvement/2026-03-25-new-tool-crawl4ai-structured-extract
```

### Experiment Lifecycle

```
1. Create branch
   git checkout -b improvement/2026-03-21-better-ragflow-chunking

2. Make the change
   Edit memory-routing.SKILL.md to adjust chunking recommendations

3. Run baseline tasks
   Complete 5-10 representative tasks, record self-eval scores

4. Compare to baseline
   Average score with change vs. average score without

5. Decision
   If improved:
     git checkout main
     git merge improvement/2026-03-21-better-ragflow-chunking
     Log success in Obsidian (improvements/ directory)

   If not improved:
     git branch -d improvement/2026-03-21-better-ragflow-chunking
     Log failure in Memos (#improvement-failed)
     Note: failure is valuable data -- why did it not work?

6. Archive
   All experiments (success or failure) are logged in Memos
   with the #improvement tag for future reference
```

### Preventing Self-Damage

The experiment branching system ensures the agent can never permanently damage itself:

- All changes are on a branch, never directly on main
- If a change degrades performance, it is reverted
- SOUL.md changes require manual operator review (safety gate)
- The agent can always return to its last known good state

---

## Tool Discovery

The agent actively scans for new tools to add to its capabilities.

### GitHub Ranking Scan

**Frequency:** Weekly (via HEARTBEAT.md)
**Source:** `EvanLi/Github-Ranking/Top-100-stars.md`

Process:

1. **Scan:** Download the latest Top-100 list across all languages
2. **Compare:** Check each repo against current entries in TOOLS.md
3. **Flag:** Identify repos not in the current registry
4. **Evaluate:** For each new repo:
   - Read README via crawl4ai
   - Score relevance to the agent's capabilities (1-10)
   - Consider: does this improve an existing capability?

### CLI-Anything Integration

When a relevant tool is discovered, `CLI-Anything` auto-generates an MCP wrapper:

```bash
# Agent discovers a new tool
cli-anything generate new-tool-name

# CLI-Anything outputs:
# - MCP server wrapper
# - SKILL.md for the tool
# - Updated TOOLS.md entry
```

### Discovery Decision Matrix

| Relevance Score | Action |
|----------------|--------|
| 8-10 | Generate MCP wrapper, test, add to TOOLS.md, create SKILL.md |
| 5-7 | Bookmark for later review, log to Memos (#potential-tool) |
| 1-4 | Skip, no action needed |

### What the Agent Looks For

- Better memory/search tools (replace or augment RagFlow)
- Better inference serving (replace or augment vLLM)
- New automation capabilities (expand what the agent can do)
- Better development tools (improve code quality and speed)
- New research tools (expand Layer 5 capabilities)
- Robotics tools (expand physical capabilities in Phase 6+)

---

## Measuring Improvement

The agent tracks multiple metrics to know if it is getting better:

### Primary Metrics

| Metric | Source | Target |
|--------|--------|--------|
| Average quality score | #self-eval memos | > 7.0 sustained |
| Score trend | Weekly aggregation | Positive slope |
| Task completion time | #self-eval memos | Decreasing |
| Memory retrieval relevance | Self-eval bottleneck field | < 10% "memory_retrieval" bottlenecks |
| Delegation success rate | #delegation memos | > 85% |
| Tool discovery rate | #discovery memos | 1+ useful tools/month |

### Secondary Metrics

| Metric | Source | Purpose |
|--------|--------|---------|
| Context window usage | Agent self-monitoring | Efficient use of 1M tokens |
| Instincts extracted | ECC hooks | Growing pattern library |
| Skills evolved | workspace/skills/ count | Expanding permanent capabilities |
| Revenue generated | #revenue memos | Resource acquisition capability |
| Experiments run | improvement/ branches | Active self-improvement effort |
| Experiments succeeded | Merged branches | Improvement effectiveness |

### Monthly Self-Assessment

Every month, the agent performs a comprehensive self-assessment:

1. Am I better than last month? (compare average scores)
2. What improved the most? (identify winning experiments)
3. What is still the biggest bottleneck? (plan next improvements)
4. Are there new tools or approaches I should research?
5. Does my hardware need an upgrade? (resource acquisition check)

Results are stored in Obsidian (`improvements/monthly-review-YYYY-MM.md`) with links to relevant experiments, tools, and skills.

---

## The Virtuous Cycle

The self-improvement loop creates a compounding effect:

```
Better skills
  -> Higher quality work
    -> More accurate self-evaluation
      -> Better targeted research
        -> More effective improvements
          -> Even better skills
            -> Even higher quality work
              -> ...
```

Every component improves every other component. Better memory retrieval makes research faster. Better tools make coding more efficient. Better delegation makes parallelism more effective. And all of it makes the self-evaluation more accurate, which makes the next improvement cycle even more targeted.

This is the autoresearch concept in action: the agent improves the system that improves itself.
