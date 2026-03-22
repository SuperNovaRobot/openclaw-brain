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

[Quick Start](#quick-start) · [Architecture](#architecture) · [Memory System](#memory-system) · [Self-Improvement](#self-improvement) · [Contributing](#contributing)

</div>

---

Most agent frameworks are fixed pipelines — same prompts, same chains, every single time. OpenClaw Brain is a **cognitive architecture**: a 5-layer memory stack, a dedicated Memory Agent, a lossless context engine, and a self-improvement loop built on [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) concept. The agent doesn't just follow instructions — it evaluates its own performance, researches better approaches, and rewrites its own tools, skills, and prompts. It gets better at getting better.

Designed for real hardware. Runs on a Jetson Orin, scales to 8x GPU rigs, deploys to cloud. No toy demos — production Postgres, Elasticsearch, RagFlow, and Obsidian knowledge graphs. Built for agents that need to remember everything, learn from everything, and eventually control a physical body.

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

## Why Not SQLite?

Every other agent memory plugin stores memories in SQLite and calls it a day. Here's why that doesn't scale:

| Feature | SQLite Plugins | OpenClaw Brain |
|---------|---------------|----------------|
| Multi-agent writes | ❌ Single-writer lock | ✅ Postgres MVCC — concurrent agents, zero contention |
| Vector search | ❌ FTS5 only | ✅ pgvector + Elasticsearch hybrid |
| Semantic search | ❌ Basic BM25 | ✅ RagFlow hybrid (BM25 + vector + rerank) |
| Knowledge graph | ❌ Flat key-value | ✅ Obsidian wiki-links + Postgres world model |
| Research brain | ❌ None | ✅ NotebookLM (Gemini) + SurfSense fallback |
| Memory Agent | ❌ Auto-inject only | ✅ Dedicated agent, 5-layer curated search |
| Lossless context | ❌ Most delete old memories | ✅ Lossless Claw DAG + drill-back + RagFlow bridge |
| Quality scoring | ❌ Store everything | ✅ 9-dimensional scoring, noise rejection |
| Decay engine | ❌ No decay model | ✅ Hebbian activation decay, reinforcement on access |
| Scale | ❌ Single machine | ✅ Multi-machine (brain + GPU rig + cloud) |

---

## Memory System

The 5-layer memory stack is the core of OpenClaw Brain. Each layer has a specific purpose and access pattern:

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

### What gets self-improved

- **Tools** — Discovery scanner finds better tools on GitHub, evaluates them, integrates what works
- **Skills** — Agent evolves its own skill files based on what strategies succeed
- **Prompts** — System prompts and templates are rewritten based on eval scores
- **Memory** — Routing heuristics, quality thresholds, and decay parameters adapt over time
- **Workflows** — Multi-step processes are profiled, bottlenecks identified, steps reordered or parallelized

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
| **Hybrid** | Jetson Orin + 8x 3090 rig | 8x 24GB | 64 + 256 GB | Nemotron 122B, 1M ctx | Full 5-layer | ✅ OAK-D, arm, sim |
| **Multi-GPU** | 4-8x A100/H100 | 4-8x 80GB | 256GB+ | Nemotron 122B, 1M ctx | Full 5-layer | Sim only |
| **Single-GPU** | RTX 3090 / 4090 | 1x 24GB | 32GB | 7B-70B models | Full 5-layer | ❌ |
| **Cloud** | AWS / GCP GPU instance | Elastic | Elastic | Nemotron 122B | Full 5-layer | ❌ |
| **CPU-Only** | Any laptop / desktop | None | 16GB | External API | Partial (Postgres + Memos) | ❌ |

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
