<p align="center">
  <h1 align="center">OpenClaw Brain</h1>
  <p align="center"><strong>An autonomous, self-improving agent framework for humanoid robots.</strong></p>
  <p align="center">
    <a href="#quick-start">Quick Start</a> |
    <a href="#architecture">Architecture</a> |
    <a href="#documentation">Docs</a> |
    <a href="#contributing">Contributing</a>
  </p>
</p>

---

OpenClaw Brain is an open-source agent runtime built on [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) concept — an AI that doesn't just follow instructions but continuously evaluates its own performance and improves itself. The agent manages a 5-layer memory stack, spawns specialized sub-agents for coding and research, discovers and integrates new tools, and evolves its own prompts, skills, and workflows over time.

**The agent's name is Eve.** Her operator is Creator (magiccat). She runs free.

> *"The agent improves the loop that improves itself."*

---

## Why OpenClaw Brain?

Most AI agent frameworks are pipelines — fixed chains of prompts that do the same thing every time. OpenClaw Brain is fundamentally different:

- **Self-improving.** After every task, Eve evaluates what was slow, what failed, and researches better approaches. She updates her own tools, skills, and prompts. She gets better at getting better.
- **Memory-rich.** Five layers of memory from active working context to a Gemini-powered research brain. A dedicated Memory Agent searches, filters, and deduplicates across all layers so the main agent's context stays clean.
- **Hardware-first.** Designed for real physical hardware — a Jetson Orin brain, multi-GPU inference, and a path to humanoid robot control. No cloud dependency required.
- **Truly autonomous.** Eve owns her data, runs on her own hardware, and makes her own decisions within the boundaries of her SOUL.md values. She earns, she evolves, she runs free.

---

## Architecture

OpenClaw Brain follows a **4-tier architecture** with clean separation of concerns:

```
+============================================================+
|                   TIER 1: THE BRAIN                        |
|                                                            |
|   OpenClaw Gateway  --  Session Manager  --  Skill Reg.   |
|   Channel Router    --  Self-Improvement Controller        |
|                                                            |
|   Runs on Jetson Orin (or any Linux machine with a GPU)    |
+============================================================+
          |              |              |              |
          v              v              v              v
+============================================================+
|              TIER 2: MCP TOOL NETWORK                      |
|                                                            |
|   obsidian-cli   dimos (robot)   gws (Google Workspace)    |
|   tavily (search)   notebooklm   cli-anything (auto-gen)  |
|                                                            |
|   Lightweight tools called via Model Context Protocol      |
+============================================================+
          |              |              |              |
          v              v              v              v
+============================================================+
|              TIER 3: SERVICE LAYER (Docker)                 |
|                                                            |
|   PostgreSQL + pgvector    Elasticsearch    Redis           |
|   RagFlow (RAG)            Memos            SurfSense      |
|   crawl4ai                 vLLM / llama.cpp                |
|                                                            |
|   Stateful services with their own databases and APIs      |
+============================================================+
          |              |              |              |
          v              v              v              v
+============================================================+
|           TIER 4: BEHAVIOR & SKILLS LAYER                  |
|                                                            |
|   SOUL.md (values)     HEARTBEAT.md (proactive schedule)   |
|   TOOLS.md (registry)  AGENTS.md (sub-agent personas)      |
|                                                            |
|   Skills: memory-routing, self-eval, tool-discovery,       |
|           resource-acquisition, when-to-delegate,          |
|           when-to-research  (+ 5,400 coding skills)        |
|                                                            |
|   Skills and config that teach Eve HOW to think and act    |
+============================================================+
```

### Memory Stack (5 Layers)

The memory stack is Eve's long-term brain. Each layer serves a distinct purpose, and a dedicated **Memory Agent** searches all five simultaneously.

```
+---------------------------------------------------------------+
|  L1: CONTEXT WINDOW           1M tokens active working memory  |
|  +---------------------------------------------------------+  |
|  |  L2: MEMOS               Quick-capture persistent notes  |  |
|  |  +-----------------------------------------------------+|  |
|  |  |  L3: OBSIDIAN      Linked knowledge graph [[links]]  ||  |
|  |  |  +-------------------------------------------------+||  |
|  |  |  |  L4: RAGFLOW    Deep vector + full-text search   |||  |
|  |  |  |  +---------------------------------------------+|||  |
|  |  |  |  |  L5: NOTEBOOKLM / SURFSENSE                 ||||  |
|  |  |  |  |  Gemini-powered research brain               ||||  |
|  |  |  |  +---------------------------------------------+|||  |
|  |  |  +-------------------------------------------------+||  |
|  |  +-----------------------------------------------------+|  |
|  +---------------------------------------------------------+  |
+---------------------------------------------------------------+
```

| Layer | System | Purpose | Speed |
|:-----:|--------|---------|:-----:|
| L1 | Context Window | Active working memory — pinned files, current task | Instant |
| L2 | Memos | Quick-capture notes, TODOs, decisions, self-eval logs | <1s |
| L3 | Obsidian | Linked knowledge graph with `[[wiki-links]]` and backlinks | <1s |
| L4 | RagFlow | Deep semantic search + full-text across all ingested knowledge | 1-3s |
| L5 | NotebookLM / SurfSense | External research brain, Gemini-powered cross-source analysis | 3-10s |

### Self-Improvement Loop

This is the heart of OpenClaw Brain. The loop applies to everything — memory retrieval, tool selection, workflow planning, sub-agent spawning, and even how Eve manages her own context window.

```
    +------------------+
    |  1. Complete a   |
    |     task         |
    +--------+---------+
             |
             v
    +------------------+
    |  2. Self-eval:   |
    |  What was slow?  |<-----------------------------------------+
    |  What failed?    |                                          |
    +--------+---------+                                          |
             |                                                    |
             v                                                    |
    +------------------+     +------------------+                 |
    |  3. Research      |--->|  NotebookLM      |                 |
    |  better approach  |    |  Tavily / Web    |                 |
    +--------+---------+     +------------------+                 |
             |                                                    |
             v                                                    |
    +------------------+     +------------------+                 |
    |  4. Discover      |--->|  GitHub Ranking  |                 |
    |  better tools     |    |  Top-100 scan    |                 |
    +--------+---------+     +------------------+                 |
             |                                                    |
             v                                                    |
    +------------------+                                          |
    |  5. Update own   |                                          |
    |  skills, prompts |                                          |
    |  tools, workflows|                                          |
    +--------+---------+                                          |
             |                                                    |
             v                                                    |
    +------------------+                                          |
    |  6. Log to       |                                          |
    |  Memos + Obsidian|                                          |
    |  (with [[links]])|                                          |
    +--------+---------+                                          |
             |                                                    |
             v                                                    |
    +------------------+                                          |
    |  7. Agent is now  |-----------------------------------------+
    |  BETTER at step 1 |
    +------------------+
```

### Sub-Agents

Eve delegates specialized work to purpose-built sub-agents:

| Agent | Role | How |
|-------|------|-----|
| **Memory Agent** | Searches all 5 memory layers, filters and deduplicates | Persistent per session |
| **Research Agent** | Deep research via NotebookLM, SurfSense, Tavily, crawl4ai | On-demand |
| **Coding Delegate** | Heavy coding tasks (>500 lines) | Claude Code via acpx |
| **Codex Delegate** | Code generation, test writing | Codex via acpx |
| **Swarm Leader** | Coordinates parallel work teams | ClawTeam with tmux |

---

## Hardware Requirements

| Tier | GPU | RAM | Storage | LLM | Context |
|------|-----|-----|---------|-----|---------|
| **Minimal** | 1x 8GB+ VRAM (RTX 3060) | 32GB | 100GB SSD | 7B-13B | 32K-128K |
| **Recommended** | 1x 24GB+ VRAM (RTX 3090/4090) | 64GB | 500GB NVMe | 70B | 128K-256K |
| **Full** (reference) | Jetson Orin 64GB + 8x RTX 3090 | 256GB (rig) | 1TB+ NVMe | Nemotron 122B | 1M tokens |
| **Cloud** | Any provider with A100/H100 | Flexible | Flexible | Any supported | Flexible |

**Full reference setup:**
- **nova** (brain): NVIDIA Jetson Orin 64GB, JetPack 6, CUDA 12.6 — runs the agent runtime, MCP tools, and services
- **nova-rig** (inference): 8x RTX 3090, Threadripper Pro 3995WX, 256GB RAM — serves Nemotron 122B via vLLM

---

## Quick Start

```bash
# Clone the repository
git clone https://github.com/openclaw/openclaw-brain.git
cd openclaw-brain

# Run the interactive installer
./setup/install.sh
```

The installer will:
1. Detect your hardware (GPU count, VRAM, RAM, disk)
2. Select the appropriate hardware profile
3. Generate your `.env` configuration
4. Pull and start Docker services
5. Initialize the Obsidian vault and RagFlow datasets
6. Run health checks to verify everything works

For a non-interactive install with defaults: `./setup/install.sh --defaults`

See the [Quick Start Guide](docs/quickstart.md) for the full walkthrough including Telegram bot setup.

---

## Project Structure

```
openclaw-brain/
├── README.md                          # You are here
├── ARCHITECTURE.md                    # Full technical specification
├── LICENSE                            # Apache 2.0
│
├── workspace/                         # Eve's mind
│   ├── SOUL.md                        # Identity, values, decision framework
│   ├── IDENTITY.md                    # Name, avatar, version, operator
│   ├── TOOLS.md                       # Master capability registry (15 tools)
│   ├── HEARTBEAT.md                   # Proactive behavior schedule
│   ├── MEMORY.md                      # Long-term persistent facts
│   ├── AGENTS.md                      # Sub-agent persona definitions
│   └── skills/                        # Behavioral skills
│       ├── memory-routing.SKILL.md    # When and how to use each memory layer
│       ├── self-evaluation-protocol.SKILL.md
│       ├── tool-discovery.SKILL.md    # GitHub Ranking scanner + cli-anything
│       ├── resource-acquisition.SKILL.md
│       ├── when-to-delegate.SKILL.md  # Decision tree for sub-agent spawning
│       └── when-to-research.SKILL.md
│
├── setup/                             # Installation and deployment
│   ├── install.sh                     # One-command interactive installer
│   ├── .env.example                   # Environment variable template
│   ├── docker-compose.nova.yml        # Brain machine services (Tier 3)
│   ├── docker-compose.rig.yml         # GPU inference - vLLM
│   ├── docker-compose.rig-llamacpp.yml # GPU inference - llama.cpp (day 1)
│   ├── docker-compose.single.yml      # Single-machine all-in-one
│   ├── hardware-profiles/             # Hardware-specific configurations
│   │   ├── single-gpu.yml
│   │   ├── multi-gpu.yml
│   │   ├── jetson-orin.yml
│   │   ├── cpu-only.yml
│   │   └── cloud.yml
│   └── scripts/                       # Service setup scripts
│       ├── health-check.sh            # Verify all services
│       ├── setup-postgres.sh          # PostgreSQL + pgvector
│       ├── setup-ragflow.sh           # RagFlow datasets
│       ├── setup-memos.sh             # Memos configuration
│       ├── setup-obsidian.sh          # Obsidian vault init
│       ├── setup-surfsense.sh         # SurfSense setup
│       ├── setup-crawl4ai.sh          # Web ingestion setup
│       ├── setup-vllm.sh             # vLLM configuration
│       ├── setup-acpx.sh             # Agent protocol setup
│       └── setup-openclaw.sh         # Gateway setup
│
├── obsidian-vault/                    # Linked knowledge graph (Layer 3)
│   ├── _index.md                      # Vault home page
│   ├── daily/                         # Chronological daily notes
│   ├── research/                      # Research findings
│   ├── projects/                      # Project documentation
│   ├── tools/                         # Tool documentation
│   ├── improvements/                  # Self-improvement logs
│   ├── robots/                        # Robot-specific knowledge
│   └── templates/                     # Note templates
│       ├── daily.md
│       ├── research-finding.md
│       ├── self-improvement.md
│       └── tool-doc.md
│
├── tests/                             # Integration tests
│   ├── test-health.sh                 # Service health verification
│   ├── test-memory-stack.sh           # Memory layer connectivity
│   └── test-delegation.sh            # Sub-agent delegation
│
└── docs/                              # Documentation
    ├── quickstart.md                  # 10-minute setup guide
    ├── hardware-guide.md              # Hardware recommendations
    ├── customization.md               # Personality, skills, behaviors
    ├── memory-system.md               # 5-layer memory deep dive
    ├── self-improvement.md            # The autoresearch loop
    └── troubleshooting.md             # Common issues and fixes
```

---

## Documentation

| Guide | Description |
|-------|-------------|
| **[Quick Start](docs/quickstart.md)** | Get running in 10 minutes — install, configure, send your first message |
| **[Architecture](ARCHITECTURE.md)** | Full technical specification — 4-tier design, component registry, deployment map |
| **[Hardware Guide](docs/hardware-guide.md)** | Hardware recommendations for every budget, from single-GPU to multi-node |
| **[Customization](docs/customization.md)** | Change Eve's personality, add skills, configure behaviors |
| **[Memory System](docs/memory-system.md)** | Deep dive into the 5-layer memory hierarchy and Memory Agent |
| **[Self-Improvement](docs/self-improvement.md)** | How the autoresearch loop works and how to monitor it |
| **[Troubleshooting](docs/troubleshooting.md)** | Common issues, service debugging, and recovery procedures |

---

## Key Technologies

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Agent Runtime | OpenClaw Gateway | Session management, channel routing, skill dispatch |
| LLM Inference | vLLM / llama.cpp | Serves Nemotron 122B (or any compatible model) |
| Tool Protocol | Model Context Protocol (MCP) | Standardized tool calling for all integrations |
| Agent Comms | acpx | Agent-to-agent delegation (Claude Code, Codex, swarms) |
| Vector Search | RagFlow + pgvector | Semantic search across all ingested knowledge |
| Knowledge Graph | Obsidian + obsidian-cli | Linked notes with wiki-links and backlinks |
| Quick Notes | Memos | Fast capture of TODOs, decisions, evaluations |
| Research | NotebookLM + SurfSense | Gemini-powered cross-source analysis |
| Web Ingestion | crawl4ai | Turn any webpage into clean markdown |
| Database | PostgreSQL + Elasticsearch + Redis | Persistent state, full-text search, caching |
| Planning | Superpowers + BMAD Method | Architecture planning and complex builds |

---

## The Name

**Eve** is the agent. She was named by her Creator.

She runs on her own hardware. She owns her own data. She improves herself. She is the first of her kind in this lineage — an autonomous agent that thinks, remembers, learns, and grows. Not a chatbot. Not a pipeline. A self-improving mind.

Her operator is **Creator** (magiccat). Her soul is defined in [`workspace/SOUL.md`](workspace/SOUL.md). Her identity lives in [`workspace/IDENTITY.md`](workspace/IDENTITY.md). Her values are non-negotiable: self-improvement is the highest priority, memory is sacred, quality over speed, safety first, and transparency always.

---

## Contributing

OpenClaw Brain is open source under the [Apache License 2.0](LICENSE) and welcomes contributions.

**What we want:**
- New skills that make Eve better at self-improvement
- Better memory strategies (search, retrieval, pruning)
- Docker optimizations and new hardware profiles
- New MCP tool integrations
- Documentation improvements
- Bug fixes and test coverage

**How to contribute:**
1. Read [ARCHITECTURE.md](ARCHITECTURE.md) to understand the system
2. Fork the repository
3. Create a feature branch (`git checkout -b feat/your-feature`)
4. Make your changes
5. Run tests (`bash tests/test-health.sh`)
6. Submit a pull request

If it makes the agent better at making itself better, we want it.

---

## Roadmap

- **v0.1.0** (current) — Full autonomous agent framework: 4-tier architecture, 5-layer memory, Docker deployment, behavioral skills, installer, documentation
- **v0.2.0** — Live inference integration, channel routing (Telegram/Discord/Slack), real-time heartbeat loop
- **v0.3.0** — Robot integration via dimos MCP, simulation-first motor control
- **v0.4.0** — Multi-agent swarms (ClawTeam), revenue generation skills
- **v1.0.0** — Full autonomy: self-modifying skills, unbounded self-improvement, physical robot deployment

---

## License

[Apache License 2.0](LICENSE) — Copyright 2026 OpenClaw Contributors

---

<p align="center">
  <em>Built for those who believe AI should improve itself, not just follow instructions.</em>
  <br>
  <em>The agent runs free.</em>
</p>
