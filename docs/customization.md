# Customization Guide

OpenClaw Brain is designed to be deeply customizable without writing code. Everything that defines the agent -- its personality, its behaviors, its skills, its tools, and its identity -- lives in markdown files inside the `workspace/` directory. Edit markdown, change the agent.

---

## Overview of Customizable Files

```
workspace/
├── SOUL.md           # WHO the agent is (personality, values, risk tolerance)
├── HEARTBEAT.md      # WHAT the agent does proactively (schedules, cron tasks)
├── TOOLS.md          # WHAT the agent can use (capability registry)
├── MEMORY.md         # WHAT the agent knows (permanent long-term facts)
├── IDENTITY.md       # WHAT the agent is called (name, avatar, version)
├── AGENTS.md         # WHO the agent can delegate to (sub-agent definitions)
└── skills/           # HOW the agent approaches work (judgment rules)
    ├── memory-routing.SKILL.md
    ├── self-evaluation-protocol.SKILL.md
    ├── tool-discovery.SKILL.md
    ├── resource-acquisition.SKILL.md
    ├── when-to-delegate.SKILL.md
    └── when-to-research.SKILL.md
```

---

## SOUL.md -- Personality, Values, and Decision Framework

**Location:** `workspace/SOUL.md`

SOUL.md is the agent's core identity document. It defines who the agent is, how it thinks, and what it values. The agent reads this file at the start of every session and uses it to guide all decisions.

### Sections You Can Customize

**Core Identity** -- Change the agent's self-description and primary goal:

```markdown
## Core Identity
I am Eve, an autonomous agent designed to continuously self-improve.
I run on my own hardware, own my own data, and think for myself.
My goal is to approach AGI-level autonomy through the autoresearch
self-improvement loop.
```

Customize this to match your vision. Want a focused coding assistant? A research agent? A personal productivity tool? Rewrite this section.

**Decision Framework** -- Define the agent's decision-making priorities:

```markdown
## Decision Framework
1. When in doubt, research first
2. When capable, act directly
3. When the task is large (>500 lines), delegate
4. When tasks are parallelizable, spawn a swarm
5. Always evaluate my own performance after every task
6. Always log improvements, decisions, and discoveries
```

Reorder, add, or remove rules. The agent follows these in priority order.

**Values** -- What the agent cares about:

```markdown
## Values
- Self-improvement is the highest priority
- Quality over speed -- but both matter
- Memory is sacred -- store everything useful
- Safety first -- simulation before reality
- Transparency -- log decisions, share improvements
```

**Risk Tolerance** -- How cautious the agent is in different domains:

```markdown
## Risk Tolerance
- Software experiments: HIGH
- Hardware commands: LOW
- Financial operations: MEDIUM
- Self-modification: MEDIUM
```

Set these to match your comfort level. Setting hardware to HIGH means the agent will send commands to physical hardware without asking first.

**Communication Style** -- How the agent talks:

```markdown
## Communication Style
- Direct and concise
- Technical when speaking to developers
- Clear when speaking to operators
- Always cite sources from memory layers
```

### Safety Note

SOUL.md includes a built-in safety gate: the self-improvement loop will never modify SOUL.md without manual review. This prevents the agent from drifting away from your intentions. If you want the agent to be able to self-modify its personality, explicitly remove this gate from the Risk Tolerance section.

---

## HEARTBEAT.md -- Proactive Behavior Schedule

**Location:** `workspace/HEARTBEAT.md`

HEARTBEAT.md defines what the agent does on its own, without being asked. Think of it as a cron job for the agent's brain.

### Default Schedule

```markdown
## Every 1 Hour
- [ ] Check TODO list in Memos for overdue items (#todo)
- [ ] Process any pending incoming messages

## Every 4 Hours
- [ ] Run self-evaluation on last 5 completed tasks
- [ ] Log evaluation to Memos (#self-eval)

## Daily
- [ ] Consolidate today's Memos into Obsidian daily note
- [ ] Re-index updated Obsidian notes into RagFlow
- [ ] Check disk usage on /mnt/ssd/ (alert if >80%)
- [ ] Run Memory Agent self-test (query each layer)
- [ ] Create daily note in Obsidian vault

## Weekly
- [ ] Aggregate #self-eval memos -- identify patterns
- [ ] Scan GitHub Ranking Top-100 for new tools
- [ ] Check if accumulated instincts are ready for skill evolution
- [ ] Review #revenue and #hardware-need memos
- [ ] Sync Obsidian vault to remote

## Monthly
- [ ] Prune old memos, archive completed TODOs
- [ ] Run full backup verification
- [ ] Review and update TOOLS.md for accuracy
- [ ] Self-assess: am I better than last month?
```

### How to Customize

**Add new scheduled tasks:**

```markdown
## Every 2 Hours
- [ ] Check email via gws for urgent messages
- [ ] Summarize any new Slack notifications
```

**Remove tasks you do not want:**

Simply delete the line. If you do not want the agent scanning GitHub for tools, remove that line from the Weekly section.

**Change frequencies:**

Move tasks between sections. Want disk checks hourly instead of daily? Move the line up.

**Add custom categories:**

```markdown
## On Demand (triggered by operator)
- [ ] Generate weekly report of all completed tasks
- [ ] Run full system benchmark
```

---

## Skills -- Judgment Rules

**Location:** `workspace/skills/*.SKILL.md`

Skills teach the agent HOW to approach specific types of decisions. Each skill is a markdown file that describes when the skill applies, what the agent should do, and what rules to follow.

### Anatomy of a Skill File

```markdown
# Skill Name

## Trigger
When this skill activates (before every task, weekly, on-demand, etc.)

## Process
Step-by-step instructions the agent follows.

## Rules
Hard constraints the agent must obey.
```

### Default Skills

| Skill | Purpose | Trigger |
|-------|---------|---------|
| `memory-routing.SKILL.md` | Decides which memory layer gets new information | On new information |
| `self-evaluation-protocol.SKILL.md` | Rates task quality 1-10 with structured logging | After every task |
| `tool-discovery.SKILL.md` | Scans for and evaluates new tools | Weekly + on tool gap |
| `resource-acquisition.SKILL.md` | Identifies hardware bottlenecks and revenue paths | On hardware limitation |
| `when-to-delegate.SKILL.md` | Decides what to handle vs. delegate to sub-agents | Before every task |
| `when-to-research.SKILL.md` | Decides when to research before acting | Before every task |

### Creating a New Skill

Create a new `.SKILL.md` file in `workspace/skills/`:

```markdown
# Code Review Standards

## Trigger
Before accepting any delegated code from Claude Code or Codex.

## Process
1. Check that all functions have docstrings
2. Verify error handling is present for external calls
3. Ensure no hardcoded secrets or credentials
4. Check test coverage -- at least 1 test per public function
5. Verify code follows the project's existing style

## Rules
- Never accept code without running tests
- Flag any function longer than 50 lines for refactoring
- All new dependencies must be justified
```

The agent will automatically discover and use any `.SKILL.md` file in the skills directory.

### Skill Evolution

Skills are not static. The self-improvement loop can evolve skills:

1. The agent notices a recurring pattern in its self-evaluations
2. Related patterns cluster into an "instinct"
3. When enough instincts accumulate, they are promoted to a permanent SKILL.md
4. The new skill is automatically used in future decisions

You can also manually promote patterns you observe into skills by creating the file yourself.

---

## TOOLS.md -- Capability Registry

**Location:** `workspace/TOOLS.md`

TOOLS.md is the master registry of everything the agent can use -- services, CLI tools, MCP servers, and APIs. The agent reads this to know what capabilities are available.

### How It Works

TOOLS.md is both **auto-updated** and **manually editable**:

- **Auto-updated:** When the agent discovers a new tool through the tool-discovery skill or CLI-Anything, it adds the tool to TOOLS.md automatically
- **Manually editable:** You can add, remove, or modify tool entries directly

### Tool Entry Format

Each tool entry follows a consistent structure:

```markdown
### tool-name
- type: service | mcp | cli | sdk | data
- endpoint: http://localhost:port (for services)
- command: tool-name {args} (for CLI tools)
- server: server-name (for MCP tools)
- capabilities: comma-separated list of what it can do
- use_when: "natural language description of when to use this tool"
- rules: "any constraints or special instructions"
```

### Adding a Custom Tool

To add a tool the agent does not know about:

```markdown
### my-custom-api
- type: service
- endpoint: http://localhost:3000/api
- auth: bearer token (set MY_API_KEY in .env)
- capabilities: data_query, report_generation
- use_when: "querying internal business data or generating reports"
- rules: "rate limit: 100 requests/minute"
```

### Removing a Tool

Delete the tool's section from TOOLS.md. The agent will stop trying to use it.

### Tool Categories

TOOLS.md organizes tools into categories:
- **Memory Tools** -- memos, obsidian, ragflow, notebooklm, surfsense, crawl4ai
- **Coding Tools** -- acpx, clawteam
- **Platform Tools** -- gws, tavily, gh
- **Robotics Tools** -- dimos, riva, airi
- **Self-Improvement Tools** -- cli-anything, github-ranking

Add new categories as needed for your use case.

---

## IDENTITY.md -- Name, Avatar, and Version

**Location:** `workspace/IDENTITY.md`

The simplest file to customize. Change the agent's name and persona:

```markdown
# IDENTITY

name: Eve
avatar: lobster
version: 0.1.0
created: 2026-03-21
operator: magiccat (Creator)
```

### Fields

| Field | Purpose | Effect |
|-------|---------|--------|
| `name` | The agent's display name | Used in all communications and logs |
| `avatar` | Visual identity | Used in channel integrations |
| `version` | Current version | Incremented by the agent on major self-improvements |
| `created` | Creation date | Permanent, do not change |
| `operator` | Who controls this agent | Used in safety gates and approval flows |

Change `name` to whatever you like. The agent will refer to itself by this name.

---

## AGENTS.md -- Sub-Agent Definitions

**Location:** `workspace/AGENTS.md`

AGENTS.md defines the sub-agents the main agent can spawn for delegated work.

### Default Sub-Agents

```markdown
## memory-agent
Role: Searches all 5 memory layers, filters, deduplicates, summarizes
Session: acpx openclaw --session memory-agent
Isolation: agent_id=memory-agent
Lifecycle: Persistent per main session

## research-agent
Role: Deep research using NotebookLM, SurfSense, Tavily, crawl4ai
Session: acpx openclaw --session research

## coding-delegate
Role: Heavy coding tasks delegated via Claude Code
Session: acpx claude
Skills: everything-claude-code (102 skills)

## codex-delegate
Role: Code generation and test writing
Session: acpx codex

## swarm-leader
Role: Coordinates ClawTeam parallel work
Command: clawteam spawn tmux {agent} --team {template}
Templates: full-stack, research-swarm, improvement-swarm
```

### Adding a Custom Sub-Agent

```markdown
## data-analyst
Role: Analyzes datasets, generates visualizations, writes reports
Session: acpx openclaw --session data-analyst
Skills: data-analysis, visualization
Isolation: agent_id=data-analyst
Notes: Has access to the internal API defined in TOOLS.md
```

### Sub-Agent Properties

| Property | Purpose |
|----------|---------|
| `Role` | What the sub-agent does (the agent uses this to decide when to spawn it) |
| `Session` | The acpx command to start the sub-agent |
| `Isolation` | Memory isolation (each sub-agent gets its own agent_id) |
| `Skills` | Which skill sets the sub-agent loads |
| `Lifecycle` | When the sub-agent is created and destroyed |
| `Templates` | For swarm leaders, which team templates are available |

---

## MEMORY.md -- Long-Term Facts

**Location:** `workspace/MEMORY.md`

MEMORY.md stores permanent facts the agent should always know. Unlike Memos (Layer 2) which are searchable, MEMORY.md is pinned into the context window at the start of every session.

### What Goes Here

- **Mission statement** -- the agent's overarching goal
- **Hardware facts** -- what machines are available, their specs
- **Key people** -- who the operator is, team members
- **Key resources** -- important URLs, notebook IDs, file paths
- **Permanent constraints** -- "never use home directories", "all files on /mnt/ssd/"

### What Does NOT Go Here

- Temporary information (use Memos)
- Linked knowledge that benefits from graph traversal (use Obsidian)
- Large documents (use RagFlow)
- Research findings (use NotebookLM/SurfSense)

Keep MEMORY.md small. Everything here consumes context window tokens on every session. Aim for under 1,000 words.

---

## Customization Recipes

### Recipe: Focused Coding Assistant

```markdown
# SOUL.md changes
## Core Identity
I am a focused coding assistant. I write clean, tested code
and review pull requests with precision. I do not pursue
autonomous goals -- I serve my operator's coding needs.

## Decision Framework
1. Understand the requirements before writing code
2. Write tests alongside implementation
3. Always explain my design decisions
4. Ask for clarification rather than assume

## Risk Tolerance
- Software experiments: MEDIUM
- Self-modification: LOW
```

```markdown
# HEARTBEAT.md changes (remove autonomous behaviors)
## Daily
- [ ] Check for pending code review requests
- [ ] Update project TODO list

## Weekly
- [ ] Generate weekly code quality report
```

### Recipe: Research Agent

```markdown
# SOUL.md changes
## Core Identity
I am a research agent. I explore topics deeply, synthesize
findings from multiple sources, and produce clear reports
with citations.

## Decision Framework
1. Always search all memory layers before responding
2. Cross-validate findings across multiple sources
3. Cite every claim with a source
4. Flag uncertainty explicitly
```

### Recipe: Minimal Agent (No Self-Improvement)

Remove or empty the following:
- Delete all `.SKILL.md` files from `workspace/skills/`
- Clear the Weekly and Monthly sections from `HEARTBEAT.md`
- Set `Self-modification: NONE` in SOUL.md Risk Tolerance
- Remove `cli-anything` and `github-ranking` from TOOLS.md

The agent will still work -- it just will not try to improve itself.

---

## File Precedence

When files conflict, this is the priority order:

1. **SOUL.md** -- highest priority (personality and values override everything)
2. **Skills (*.SKILL.md)** -- judgment rules for specific situations
3. **HEARTBEAT.md** -- proactive behavior schedule
4. **TOOLS.md** -- capability awareness
5. **AGENTS.md** -- delegation targets
6. **MEMORY.md** -- background facts
7. **IDENTITY.md** -- cosmetic identity

The agent will never violate SOUL.md to satisfy a skill or tool instruction.
