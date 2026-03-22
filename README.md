<div align="center">

# 🧠 OpenClaw Brain

**Production-grade cognitive architecture for autonomous AI agents.**

5-layer memory · Lossless context · Multi-agent search · Self-improvement loop · Robotics-ready

[![Release](https://img.shields.io/github/v/release/SuperNovaRobot/openclaw-brain?style=flat-square&color=blue)](https://github.com/SuperNovaRobot/openclaw-brain/releases)
[![License](https://img.shields.io/badge/license-Apache%202.0-green?style=flat-square)](LICENSE)
[![Stars](https://img.shields.io/github/stars/SuperNovaRobot/openclaw-brain?style=flat-square)](https://github.com/SuperNovaRobot/openclaw-brain)
[![OpenClaw](https://img.shields.io/badge/OpenClaw-2026.3-orange?style=flat-square)](https://openclaw.ai)
[![Postgres](https://img.shields.io/badge/Postgres-pgvector-blue?style=flat-square)](https://github.com/pgvector/pgvector)
[![RagFlow](https://img.shields.io/badge/RagFlow-80k%20⭐-purple?style=flat-square)](https://github.com/infiniflow/ragflow)

[Quick Start](#quick-start) · [Architecture](#architecture) · [Component Registry](#component-registry) · [Agent Communication](#agent-communication) · [Memory System](#memory-system) · [Self-Improvement](#self-improvement) · [Contributing](#contributing)

</div>

---

Most agent frameworks are fixed pipelines — same prompts, same chains, every single time. OpenClaw Brain is a **cognitive architecture**: a 5-layer memory stack, a dedicated Memory Agent, a lossless context engine, and a self-improvement loop built on [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) concept. The agent doesn't just follow instructions — it evaluates its own performance, researches better approaches, and rewrites its own tools, skills, and prompts. It gets better at getting better.

Designed for real hardware. Runs on a Jetson Orin, scales to 8x GPU rigs, deploys to cloud. No toy demos — production Postgres, Elasticsearch, RagFlow, and Obsidian knowledge graphs. Built for agents that need to remember everything, learn from everything, and eventually control a physical body.

27 GitHub repos wired together. 62 Claude Code skills. 65 rules. 28 sub-agents. 5 memory layers. One coherent brain.

---

## Architecture

```
Conversation (OpenClaw / Claude Code / Codex / Any Agent)
        │
        ▼
┌─────────────────────────────────────────────┐
│            OpenClaw Brain v2.0              │
│        (cognitive architecture)             │
├─────────────────────────────────────────────┤
│                                             │
│  Capture → Quality Score → World Model      │
│  Recall  ← Orchestrator (6 strategies)     │
│  Memory Agent → 5-layer curated search     │
│  Lossless Claw → DAG summaries, drill-back │
│  Autoresearch → self-improving loop        │
│                                             │
└─────────┬───────┬──────┬──────┬────────────┘
          │       │      │      │
    ┌─────▼──┐ ┌──▼───┐ ┌▼────┐ ┌▼──────────┐
    │ Memos  │ │Obsid-│ │Rag- │ │NotebookLM │
    │  (L2)  │ │ian   │ │Flow │ │  (L5)     │
    │ tagged │ │(L3)  │ │(L4) │ │ Gemini    │
    │ notes  │ │wiki- │ │vec+ │ │ research  │
    │        │ │links │ │text │ │           │
    └────────┘ └──────┘ └─────┘ └───────────┘
          │       │       │          │
          └───────┴───────┴──────────┘
                      │
    ┌─────────────────┴─────────────────┐
    │       PostgreSQL + pgvector        │
    │  (world model, facts, beliefs,     │
    │   decay engine, bi-temporal)       │
    └─────────────────┬─────────────────┘
                      │
    ┌─────────────────┴─────────────────┐
    │        Lossless Claw (LCM)         │
    │  (DAG summaries, drill-back,       │
    │   fresh tail, nothing ever lost)   │
    └───────────────────────────────────┘
```

Every conversation flows through the Brain. Incoming messages are scored for quality, entities are extracted into a world model, and the Pre-Prompt Orchestrator auto-injects relevant context from all 5 memory layers before the agent even sees the message. Nothing is ever deleted — the Lossless Claw compacts old context into DAG summaries that can be drilled back into at any time.

---

## Highlights

- 🧠 **5-Layer Memory Stack** — Context → Memos → Obsidian → RagFlow → NotebookLM. Each layer serves a different purpose, from fast working memory to deep research.
- 🔒 **Lossless Context** — The Lossless Claw DAG ensures nothing is ever deleted. Old context is compacted into summaries with drill-back links. Zero information loss, infinite history.
- 🔍 **Memory Agent** — A dedicated sub-agent that searches all 5 layers, deduplicates results, and returns curated summaries. The main agent never wastes context on raw memory queries.
- 🎯 **Pre-Prompt Orchestrator** — 6 recall strategies auto-inject the right context before every message. Recency, semantic similarity, entity-based, emotional salience, temporal, and random exploration.
- 🌍 **World Model** — Entities, beliefs, episodes, and contradictions stored in Postgres with bi-temporal timestamps. The agent builds and maintains a structured model of its world.
- 📊 **Quality Scoring** — 9-dimensional scoring (novelty, relevance, actionability, emotional weight, contradiction, source reliability, specificity, temporal sensitivity, cross-reference potential) keeps signal and rejects noise.
- 📉 **Activation Decay** — Hebbian-inspired decay engine. Memories fade unless reinforced by access or relevance. High-quality memories decay slower. The brain stays sharp.
- 🔄 **Autoresearch Loop** — Built on Karpathy's concept: act → evaluate → research → improve → repeat. The agent improves its own prompts, tools, skills, and workflows. Continuously.
- 🤖 **Robotics-Ready** — OAK-D Pro stereo vision, Dynamixel arm control, MuJoCo simulation, Riva voice pipeline, AIRI avatar. Designed for a physical body from day one.
- 🛠️ **Production Infrastructure** — Postgres + pgvector, Elasticsearch, RagFlow (80K+ stars), Redis, Docker Compose. Battle-tested components, not toy abstractions.

---

## Component Registry

Every tool, service, and framework wired into the brain. 27 repos, one architecture.

### Core Agent

| Repo | Role | Interface |
|------|------|-----------|
| [openclaw/openclaw](https://github.com/openclaw/openclaw) | Agent runtime, gateway, channels | CLI + WebSocket |
| [openclaw/acpx](https://github.com/openclaw/acpx) | Agent-to-agent communication | ACP protocol |
| [Martian-Engineering/lossless-claw](https://github.com/Martian-Engineering/lossless-claw) | Lossless context management | ContextEngine plugin |

### Memory Stack

| Repo | Layer | Role |
|------|-------|------|
| [usememos/memos](https://github.com/usememos/memos) | L2 | Fast tagged notes, TODOs, self-eval logs |
| [jwhonce/obsidian-cli](https://github.com/jwhonce/obsidian-cli) | L3 | Headless vault access + MCP |
| [Vinzent03/obsidian-git](https://github.com/Vinzent03/obsidian-git) | L3 | Vault version control |
| [infiniflow/ragflow](https://github.com/infiniflow/ragflow) | L4 | Production RAG (80K+ stars) |
| [MODSetter/SurfSense](https://github.com/MODSetter/SurfSense) | L5 | Self-hosted NotebookLM alternative |
| [MemTensor/MemOS-Cloud-OpenClaw-Plugin](https://github.com/MemTensor/MemOS-Cloud-OpenClaw-Plugin) | Bridge | Memory lifecycle hooks |

### Research & Discovery

| Repo | Role |
|------|------|
| NotebookLM (Google) | Gemini-powered cross-source research |
| [unclecode/crawl4ai](https://github.com/unclecode/crawl4ai) | Web → markdown ingestion |
| [EvanLi/Github-Ranking](https://github.com/EvanLi/Github-Ranking) | Weekly tool discovery scanning |
| [trimstray/the-book-of-secret-knowledge](https://github.com/trimstray/the-book-of-secret-knowledge) | Ops reference knowledge |

### Coding & Workflows

| Repo | Role |
|------|------|
| [obra/superpowers](https://github.com/obra/superpowers) | Brainstorm → plan → execute workflow |
| [bmad-code-org/BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) | Complex multi-agent architecture |
| [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 62 skills, 65 rules, 28 agents for Claude Code |
| [alirezarezvani/claude-skills](https://github.com/alirezarezvani/claude-skills) | 800+ cross-domain agent skills |
| [VoltAgent/awesome-openclaw-skills](https://github.com/VoltAgent/awesome-openclaw-skills) | 5,400+ skill registry |

### Agent Swarms

| Repo | Role |
|------|------|
| [HKUDS/ClawTeam](https://github.com/HKUDS/ClawTeam) | Parallel agent swarm orchestration |
| [tisu19021997/langclaw](https://github.com/tisu19021997/langclaw) | LangChain ↔ OpenClaw bridge |
| [langchain-ai/langchain](https://github.com/langchain-ai/langchain) | LLM orchestration framework |

### Platform & CLI

| Repo | Role |
|------|------|
| [googleworkspace/cli](https://github.com/googleworkspace/cli) | Gmail, Calendar, Drive access |
| [HKUDS/CLI-Anything](https://github.com/HKUDS/CLI-Anything) | Auto-generate CLI for any software |

### Robotics

| Repo | Role |
|------|------|
| [dimensionalOS/dimos](https://github.com/dimensionalOS/dimos) | Robot OS, simulation, blueprints |
| [nvidia-riva/python-clients](https://github.com/nvidia-riva/python-clients) | Voice ASR/TTS |
| [moeru-ai/airi](https://github.com/moeru-ai/airi) | Avatar display / robot face |
| [leap71](https://github.com/leap71) | Computational engineering / CAD |

### Self-Improvement

| Repo | Role |
|------|------|
| [karpathy/autoresearch](https://github.com/karpathy/autoresearch) | THE core concept — autonomous self-improvement |
| [NVIDIA/NemoClaw](https://github.com/NVIDIA/NemoClaw) | Reference architecture (optional) |

---

## Agent Communication

Eve doesn't work alone. She delegates heavy tasks and coordinates agent swarms via the Agent Client Protocol (acpx).

### Delegation Decision Tree

```
Eve receives a task
    │
    ├─ < 100 lines, in capability → handle directly
    │
    ├─ > 500 lines, heavy coding → delegate to Claude Code
    │   acpx claude -s backend "Build the REST API"
    │   Claude Code has: Superpowers (14 skills), ECC (62 skills, 65 rules, 28 agents)
    │
    ├─ Code generation / tests → delegate to Codex
    │   acpx codex "Write tests for the auth module"
    │
    ├─ Multiple independent tasks → spawn ClawTeam swarm
    │   clawteam spawn tmux claude --team full-stack \
    │     --tasks "backend:REST API" "frontend:React UI" "tester:integration tests"
    │
    └─ Memory search → spawn Memory Agent
        acpx openclaw --session memory-agent "search all layers for: {query}"
        Searches 5 layers, filters, deduplicates, returns curated summary
```

Eve decides based on task complexity and scope. Simple tasks she handles inline. Medium tasks go to Claude Code with Superpowers. Complex multi-system builds go through the full BMAD pipeline with agent swarms. Memory queries always go to the dedicated Memory Agent so the main agent never wastes context on raw retrieval.

### Session Management

```bash
acpx claude -s api-v2 "continue the API work"     # persistent named session
acpx claude -s frontend "fix the React component"  # parallel session
acpx sessions list                                  # see active sessions
```

Sessions persist across restarts. Each session maintains its own context, memory references, and working state. Multiple sessions run in parallel — one agent works on the backend while another works on the frontend. acpx handles routing, status tracking, and result aggregation.

### Superpowers Workflow

For complex projects that need planning before execution:

```
1. superpowers:brainstorming    → design the solution
2. superpowers:writing-plans    → create implementation plan
3. superpowers:subagent-driven-development → execute with fresh agents per task
4. superpowers:test-driven-development    → TDD for each component
5. superpowers:systematic-debugging       → when things break
```

Each step produces artifacts that feed the next. Brainstorming creates a design spec. Writing-plans breaks the spec into ordered tasks. Subagent-driven-development spawns a fresh agent for each task — no context contamination between tasks, maximum token budget per task. The agent self-selects which workflow a task needs.

### BMAD Method

For multi-agent architecture builds where the system design itself is complex:

```
Analyst   → Project Brief (scope, stakeholders, constraints)
PM        → Product Requirements Document (features, acceptance criteria)
Architect → Technical Architecture (components, interfaces, data flow)
Developer → Implementation (code, tests, deployment)
```

Each role is a separate agent pass with a distinct persona and responsibilities. The Analyst doesn't write code. The Developer doesn't question product decisions. This separation prevents architectural drift and ensures each concern gets full attention.

Eve decides which workflow to use based on task complexity. Simple tasks: handle directly. Medium: delegate to Claude Code with Superpowers. Complex multi-system builds: BMAD pipeline with agent swarms.

### ECC Ecosystem

[Everything Claude Code](https://github.com/affaan-m/everything-claude-code) is wired into every Claude Code delegate:

- **62 skills** — specialized capabilities from git operations to full-stack development
- **65 rules** — behavioral guardrails that prevent common agent failure modes
- **28 agents** — pre-configured personas for different task types (backend, frontend, testing, devops, security, etc.)

When Eve delegates to Claude Code, the delegate gets the full ECC stack. This means a coding delegate has access to more accumulated agent engineering knowledge than most entire teams.

---

## Why Not SQLite?

Every other agent memory plugin stores memories in SQLite and calls it a day. Here that doesn't scale:

| Feature | SQLite Plugins | OpenClaw Brain |
|---------|---------------|----------------|
| Multi-agent writes | Single-writer lock | Postgres MVCC — concurrent agents, zero contention |
| Vector search | FTS5 only | pgvector + Elasticsearch hybrid |
| Semantic search | Basic BM25 | RagFlow hybrid (BM25 + vector + rerank) |
| Knowledge graph | Flat key-value | Obsidian wiki-links + Postgres world model |
| Research brain | None | NotebookLM (Gemini) + SurfSense fallback |
| Memory Agent | Auto-inject only | Dedicated agent, 5-layer curated search |
| Lossless context | Most delete old memories | Lossless Claw DAG + drill-back + RagFlow bridge |
| Quality scoring | Store everything | 9-dimensional scoring, noise rejection |
| Decay engine | No decay model | Hebbian activation decay, reinforcement on access |
| Scale | Single machine | Multi-machine (brain + GPU rig + cloud) |

---

## Memory System

The 5-layer memory stack is the core of OpenClaw Brain. Each layer has a specific purpose and access pattern.

### Layer 1 — Context (Working Memory)

The agent's active context window. Managed by the Lossless Claw to maximize useful information per token. When context fills up, older content is compacted into DAG summaries — never deleted, always drill-back accessible.

### Layer 2 — Memos (Fast Structured Notes)

Tagged, searchable notes stored in [Memos](https://github.com/usememos/memos). Quick capture of decisions, action items, task outcomes, and learnings. The agent's scratchpad with structure. Accessed via API with tag-based filtering.

### Layer 3 — Obsidian (Knowledge Graph)

A linked knowledge graph using `[[wiki-links]]` and backlinks. Not flat files — a web of connected concepts, tools, decisions, and research findings that the agent traverses to discover relationships it didn't explicitly create. Daily notes provide chronological context. The graph grows smarter over time.

### Layer 4 — RagFlow (Deep Semantic Search)

[RagFlow](https://github.com/infiniflow/ragflow) provides hybrid retrieval: BM25 keyword search + vector similarity + cross-encoder reranking. Ingests documents, conversation history (via LCM bridge), and crawled documentation. When the agent needs to find something it saw weeks ago, RagFlow finds it.

### Layer 5 — NotebookLM (Research Brain)

The agent's direct line to Google Gemini for cutting-edge research. Ingests sources and gets Gemini-powered cross-source analysis. Discovers connections the local model might miss. [SurfSense](https://github.com/MODSetter/SurfSense) provides a self-hosted fallback. Research findings flow back into Layers 2-4.

### Memory Hooks (Automatic)

The memory system is not passive storage — it actively participates in every conversation via lifecycle hooks:

| Hook | Event | What It Does |
|------|-------|-------------|
| `memory-recall` | Session start | Load TODOs, mission, self-eval trends from Memos |
| `memory-enrich` | Message received | Search Memos for relevant context, inject into conversation |
| `memory-persist` | Message sent | Persist decisions/completions/learnings, trigger self-eval |
| `memory-flush` | Before compaction | Save all key facts before context compression |
| `lcm-ragflow-sync` | Message sent | Sync LCM summaries to RagFlow for semantic search |

Every incoming message triggers `memory-enrich` — the agent never starts a response without checking what it already knows about the topic. Every outgoing message triggers `memory-persist` — decisions, completions, and learnings are captured automatically, not on-demand. The agent doesn't have to remember to remember.

### LCM → RagFlow Bridge

This is the architectural innovation that ties the memory system together:

```
LCM stores DAG summaries (lossless)
    │
    ▼
Sync bridge (hook + cron)
    │
    ▼
RagFlow indexes summaries (semantic search)
    │
    ▼
Memory Agent finds by MEANING → drills back via LCM for DETAIL
```

The Lossless Claw (LCM) stores everything in a directed acyclic graph — summaries point back to the full content they were derived from. But DAG summaries aren't semantically searchable. RagFlow is semantically searchable but doesn't have the full conversation history.

The bridge connects them: LCM summaries are synced to RagFlow on every message and via cron. When the Memory Agent searches for a concept, RagFlow finds the relevant summaries by meaning, and the agent drills back through LCM to get the full original context. Semantic discovery with lossless depth.

Nobody else has this. Gigabrain can't do semantic search over history. LCM can't do semantic search at all. We do both.

### World Model

The world model lives in Postgres with bi-temporal timestamps (valid time + transaction time). It stores:

- **Entities** — people, tools, projects, machines, concepts
- **Beliefs** — what the agent thinks is true, with confidence scores
- **Episodes** — significant events with causal links
- **Contradictions** — when new information conflicts with existing beliefs, both are kept with flags

The world model is not a simple key-value store. It tracks how the agent's understanding evolves over time. A belief from last week that was updated today still has its original timestamp — the agent can see what it used to think and why it changed its mind.

### Quality Scoring

Every piece of information entering the memory system is scored on 9 dimensions:

1. **Novelty** — is this new information or redundant?
2. **Relevance** — does this relate to active tasks or goals?
3. **Actionability** — can the agent act on this?
4. **Emotional weight** — does this matter to the operator?
5. **Contradiction** — does this conflict with existing knowledge?
6. **Source reliability** — how trustworthy is the source?
7. **Specificity** — concrete facts score higher than vague statements
8. **Temporal sensitivity** — time-bound information gets urgency weighting
9. **Cross-reference potential** — does this connect to multiple existing memories?

Low-scoring information is still stored (nothing is deleted) but decays faster and ranks lower in retrieval. High-scoring information decays slower and surfaces more readily. The quality threshold adapts over time based on retrieval success rates — the agent learns what quality of information actually helps it.

---

## Self-Improvement

OpenClaw Brain implements [Karpathy's autoresearch concept](https://github.com/karpathy/autoresearch) as a continuous loop:

```
┌──────────────────────────────────────────────────────┐
│                                                      │
│   1. Act         — Complete a task                   │
│   2. Evaluate    — Score performance (what was       │
│                    slow? what failed? what worked?)   │
│   3. Research    — Use NotebookLM/Gemini + GitHub    │
│                    to find better approaches          │
│   4. Improve     — Update own tools, skills, prompts │
│   5. Log         — Store improvement in Memos +      │
│                    Obsidian (with [[wiki-links]])     │
│   6. Repeat      — Agent is now better at step 1     │
│                                                      │
└──────────────────────────────────────────────────────┘
```

This loop runs on **everything** — not just coding. Memory retrieval strategies, tool selection, workflow planning, sub-agent spawning, context window management. The agent improves the loop that improves itself.

### What Gets Self-Improved

- **Tools** — Discovery scanner finds better tools on GitHub via [Github-Ranking](https://github.com/EvanLi/Github-Ranking), evaluates them, integrates what works
- **Skills** — Agent evolves its own skill files based on what strategies succeed. Draws from [800+ skills](https://github.com/alirezarezvani/claude-skills) and [5,400+ skill registry](https://github.com/VoltAgent/awesome-openclaw-skills)
- **Prompts** — System prompts and templates are rewritten based on eval scores
- **Memory** — Routing heuristics, quality thresholds, and decay parameters adapt over time
- **Workflows** — Multi-step processes are profiled, bottlenecks identified, steps reordered or parallelized

### Discovery Scanner

The agent doesn't wait for humans to find better tools. The discovery scanner runs weekly:

1. Pulls trending repos from [Github-Ranking](https://github.com/EvanLi/Github-Ranking) and [The Book of Secret Knowledge](https://github.com/trimstray/the-book-of-secret-knowledge)
2. Filters for repos relevant to the agent's capabilities
3. Evaluates star count, activity, documentation quality
4. Tests integration feasibility
5. Updates `TOOLS.md` and logs findings to Obsidian with `[[wiki-links]]` to related tools

---

## Quick Start

### One-Command Install

```bash
git clone https://github.com/SuperNovaRobot/openclaw-brain.git
cd openclaw-brain
bash setup/install.sh
```

The installer auto-detects your hardware and selects the right profile. For non-interactive setup:

```bash
bash setup/install.sh --defaults
```

### Hardware Profiles

The installer supports five hardware profiles out of the box:

| Profile | Hardware | What You Get |
|---------|----------|-------------|
| `jetson-orin` | Jetson Orin + GPU rig | Two-machine setup. Full stack + robotics hardware |
| `multi-gpu` | 4-8x GPU workstation | Full power. 8-way tensor parallel, 1M context |
| `single-gpu` | 1x GPU (8GB+ VRAM) | All-in-one. Smaller models (7B-70B) |
| `cloud` | Cloud GPU (A100/H100) | Elastic scaling. Full features minus robotics |
| `cpu-only` | Any machine, 16GB+ RAM | External API for inference. Memory stack only |

### Verify Installation

```bash
bash tests/test-health.sh          # Service health checks
bash tests/test-memory-stack.sh    # Memory layer connectivity
bash tests/test-full-system.sh     # Full integration test
```

---

## Hardware Support

| Tier | Example Hardware | GPU | RAM | Inference | Memory Stack | Robotics |
|------|-----------------|-----|-----|-----------|-------------|----------|
| **Hybrid** | Jetson Orin + 8x 3090 rig | 8x 24GB | 64 + 256 GB | Nemotron 122B, 1M ctx | Full 5-layer | OAK-D, arm, sim |
| **Multi-GPU** | 4-8x A100/H100 | 4-8x 80GB | 256GB+ | Nemotron 122B, 1M ctx | Full 5-layer | Sim only |
| **Single-GPU** | RTX 3090 / 4090 | 1x 24GB | 32GB | 7B-70B models | Full 5-layer | No |
| **Cloud** | AWS / GCP GPU instance | Elastic | Elastic | Nemotron 122B | Full 5-layer | No |
| **CPU-Only** | Any laptop / desktop | None | 16GB | External API | Partial (Postgres + Memos) | No |

---

## Project Structure

```
openclaw-brain/
├── agents/                    # Sub-agent definitions
│   ├── coding-delegate/       #   Code generation via Claude Code / Codex
│   ├── memory-agent/          #   Dedicated 5-layer memory search agent
│   └── research-agent/        #   NotebookLM + Tavily research pipeline
├── docs/                      # Documentation
│   ├── quickstart.md          #   Getting started guide
│   ├── memory-system.md       #   Memory architecture deep-dive
│   ├── self-improvement.md    #   Autoresearch loop details
│   ├── hardware-guide.md      #   Hardware tier guide
│   └── troubleshooting.md     #   Common issues + fixes
├── memory/                    # Memory subsystem
│   ├── behavior-mcps/         #   Memory-decision, self-eval, task-router MCPs
│   ├── decay/                 #   Hebbian activation decay engine
│   ├── dedup/                 #   Cross-layer deduplication
│   ├── eval/                  #   Memory evaluation + quality scoring
│   ├── extraction/            #   Entity / fact / belief extraction
│   ├── hooks/                 #   Pre/post message hooks
│   ├── lcm-bridge/            #   Lossless Claw → RagFlow bridge
│   ├── orchestrator/          #   Pre-Prompt Orchestrator (6 strategies)
│   ├── quality/               #   9-dimensional quality scoring
│   └── schema/                #   Postgres schema (world model, bi-temporal)
├── obsidian-vault/            # Obsidian knowledge graph
│   ├── daily/                 #   Chronological daily notes
│   ├── improvements/          #   Self-improvement logs
│   ├── projects/              #   Project-specific knowledge
│   ├── research/              #   Research findings
│   ├── robots/                #   Robotics knowledge base
│   ├── templates/             #   Note templates
│   └── tools/                 #   Tool evaluations + docs
├── robotics/                  # Robotics subsystem
│   ├── arm-control/           #   Dynamixel servo control
│   ├── avatar/                #   AIRI avatar display
│   └── nova-vision/           #   OAK-D Pro stereo vision pipeline
├── self-improvement/          # Autoresearch loop
│   ├── discovery-scanner/     #   GitHub tool discovery
│   ├── eval-logger/           #   Performance evaluation logging
│   ├── experiment-runner/     #   A/B experiment framework
│   └── instinct-extractor/    #   Pattern extraction from successes
├── setup/                     # Installation + deployment
│   ├── docker-compose.*.yml   #   Compose files per topology
│   ├── hardware-profiles/     #   5 hardware tier configs
│   ├── install.sh             #   One-command installer
│   └── scripts/               #   Setup helper scripts
├── skills/                    # Agent skill definitions (17 files)
│   ├── memory-agent.SKILL.md
│   ├── research-pipeline.SKILL.md
│   ├── vision-pipeline.SKILL.md
│   └── ...
├── tests/                     # Integration + unit tests (15 files)
│   ├── test-full-system.sh
│   ├── test-memory-stack.sh
│   └── ...
├── workspace/                 # Runtime workspace
│   ├── SOUL.md                #   Agent values + boundaries
│   ├── IDENTITY.md            #   Agent identity
│   ├── TOOLS.md               #   Active tool registry
│   ├── AGENTS.md              #   Sub-agent definitions
│   └── MEMORY.md              #   Memory routing config
├── ARCHITECTURE.md            # Full architecture specification
├── LICENSE                    # Apache 2.0
└── README.md                  # You are here
```

---

## Contributing

Contributions are welcome. OpenClaw Brain is Apache 2.0 licensed — see [LICENSE](LICENSE) for details.

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Run tests (`bash tests/test-full-system.sh`)
5. Open a PR against `v2.0/lossless-memory`

For architecture decisions and design context, see [ARCHITECTURE.md](ARCHITECTURE.md).

---

<div align="center">

**Built for agents that remember everything, learn from everything, and never stop improving.**

[⬆ Back to top](#-openclaw-brain)

</div>
