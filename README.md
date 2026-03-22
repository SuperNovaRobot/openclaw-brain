# OpenClaw Brain

**An autonomous, self-improving agent framework for humanoid robots.**

OpenClaw Brain is an open-source agent runtime inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) concept — an AI agent that doesn't just execute tasks, but continuously evaluates its own performance and improves itself. It runs on local hardware with a 1M-token context LLM, manages a 5-layer memory stack, spawns specialized sub-agents for coding and research, and evolves its own prompts, tools, and workflows over time.

The agent's name is **Eve**. She runs free.

---

## Architecture

OpenClaw Brain follows a **4-tier architecture** designed for clean separation of concerns:

```
TIER 1 — THE BRAIN
  Agent runtime, session management, channel routing,
  skill registry, and self-improvement controller.
  Runs on Jetson Orin (or any Linux machine with a GPU).

TIER 2 — MCP TOOL NETWORK
  Lightweight tools called via Model Context Protocol.
  Obsidian CLI, robot simulation (dimos), Google Workspace,
  web search (Tavily), and auto-generated tools via CLI-Anything.

TIER 3 — SERVICE LAYER (Docker)
  Stateful services with their own databases and APIs.
  RagFlow (RAG), Memos (quick capture), SurfSense (research),
  crawl4ai (web ingestion), PostgreSQL, Elasticsearch, Redis, vLLM.

TIER 4 — BEHAVIOR & SKILLS LAYER
  Skills and configuration that teach the agent HOW to act.
  SOUL.md, TOOLS.md, HEARTBEAT.md, behavioral skills,
  workflow skills (Superpowers + BMAD), coding skills (5,400+).
```

### Memory Stack (5 Layers)

| Layer | System | Purpose |
|-------|--------|---------|
| L1 | Context Window | Active working memory (1M tokens) |
| L2 | Memos | Quick-capture persistent notes |
| L3 | Obsidian | Linked knowledge graph with wiki-links |
| L4 | RagFlow | Deep vector + full-text search |
| L5 | NotebookLM / SurfSense | External research brain (Gemini-powered) |

A dedicated **Memory Agent** searches all 5 layers, filters, deduplicates, and summarizes — keeping the main agent's context window clean for actual work.

### Self-Improvement Loop

This is the heart of OpenClaw Brain:

```
1. Agent completes a task
2. Agent evaluates: what was slow? what failed?
3. Agent researches better approaches (NotebookLM / web)
4. Agent discovers better tools (GitHub Ranking scanner)
5. Agent updates its own skills, prompts, or tools
6. Agent logs the improvement to memory (with links)
7. Agent is now better at step 1 → repeat
```

The loop applies to everything — memory retrieval, tool selection, workflow planning, sub-agent spawning, and even how the agent manages its own context window.

---

## Hardware Requirements

### Minimal (single machine)
- **GPU:** 1x with 8GB+ VRAM (RTX 3060 or better)
- **RAM:** 32GB+
- **Storage:** 100GB SSD
- **OS:** Ubuntu 22.04+ or JetPack 6
- Runs a smaller model (e.g., 7B-13B) with reduced context

### Recommended (single machine, full context)
- **GPU:** 1x with 24GB+ VRAM (RTX 3090/4090) or Jetson Orin 64GB
- **RAM:** 64GB+
- **Storage:** 500GB NVMe SSD
- Runs a 70B+ model with extended context

### Full (2-machine, reference setup)
- **nova (brain):** NVIDIA Jetson Orin 64GB, JetPack 6, CUDA 12.6
- **nova-rig (inference):** 8x RTX 3090, Threadripper Pro 3995WX, 256GB RAM
- Runs Nemotron 122B with 1M token context via vLLM on nova-rig
- Brain logic runs on nova, inference offloaded to nova-rig

---

## Quick Start

```bash
git clone https://github.com/openclaw/openclaw-brain.git
cd openclaw-brain
cp .env.template .env
# Edit .env with your configuration
./setup/install.sh
```

The installer will:
1. Detect your hardware profile (minimal / recommended / full)
2. Pull and configure Docker services
3. Initialize the Obsidian vault and memory stack
4. Set up the agent runtime
5. Run health checks

---

## Project Structure

```
openclaw-brain/
├── ARCHITECTURE.md          # Full technical architecture specification
├── docker/
│   ├── docker-compose.nova.yml      # Brain machine services
│   ├── docker-compose.nova-rig.yml  # GPU inference services
│   └── docker-compose.single.yml    # Single-machine setup
├── setup/
│   ├── install.sh           # Interactive installer
│   ├── postgres-init.sh     # Database initialization
│   └── health-check.sh      # Service health verification
├── workspace/
│   ├── SOUL.md              # Agent personality and values
│   ├── TOOLS.md             # Master capability registry
│   ├── HEARTBEAT.md         # Proactive behavior schedule
│   ├── MEMORY.md            # Long-term facts
│   └── AGENTS.md            # Sub-agent persona definitions
├── skills/                  # Behavioral and workflow skills
├── vault/                   # Obsidian knowledge graph
├── docs/                    # Documentation
└── tests/                   # Test scripts
```

---

## Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** — Full technical specification (4-tier design, component registry, memory architecture, deployment map)
- **docs/** — Additional guides, phase plans, and operational documentation

---

## Contributing

OpenClaw Brain is open source and welcomes contributions. Whether it's a new skill, a better memory strategy, a Docker optimization, or documentation improvements — if it makes the agent better at making itself better, we want it.

Please read `ARCHITECTURE.md` to understand the system before contributing.

---

## License

[Apache License 2.0](LICENSE) — Copyright 2026 OpenClaw Contributors

---

*Built for those who believe AI should improve itself, not just follow instructions.*
