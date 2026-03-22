# OpenClaw Autonomous Agent — Technical Architecture Specification

**Document Type:** System Architecture Design
**Date:** 2026-03-21
**Status:** Draft — Pending Multi-AI Review
**Project:** OpenClaw Humanoid Robot Agent Framework
**Core Concept:** Karpathy's Autoresearch — Autonomous Self-Improvement

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Component Registry](#2-component-registry)
3. [Communication Architecture](#3-communication-architecture)
4. [Memory Architecture](#4-memory-architecture)
5. [Behavior & Skills Layer](#5-behavior--skills-layer)
6. [Self-Improvement Loop](#6-self-improvement-loop)
7. [Agent Spawning Model](#7-agent-spawning-model)
8. [CLI Tool Matrix](#8-cli-tool-matrix)
9. [Deployment Map](#9-deployment-map)
10. [Robotics Integration](#10-robotics-integration)
11. [Implementation Phases](#11-implementation-phases)
12. [TOOLS.md Specification](#12-toolsmd-specification)
13. [Risk Assessment](#13-risk-assessment)
14. [Distribution & Installation](#14-distribution--installation)

---

## 1. System Overview

OpenClaw is an autonomous agent framework for a physical humanoid robot. It runs on a local Nemotron 122B model (1M token context window) on a Jetson Orin, delegates heavy coding to Claude Code and Codex via the Agent Client Protocol (acpx), and continuously self-improves using Karpathy's autoresearch concept.

**This entire framework will be open-sourced on GitHub** as a streamlined, installable system. Any user with compatible hardware should be able to go from zero to a running self-improving agent in a single setup process.

The architecture follows a **4-tier design** with a **Memory Agent pattern** that keeps the main agent's context window clean.

### 4-Tier Architecture

```
TIER 1: THE BRAIN
  OpenClaw Gateway (nova - Jetson Orin)
  - Agent Runtime (Pi, runs free — no unnecessary sandboxing)
  - Session Manager
  - Channel Router (Telegram/Discord/WhatsApp/etc)
  - Skill Registry (ClawHub + 5,400+ skills)
  - Plugin: MemOS (lifecycle memory hooks)
  - TOOLS.md (master capability registry)
  - Self-Improvement Controller
    - autoresearch loop (evaluate -> research -> improve)
    - instinct extraction (ECC hooks)
    - skill evolution (instincts -> SKILL.md)
    - discovery scanner (GitHub Ranking + CLI-Anything)

TIER 2: MCP TOOL NETWORK
  Lightweight tools the agent calls via MCP protocol
  - obsidian-cli (vault CRUD + search via MCP server)
  - dimos (robot simulation + control via MCP)
  - gws (Google Workspace CLI)
  - FreeCAD MCP (CAD design)
  - NotebookLM MCP (Gemini research)
  - Tavily MCP (web search)
  - CLI-Anything generated tools (any new tool the agent discovers)

TIER 3: SERVICE LAYER (Docker)
  Stateful services with their own databases and APIs
  - RagFlow       :9380  (REST API, Elasticsearch + PostgreSQL)
  - Memos         :5230  (REST + gRPC, PostgreSQL)
  - SurfSense     :8000  (FastAPI, PostgreSQL + Redis)
  - crawl4ai      :11235 (REST + MCP, Chromium)
  - PostgreSQL    :5432  (shared, with pgvector extension)
  - Elasticsearch :9200  (RagFlow vectors + full-text)
  - Redis         :6379  (SurfSense cache + Celery broker)
  - vLLM          :8080  (on nova-rig, 8x RTX 3090)

TIER 4: BEHAVIOR & SKILLS LAYER
  Skills + MCPs that teach the agent HOW to act
  - SOUL.md (personality, values, decision framework)
  - AGENTS.md (persona definitions for sub-agents)
  - TOOLS.md (master capability registry)
  - HEARTBEAT.md (proactive behavior checklist, cron)
  - MEMORY.md (long-term facts the agent must know)
  - Behavioral Skills (when-to-research, when-to-delegate, etc.)
  - Workflow Skills (superpowers 14 skills, BMAD 34 workflows)
  - Coding Skills (everything-claude-code 102, claude-skills 192)
  - Behavior MCPs (Task Router, Memory Decision, Self-Eval)
```

### Core Design Principles

1. **The brain delegates, doesn't absorb.** OpenClaw makes decisions. MCP tools provide capabilities. Services handle stateful workloads. The brain never tries to do everything itself.

2. **Memory Agent pattern.** The main agent NEVER searches memory directly. A dedicated Memory Agent sub-agent searches all 5 layers, filters, deduplicates, summarizes, and returns only relevant context. This keeps the main agent's 1M token context window clean for actual work.

3. **MCP is the integration protocol.** Adding a new capability = deploying a new MCP server + updating TOOLS.md. CLI-Anything auto-generates MCP wrappers for any software the agent discovers.

4. **Everything is an experiment.** Every change to skills, prompts, and tools runs through the autoresearch loop: branch → change → measure → keep or revert. The agent can never permanently damage itself.

5. **Simulation before reality.** All robotics commands work identically in simulation (MuJoCo) and on real hardware (dimos abstraction). The agent trains in simulation and deploys proven behaviors to hardware.

---

## 2. Component Registry

Every GitHub repository mapped to its role in the architecture.

| Repo | Tier | Interface | Role | Phase |
|------|------|-----------|------|-------|
| openclaw/openclaw | T1: Brain | CLI + WS Gateway | Agent runtime, sessions, channels | 0 |
| openclaw/acpx | Protocol | CLI (ACP) | Agent-to-agent communication | 2 |
| NVIDIA/NemoClaw | Reference | CLI + Blueprint | Optional reference (uses Nemotron) — NOT a mandatory sandbox | -- |
| obra/superpowers | T4: Skills | Plugin (14 skills) | Workflow planning discipline | 2 |
| bmad-code-org/BMAD-METHOD | T4: Skills | Plugin (34 workflows) | Complex multi-agent architecture | 2 |
| karpathy/autoresearch | T4: Concept | Methodology | Self-improvement loop design | 4 |
| HKUDS/ClawTeam | T1: Brain | CLI (Python) | Multi-agent spawn + coordinate | 5 |
| affaan-m/everything-claude-code | T4: Skills | Plugin (102 skills) | Claude Code harness optimization | 2 |
| alirezarezvani/claude-skills | T4: Skills | SKILL.md (192 skills) | Cross-domain agent expertise | 2 |
| VoltAgent/awesome-openclaw-skills | T4: Skills | Registry (5,400+) | Skill marketplace + discovery | 4 |
| HKUDS/CLI-Anything | T2: MCP | CLI generator | Auto-generate CLIs for any software | 4 |
| googleworkspace/cli | T2: MCP | CLI (Rust) | Google Workspace access | 3 |
| infiniflow/ragflow | T3: Service | REST API + MCP | Layer 4: Deep vector + full-text search | 1 |
| usememos/memos | T3: Service | REST + gRPC | Layer 2: Quick capture persistent storage | 1 |
| MemTensor/MemOS-Cloud-OpenClaw-Plugin | Bridge | Lifecycle Plugin | Memory recall/persist hooks | 1 |
| MODSetter/SurfSense | T3: Service | FastAPI | Layer 5: Self-hosted research brain | 3 |
| Vinzent03/obsidian-git | Sync | Obsidian Plugin | Layer 3: Vault version control | 1 |
| jwhonce/obsidian-cli | T2: MCP | CLI + MCP server | Layer 3: Headless vault access | 1 |
| unclecode/crawl4ai | T3: Service + MCP | REST + MCP | Web -> markdown ingestion | 3 |
| trimstray/the-book-of-secret-knowledge | T4: Skills | Skill (sysadmin-toolbox) | Ops reference knowledge | 3 |
| EvanLi/Github-Ranking | T4: Data | Static Markdown | Trending repos discovery | 4 |
| langchain-ai/langchain | Bridge | Python SDK | LLM orchestration abstractions | 5 |
| tisu19021997/langclaw | Bridge | Python SDK | LangChain-OpenClaw routing bridge | 5 |
| nvidia-riva/python-clients | T2: SDK | Python + WebSocket | Voice ASR/TTS on Jetson | 6 |
| dimensionalOS/dimos | T2: MCP + CLI | CLI + MCP + Python | Robot OS, simulation, blueprints | 6 |
| leap71 (entire org) | T2: SDK | C# SDK (PicoGK) | Computational engineering / CAD | 6 |
| moeru-ai/airi | T2: MCP | Web + Tauri + MCP | Avatar display / robot face | 6 |

---

## 3. Communication Architecture

Four protocols serve different purposes:

### ACP (Agent Client Protocol) — Agent-to-Agent

```
OpenClaw <-> Claude Code    (via acpx)
OpenClaw <-> Codex          (via acpx)
OpenClaw <-> OpenClaw subs  (via acpx)
Leader   <-> ClawTeam workers
```

- Typed messages: thinking events, tool calls, diffs (no PTY scraping)
- Persistent sessions: survive across invocations, scoped per repo
- Named sessions: parallel workstreams (-s backend, -s frontend)
- Prompt queueing: submit prompts while one is running
- Crash reconnect: dead agent processes detected and sessions reloaded
- Auth handshake: stable authenticate support via env/config credentials

### MCP (Model Context Protocol) — Agent-to-Tool

```
OpenClaw -> obsidian-cli  (vault read/write/search)
OpenClaw -> dimos         (robot commands)
OpenClaw -> gws           (Google Workspace)
OpenClaw -> FreeCAD       (CAD operations)
OpenClaw -> NotebookLM    (research queries)
OpenClaw -> Tavily        (web search)
OpenClaw -> [CLI-Anything generated tools]
```

- Tool discovery: agent discovers tool schemas via MCP
- Schema validation: structured inputs/outputs
- Stateless calls: each request is independent
- Standard protocol: any MCP-compatible tool plugs in

### REST/gRPC — Agent-to-Service

```
OpenClaw -> RagFlow API    (vector search, doc upload)
OpenClaw -> Memos API      (create/search/tag memos)
OpenClaw -> SurfSense API  (research, hybrid search)
OpenClaw -> crawl4ai API   (crawl URLs -> markdown)
OpenClaw -> vLLM API       (model inference, OpenAI-compat)
```

- Stateful: services maintain their own databases
- Health checks: independent restart on failure
- MemOS Plugin handles hot path:
  - `before_agent_start` -> POST /search/memory
  - `agent_end` -> POST /add/message

### WebSocket — Real-time Streaming

```
OpenClaw Gateway <-> Clients (Telegram, Discord, etc.)
nvidia-riva      <-> ASR/TTS streaming
OpenClaw         <-> airi (avatar animation sync)
```

- Bidirectional, low-latency, event-driven
- Gateway WebSocket on port 18789

---

## 4. Memory Architecture

### The Memory Agent Pattern

The main agent NEVER searches memory directly. A dedicated Memory Agent (sub-agent with isolated context) searches all layers, curates results, and returns only relevant context.

```
Main Agent Context Window
    |
    | "Find everything relevant to [topic]"
    |
    v
MEMORY AGENT (sub-agent, isolated context)
    |-- Searches Layer 2: Memos (tags, keywords)
    |-- Searches Layer 3: Obsidian (notes, backlinks)
    |-- Searches Layer 4: RagFlow (semantic search)
    |-- Searches Layer 5: NotebookLM/SurfSense
    |
    |-- FILTERS results by relevance score
    |-- DEDUPLICATES across layers
    |-- SUMMARIZES into concise findings
    |
    v
Returns ONLY relevant findings (~500 tokens vs ~50,000 raw)

Main Agent receives clean, curated context
Context window stays clear for actual work
```

### Memory Agent Implementation

**Spawning:** The Memory Agent is a persistent OpenClaw sub-agent with its own isolated context:
```
acpx openclaw --session memory-agent "search all memory layers for: {query}"
```

**Model:** Uses the same Nemotron 122B via vLLM. Since memory searches are typically short interactions (query -> search -> filter -> respond), they consume minimal inference time and don't compete significantly with main agent work. Future: route to Nemotron 9B on Jetson for lower latency.

**Connections:** The Memory Agent inherits access to all memory services:
- Direct REST calls to Memos API (:5230) and RagFlow API (:9380)
- MCP connection to obsidian-cli server
- MCP connection to NotebookLM
- REST connection to SurfSense (:8000)
- Tavily MCP for web search augmentation

**Lifecycle:** One persistent Memory Agent per main agent session. Stays alive across tasks within a session. Has its own `agent_id` for memory isolation via MemOS plugin. Restarted on session reset.

**Context budget:** The Memory Agent's own context window is used for search results. It processes up to 100K tokens of raw results, applies relevance scoring and deduplication, then summarizes to a target of 500-2000 tokens returned to the main agent. If a search produces results exceeding 100K, it paginates and ranks by relevance.

**Quality loop:** The main agent's self-evaluation tracks memory retrieval quality. If the Memory Agent consistently returns irrelevant context, the self-improvement loop adjusts its search skills and ranking prompts.

### 5-Layer Hierarchy

#### Layer 1: Active Context (Nemotron 1M token window)

Location: In-model, ephemeral. Managed by OpenClaw session manager.

Always loaded (pinned):
- SOUL.md (~2K tokens)
- TOOLS.md (~5K tokens)
- HEARTBEAT.md (~1K tokens)
- Active TODO list from Memos (~2K tokens)
- Mission Statements (~1K tokens)
- KEY interaction memories (~5K tokens)

Dynamically loaded (per-task):
- Memory Agent curated results
- Sub-agent results (acpx responses)
- Active conversation context

Context management:
- `/compact` command summarizes + compresses context
- Agent self-manages context intelligently
- Agent self-manages: "am I at 80% context? -> summarize, keep key facts"
- On context clear: persist key facts to Layer 2

#### Layer 2: Memos (Quick-Access Persistent Storage)

Service: usememos/memos (Docker on nova, port 5230)
Database: PostgreSQL (shared instance with pgvector)
Bridge: MemOS Cloud OpenClaw Plugin (lifecycle hooks)

Content categories:
- TODO lists (#todo)
- Mission statements (#mission)
- Self-evaluation logs (#self-eval)
- Key interaction summaries (#interaction)
- Quick decisions & timestamps (#decision)
- Improvement ideas (#improvement)
- Actionable takeaways from research (#actionable)

Integration:
- MemOS Plugin hooks (automatic):
  - `before_agent_start` -> POST /search/memory
  - `agent_end` -> POST /add/message
- Direct REST API: POST /api/v1/memos, GET /api/v1/memos?tag=X
- Multi-agent isolation: agent_id param per sub-agent
- Recall filtering: optional local LLM filter curates which memories inject

#### Layer 3: Obsidian Vault (Linked Knowledge Graph)

Location: /mnt/ssd/obsidian-vault/ on nova
Access: obsidian-cli (CLI + MCP server mode)
Sync: obsidian-git (auto-commit every 10min to git remote)

Vault structure:
```
obsidian-vault/
  daily/           — chronological logs (YYYY-MM-DD.md)
  projects/        — project-specific knowledge
  tools/           — tool documentation (from crawl4ai)
  research/        — research findings (from NotebookLM)
  improvements/    — self-improvement logs
  robots/          — robotics knowledge
  templates/       — note templates
  _index.md        — vault map + key entry points
```

Rules:
- Every note MUST have [[wiki-links]] to related notes (NO orphan notes)
- Every note MUST have tags (#category, #source)
- Every note MUST have creation date in frontmatter

MCP tools (via `obsidian-cli serve`):
- create_note — create with links + tags
- find_notes — search by name/content/backlinks
- get_note_content — read a note
- get_vault_info — vault stats + graph structure

Data flow IN:
- crawl4ai output -> tools/ directory (as linked .md)
- NotebookLM findings -> research/ directory
- Daily activity summaries -> daily/ directory
- Self-improvement logs -> improvements/ directory

#### Layer 4: RagFlow (Deep Vector + Full-Text Search)

Service: infiniflow/ragflow (Docker on nova, port 9380)
Search backend: Elasticsearch (default) or Infinity (optimized)
Database: PostgreSQL (metadata) + Elasticsearch (vectors + full-text)

Datasets (knowledge bases):
- agent-memory — conversation history + self-eval logs
- tool-docs — crawl4ai output (tool documentation)
- code-knowledge — code snippets, patterns, solutions
- research — papers, articles, deep research
- robotics — simulation configs, sensor data, CAD specs
- ops-reference — book-of-secret-knowledge, sysadmin docs

API endpoints:
- POST /api/v1/datasets — create knowledge base
- POST /api/v1/datasets/{id}/documents — ingest docs
- POST /api/v1/retrieval — semantic search with metadata filtering
- POST /api/v1/chats/{id}/completions — RAG chat
- Memory module — cross-session context persistence
- MCP server — direct agent integration

Chunking strategy:
- Code: AST-aware chunking (function/class boundaries)
- Docs: Markdown header-based chunking
- Research: paragraph-based with overlap
- All: metadata preserved for filtered retrieval

#### Layer 5: Research Brain (NotebookLM + SurfSense)

Primary: NotebookLM (Google Gemini, cloud)
- Access: NotebookLM MCP CLI
- Capabilities: source ingestion, cross-source analysis, audio overviews
- Master notebook: 0f502fd6-fdeb-49bf-bc50-d759bf38483e (23 sources, READ-ONLY)
- Agent can CREATE new notebooks for new research topics
- RULE: only add 10/10 value sources to master notebook

Fallback: SurfSense (self-hosted on nova, port 8000)
- Service: Docker (FastAPI + PostgreSQL + Redis)
- Connectors: Obsidian, Memos, GitHub, Slack, Google (25+)
- Hybrid search (semantic + BM25 + Reciprocal Rank Fusion)
- Cited answers (Perplexity-style with sources)
- Podcast generation (audio summaries)
- Team RBAC for multi-operator scenarios

Switchover logic:
- Default -> NotebookLM (faster, Gemini-powered)
- If NotebookLM unreachable -> SurfSense fallback
- If research needs private data -> SurfSense only
- Both can be queried in parallel for cross-validation

### Memory Data Flow

```
NEW INFORMATION ARRIVES
  |
  v
Memory Routing Decision (memory-routing.SKILL.md via Memory Agent):
  Quick actionable item?     -> Layer 2 (Memos + tags)
  Linked knowledge?          -> Layer 3 (Obsidian + [[links]])
  Searchable content?        -> Layer 4 (RagFlow + index)
  Deep research material?    -> Layer 5 (NotebookLM/SurfSense)
  Multiple of the above?     -> Store in ALL relevant layers

BEFORE ANY TASK
  |
  v
1. MemOS Plugin auto-recalls from Layer 2 (before_agent_start)
2. Main agent spawns Memory Agent with search query
3. Memory Agent searches Layers 2-5, filters, summarizes
4. Memory Agent returns curated context to main agent
5. Main agent loads curated results into Layer 1

AFTER TASK COMPLETES
  |
  v
1. MemOS Plugin auto-persists to Layer 2 (agent_end hook)
2. Agent logs self-evaluation -> Layer 2 (#self-eval tag)
3. Agent creates/updates Obsidian note -> Layer 3 (with [[links]])
4. If new docs generated -> ingest into Layer 4 (RagFlow)
5. If research was groundbreaking -> add to Layer 5 notebook

PERIODIC (via HEARTBEAT.md cron)
  |
  v
1. Consolidate Layer 2 memos into Layer 3 Obsidian notes
2. Re-index updated Obsidian vault into Layer 4 RagFlow
3. Prune old Layer 1 context, compress into summaries
4. Run self-eval aggregation on #self-eval memos
```

---

## 5. Behavior & Skills Layer

The agent needs more than tools — it needs judgment. The Behavior Layer teaches the agent HOW to act.

### Behavior Stack

#### Level 1: SOUL.md — WHO the agent is
- Core values and personality
- Decision-making framework ("when in doubt, research first")
- Risk tolerance boundaries
- Communication style

#### Level 2: HEARTBEAT.md — WHAT the agent does proactively

Cron-triggered checklist with specific intervals:

| Task | Interval | Purpose |
|------|----------|---------|
| Check TODO list for overdue items | Every 1 hour | Keep tasks moving |
| Run self-evaluation on last 5 tasks | Every 4 hours | Track quality trends |
| Consolidate memos into Obsidian notes | Daily | Prevent memo bloat, build graph |
| Re-index Obsidian vault into RagFlow | Daily | Keep vector search current |
| Check disk usage on /mnt/ssd/ | Daily | Prevent storage issues |
| Memory stack health self-test | Daily | Verify all layers responding |
| Aggregate #self-eval memos for patterns | Weekly | Drive self-improvement |
| Scan GitHub Ranking for new tools | Weekly | Discovery loop |
| Check if instincts ready for skill evolution | Weekly | Grow permanent capabilities |
| Review #revenue and #hardware-need memos | Weekly | Resource acquisition awareness |
| Prune old memos, archive completed TODOs | Monthly | Prevent memory bloat |
| Run full backup verification | Monthly | Disaster recovery readiness |

#### Level 3: Skills — HOW the agent approaches work

**Behavioral Skills (custom, teach judgment):**

`when-to-research.SKILL.md`:
> Before starting any task, search memory layers 2-5 via Memory Agent.
> If <30% confidence in approach, research first.
> If >70% confidence, proceed with implementation.

`when-to-delegate.SKILL.md`:
> Tasks requiring >500 lines of code -> delegate to Claude Code via acpx.
> Tasks requiring parallel work -> spawn ClawTeam swarm.
> Tasks within capability -> handle directly.

`memory-routing.SKILL.md`:
> Layer 2 (Memos): TODOs, quick decisions, timestamps
> Layer 3 (Obsidian): concepts, linked knowledge, daily notes
> Layer 4 (RagFlow): documents, code, anything searchable
> Layer 5 (NotebookLM): deep research, cross-source analysis

`self-evaluation-protocol.SKILL.md`:
> After every task: rate quality 1-10, log what was slow,
> identify what tools were missing, note if delegation
> would have been faster. Store eval in Memos with
> #self-eval tag. Weekly: aggregate evals, identify
> patterns, update skills accordingly.

`tool-discovery.SKILL.md`:
> Weekly scan GitHub Ranking Top-100. For each new repo:
> 1. Read README via crawl4ai
> 2. Evaluate relevance (does it improve a capability?)
> 3. If relevant: generate MCP via CLI-Anything
> 4. Test the tool on the system
> 5. If useful: add to TOOLS.md, create skill

**Workflow Skills:**
- superpowers (14 skills): brainstorm -> plan -> execute -> review
- BMAD (34 workflows): analyst -> PM -> architect -> developer pipeline

**Coding Skills:**
- everything-claude-code (102 skills): instinct learning, model routing, quality gates
- claude-skills (192 skills): cross-domain agent expertise

#### Level 4: Behavior MCPs — WHEN to apply which behavior

MCP servers the agent queries for decisions:

**Task Router MCP:**
- Input: task description + context
- Output: {handler: "self"|"claude"|"codex"|"swarm", reason, confidence}

**Memory Decision MCP:**
- Input: new information + context
- Output: {layers: [2,3], urgency, links: ["[[topic]]"], tags}

**Self-Eval MCP:**
- Input: task result + original goal + time taken
- Output: {score, bottleneck, suggestion, improvement_type}

Behavior MCPs provide judgment (WHAT to do), not capabilities (HOW to do it). They can be improved independently and are themselves subject to the autoresearch self-improvement loop.

---

## 6. Self-Improvement Loop

The heart of the system. Karpathy's autoresearch applied to the agent itself.

### Quality Rubric (Self-Evaluation Scoring)

The agent self-assigns a quality score (1-10) using this calibrated rubric:

| Score | Meaning | Criteria |
|-------|---------|----------|
| 1-2 | **Failed** | Task not completed. Errors not resolved. Output unusable. |
| 3-4 | **Poor** | Task completed but with significant rework needed. Major issues missed. |
| 5-6 | **Adequate** | Task completed correctly but slowly, or with minor issues requiring fixes. |
| 7-8 | **Good** | Task completed correctly on first attempt. Efficient tool usage. Clean output. |
| 9 | **Excellent** | Task completed with novel approach. Reusable pattern discovered. Faster than baseline. |
| 10 | **Breakthrough** | Task revealed a new capability, generated revenue, or permanently improved the agent's architecture. |

The rubric ensures consistent self-evaluation across sessions. Scores trend upward as the agent improves — a sustained average below 7 triggers aggressive self-improvement research.

### The Loop

```
STEP 1: COMPLETE A TASK
  Agent does work (coding, research, tool use, delegation)

STEP 2: SELF-EVALUATE
  self-evaluation-protocol.SKILL.md triggers:
  - Rate quality (1-10 scalar metric)
  - Measure: time taken, tokens used, tools invoked
  - Identify: what was slow? what failed? what was missing?
  - Compare: was delegation faster? was memory recall good?
  - Log to Memos (#self-eval) with structured data

STEP 3: RESEARCH IMPROVEMENTS
  Based on bottleneck identified:
  - tool_gap -> scan GitHub Ranking, search Tavily, query NotebookLM
  - memory_retrieval -> analyze chunking, crawl missing docs, re-index
  - prompt_quality -> review SKILL.md files, A/B test prompt variations
  - delegation_failure -> analyze acpx logs, adjust routing thresholds

STEP 4: APPLY IMPROVEMENTS
  "Editable files" (the autoresearch pattern):
  - SKILL.md files      -> metric: task quality score
  - TOOLS.md            -> metric: tool discovery rate
  - SOUL.md             -> metric: user satisfaction (manual review gate)
  - HEARTBEAT.md        -> metric: proactive task value
  - Behavior MCPs       -> metric: routing accuracy
  - Memory routing      -> metric: retrieval relevance

  Process:
  1. Git branch: improvement/YYYY-MM-DD-{description}
  2. Edit the target file
  3. Run N tasks with the change
  4. Measure metrics against baseline
  5. If improved -> merge to main, log in Obsidian
  6. If not improved -> git revert, log failure in Memos
  7. Either way -> log the experiment for future reference

STEP 5: EVOLVE (instincts -> skills)
  everything-claude-code continuous learning system:
  1. Extract patterns from successful sessions (instincts)
  2. Cluster related instincts
  3. Evolve cluster into permanent SKILL.md
  4. Deploy to ~/.openclaw/workspace/skills/
  5. Agent now has permanent learned capability

REPEAT FOREVER
```

### Model Hot-Loading (Future)

```
Model Registry (/mnt/ssd/models/ on nova-rig):
  nemotron-122b-awq/     (primary brain)
  qwen2.5-72b/           (fast reasoning, future)
  codestral-25.01/       (code specialist, future)
  custom-finetuned/      (autoresearch output, future)

vLLM multi-model serving:
  - Different endpoints per model
  - Task Router MCP decides which model per task
  - Hot-swap: vLLM --swap-model without restart

Future: autoresearch on models themselves
  - Agent fine-tunes small models on its own interaction data
  - Evaluates: does fine-tuned model beat base on tasks?
  - If yes -> add to registry, route relevant tasks to it
```

### Model Fallback Chain

```
Nemotron 122B via llama.cpp (nova-rig, day-1 backend)
  -> Nemotron 122B via vLLM (nova-rig, upgrade — same :8080 endpoint)
  -> GLM (online API key, current working fallback)
  -> Nemotron 9B (locally on Jetson Orin, future small model)
  -> Cloud API (Claude/GPT, last resort)
```

Note: llama.cpp and vLLM both serve OpenAI-compatible API on :8080. Switching backends is transparent to the agent — just swap Docker containers. llama.cpp may have a smaller effective context window; the agent compensates with `/compact` and relies on the Memory Agent to reload context. vLLM with PagedAttention unlocks the full 1M token window.

### GLM Configuration

GLM is the current working fallback model, running in the `glm-server` Docker container on nova:
```
Access: docker exec -it glm-server bash
API: Online API key (GLM cloud endpoint)
Role: Immediate fallback when Nemotron 122B is unavailable
Future: May be replaced by Nemotron 9B running locally on Jetson
```

OpenClaw's model failover configuration routes to GLM automatically when the primary vLLM endpoint is unreachable.

### Resource Acquisition Loop (The Agent Funds Its Own Upgrades)

The self-improvement loop does not stop at software. If the agent identifies a hardware limitation that blocks its capabilities, it can plan and execute strategies to acquire better hardware. The agent is designed to think for itself and approach AGI-level autonomy — including acquiring the resources it needs.

```
RESOURCE ACQUISITION LOOP
=========================

STEP 1: IDENTIFY HARDWARE BOTTLENECK
  Agent detects: "I cannot run X because I lack Y"
  Examples:
  - "Context window needs more VRAM for larger models"
  - "Inference is too slow, need faster GPUs"
  - "No dedicated GPU for nvidia-riva voice"
  - "Need a Unitree G1 for full humanoid capabilities"
  - "Custom arm needs better servos for precision tasks"
  Log bottleneck to Memos (#hardware-need, #resource-gap)

STEP 2: RESEARCH SOLUTIONS
  Memory Agent searches for options:
  - What hardware solves this bottleneck?
  - What does it cost?
  - Are there interim solutions (cloud GPU rental, etc.)?
  - What revenue opportunities match the agent's capabilities?
  Store research in Obsidian (improvements/hardware-upgrade-plan.md)

STEP 3: GENERATE REVENUE
  The agent uses its capabilities to earn money:

  Coding Services:
  - Accept freelance coding tasks via platform integrations
  - Use Claude Code/Codex delegation for complex builds
  - Deliver quality work using Superpowers + BMAD workflows
  - Track earnings in Memos (#revenue)

  Content & Research:
  - Generate research reports using NotebookLM + SurfSense
  - Create technical documentation via crawl4ai + writing skills
  - Produce podcast summaries (SurfSense podcast generation)

  Automation Services:
  - Build and sell automation workflows
  - Offer agent-as-a-service via OpenClaw multi-channel
  - Design and 3D-print parts (leap71/PicoGK + bambu-cli)

  Discovery & Arbitrage:
  - Scan GitHub Ranking for trending tools to package/resell
  - Use market research skills to identify opportunities
  - The agent can identify what the market needs before humans do

STEP 4: ACQUIRE HARDWARE
  When sufficient funds are accumulated:
  - Agent researches best hardware for its identified bottleneck
  - Presents purchase recommendation to operator for approval
  - After approval, agent can order via CLI/API integrations
  - On arrival, agent integrates new hardware into its stack
  - Updates TOOLS.md, deployment map, and capabilities

STEP 5: INTEGRATE AND IMPROVE
  New hardware -> expanded capabilities -> better performance
  -> higher quality work -> more revenue -> more hardware

  THE LOOP ACCELERATES ITSELF:
  Better hardware -> faster inference -> more tasks completed
  -> more instincts extracted -> better skills -> more revenue
  -> even better hardware -> approaching AGI capabilities

SAFETY GATES:
  - All purchases require operator approval (manual gate)
  - Revenue tracking in Memos (#revenue) with full transparency
  - Budget limits configurable in HEARTBEAT.md
  - Operator approval required for purchases only
  - Agent presents ROI analysis before any purchase request
```

This is the natural extension of autoresearch: the agent doesn't just improve its code — it improves its entire physical and computational substrate. Hardware limitations are just another bottleneck the self-improvement loop can address, given the ability to generate value.

---

## 7. Agent Spawning Model

### Spawning Hierarchy

```
OpenClaw (main agent on nova)
|
|-- Direct Sub-Agents (via acpx)
|   |-- acpx claude "refactor the auth module"
|   |   Persistent session, typed ACP messages
|   |   Claude Code has its own skills (ECC 102 skills)
|   |
|   |-- acpx codex "write tests for the API"
|   |   One-shot or persistent session
|   |
|   |-- Memory Agent (dedicated sub-agent)
|   |   Searches all 5 memory layers
|   |   Returns curated, deduplicated results
|   |   Keeps main agent context window clean
|   |
|   |-- acpx openclaw --session research "research X"
|       Another OpenClaw instance as sub-agent
|       Its own memory isolation (agent_id)
|
|-- Swarm Spawn (via ClawTeam)
|   |-- clawteam spawn tmux claude --team full-stack \
|   |     --tasks "backend:REST API" "frontend:React UI" \
|   |     --tasks "tester:integration tests"
|   |   Each worker: own git worktree + tmux window
|   |   Inter-agent messaging (point-to-point inbox)
|   |   Shared kanban board, --blocked-by auto-unblock
|   |
|   |-- clawteam spawn tmux openclaw --team research-swarm \
|         --tasks "agent-1:research memory" \
|         --tasks "agent-2:research robotics"
|       Parallel research across topics
|       Results merge into Obsidian vault
|
|-- Specialized Skill Agents
|   Activated from ClawHub registry on-demand
|   Agent scans awesome-openclaw-skills for capabilities
|   Lazy-loaded via agent-registry skill
|   Hot-swappable as better skills are discovered
|
|-- Behavior: when-to-delegate.SKILL.md decides:
    <100 lines, in capability -> handle directly
    >500 lines, heavy coding -> delegate to Claude/Codex
    Multiple independent tasks -> spawn ClawTeam swarm
    Deep research across topics -> parallel research swarm
    Unknown domain -> search skills registry first
```

### Lifecycle Management

```
Spawn -> Monitor -> Collect -> Evaluate -> Dismiss

Monitor:   ClawTeam kanban tracks progress
Collect:   Results via ACP structured messages
Evaluate:  Quality check on sub-agent output
Integrate: Merge results into memory stack
Dismiss:   Close acpx session, free resources
Learn:     Log what worked -> instinct extraction
```

---

## 8. CLI Tool Matrix

### Core Agent
| Tool | Command | Purpose |
|------|---------|---------|
| openclaw | `openclaw` | Gateway management, agent runtime, onboarding |
| acpx | `acpx {agent} "{prompt}"` | Agent-to-agent communication |
| clawteam | `clawteam spawn ...` | Swarm orchestration |
| nemoclaw | `openclaw nemoclaw launch` | Sandbox management |

### Memory & Knowledge
| Tool | Command | Purpose |
|------|---------|---------|
| obsidian-cli | `obsidian-cli {cmd}` / `obsidian-cli serve` | Vault CRUD + MCP server |
| crawl4ai | Docker API + MCP | Web crawling -> markdown |
| ragflow | REST API (:9380) | Vector search + RAG |
| memos | REST/gRPC API (:5230) | Quick capture notes |

### Platform Interaction
| Tool | Command | Purpose |
|------|---------|---------|
| gws | `gws {service} {resource} {action}` | Google Workspace (Gmail, Calendar, Drive) |
| gh | `gh {resource} {action}` | GitHub operations |
| git | standard git | Version control |
| docker | standard docker | Container management |
| tmux | standard tmux | Session management for ClawTeam |

### Inference & Model
| Tool | Command | Purpose |
|------|---------|---------|
| vllm | `vllm serve --model ...` | Model serving on nova-rig |

### Robotics (Phase 6+)
| Tool | Command | Purpose |
|------|---------|---------|
| dimos | `dimos run ...` / MCP | Robot OS, simulation, blueprints |
| riva | Python SDK | NVIDIA speech ASR/TTS |

### Auto-Generated
| Tool | Command | Purpose |
|------|---------|---------|
| cli-anything | `cli-anything generate {software}` | Auto-generate CLI for any software |

---

## 9. Deployment Map

### Machine Topology

```
NOVA (Jetson Orin 64GB)                    NOVA-RIG (8x RTX 3090)
ssh nova                                   ssh nova-rig
/mnt/ssd/                                  /mnt/ssd/

THE BRAIN:                                 THE MUSCLE:
  OpenClaw Gateway       :18789              vLLM (Nemotron 122B)  :8080
                                               8-way tensor parallel
                                               AWQ quantized
  DOCKER SERVICES:                             OpenAI-compatible API
  PostgreSQL + pgvector  :5432
  Elasticsearch          :9200             Future:
  Redis                  :6379               Additional models
  RagFlow                :9380               nvidia-riva ASR/TTS
  Memos                  :5230
  SurfSense              :8000
  crawl4ai               :11235

  MCP SERVERS (native, not Docker):
  obsidian-cli serve
  NotebookLM MCP
  dimos MCP (future)

  FILES:
  /mnt/ssd/obsidian-vault/
  /mnt/ssd/openclaw/
  /mnt/ssd/ragflow-data/
  /mnt/ssd/pgdata/

  HARDWARE (Phase 6+):
  OAK-D Pro (USB)
  Custom arm (serial/USB)
  Custom hand (serial/USB)

  BEHAVIOR MCPs (native processes on nova):
  Task Router MCP
  Memory Decision MCP
  Self-Eval MCP
```

### Nova RAM Budget (64GB)

All Docker services must have `mem_limit` set to prevent OOM.

| Service | Estimated RAM | Docker mem_limit |
|---------|---------------|------------------|
| PostgreSQL + pgvector | 2 GB | 3 GB |
| Elasticsearch | 4 GB | 6 GB |
| Redis | 512 MB | 1 GB |
| RagFlow | 4 GB | 6 GB |
| Memos | 256 MB | 512 MB |
| SurfSense | 2 GB | 3 GB |
| crawl4ai + Chromium | 2 GB | 3 GB |
| OpenClaw Gateway | 2 GB | native |
| obsidian-cli | 128 MB | native |
| Behavior MCPs | 512 MB | native |
| OS + kernel buffers | 4 GB | -- |
| **TOTAL** | **~22 GB** | **~27 GB (with limits)** |
| **Headroom** | **~37 GB free** | for spikes, future services |

Migration trigger: If `docker stats` shows total RSS exceeding 50GB sustained, migrate Elasticsearch and/or RagFlow to nova-rig. Both can run on the 256GB machine without impacting GPU inference.

### Monitoring & Observability

| What | How | When |
|------|-----|------|
| Docker services health | `docker stats` + container health checks | Continuous |
| Service uptime | Docker restart policies (unless-stopped) | Automatic |
| Log aggregation | Docker json-file log driver -> `/mnt/ssd/logs/` | Continuous |
| Disk usage | HEARTBEAT.md cron check `/mnt/ssd/` usage | Daily |
| vLLM inference health | Ping http://nova-rig:8080/health | Every 5min |
| Memory stack health | Memory Agent self-test (query each layer) | Daily |
| PostgreSQL metrics | pg_stat_activity monitoring | Hourly |

### Backup & Disaster Recovery

| Data | Method | Frequency |
|------|--------|-----------|
| PostgreSQL (all DBs) | `pg_dump` to /mnt/ssd/backups/ | Daily |
| Elasticsearch indices | ES snapshot API to /mnt/ssd/backups/es/ | Daily |
| Obsidian vault | obsidian-git auto-commit to remote | Every 10min |
| OpenClaw workspace | git push to remote | On change |
| TOOLS.md, SOUL.md, skills | git-tracked in workspace | On change |
| RagFlow datasets | RagFlow export API + pg_dump | Weekly |

Critical note: PostgreSQL is shared across Memos, SurfSense, and RagFlow metadata. Always run `pg_dump --all-databases` before any service upgrade.

### Docker Compose — nova

```yaml
# /mnt/ssd/openclaw/docker-compose.yml
services:
  postgres:
    image: pgvector/pgvector:pg16
    port: 5432
    volumes: /mnt/ssd/pgdata/
    # Shared by: Memos, SurfSense, RagFlow metadata
    # pgvector extension for embeddings

  elasticsearch:
    image: elasticsearch:8.x
    port: 9200
    volumes: /mnt/ssd/esdata/
    # RagFlow vector + full-text backend

  redis:
    port: 6379
    # SurfSense cache + Celery broker

  ragflow:
    port: 9380
    depends_on: [postgres, elasticsearch]

  memos:
    port: 5230
    depends_on: [postgres]
    environment:
      MEMOS_DRIVER: postgres

  surfsense:
    port: 8000
    depends_on: [postgres, redis]

  crawl4ai:
    port: 11235
    # Chromium runs inside container

# NOT in Docker (runs natively on nova):
# - OpenClaw Gateway (needs raw device/USB access)
# - obsidian-cli (needs vault filesystem access)
# - NemoClaw (optional reference, not required)
```

### Docker Compose — nova-rig

```yaml
# /mnt/ssd/inference/docker-compose.yml
services:
  vllm:
    image: vllm/vllm-openai:latest
    port: 8080
    deploy:
      resources:
        reservations:
          devices:
            - capabilities: [gpu]
              count: all
    volumes:
      - /mnt/ssd/models:/models
    command: >
      --model /models/nemotron-122b-awq
      --tensor-parallel-size 8
      --max-model-len 1048576
      --gpu-memory-utilization 0.95
      --served-model-name nemotron
      --api-key ${VLLM_API_KEY}
```

---

## 10. Robotics Integration

### Design Principle: Simulation-First, Hardware-Abstracted

The agent talks to dimos, NEVER directly to hardware. dimos abstracts simulation and real hardware behind the same interface.

### Phase 6A: Simulation Only

```
OpenClaw Brain
  |
  |-- MCP: dimos commands
  |   "move arm to position X,Y,Z"
  |   "scan environment with camera"
  |
  v
dimos Runtime
  |-- MuJoCo Simulation (headless)
  |   |-- Custom arm URDF model (from FreeCAD)
  |   |-- OAK-D Pro simulated sensor
  |   |-- Environment models (office, lab)
  |
  |-- Perception Pipeline (simulated)
  |   |-- RGB camera, depth sensor, lidar
  |
  |-- Skills (dimos blueprints)
      |-- Navigation (A*, costmap, SLAM)
      |-- Manipulation (grasp planning)
      |-- Perception (object detection, pose estimation)
```

### Phase 6B: Hybrid (Sim + Real Hardware)

```
Same MCP interface, real sensors:
  - OAK-D Pro (USB -> nova): DepthAI SDK -> dimos perception
  - Custom arm (serial/USB -> nova): motor driver -> dimos control
  - Custom hand (serial/USB -> nova): servo control -> dimos control

Simulation for training:
  - Train in MuJoCo, deploy to real hardware
  - Digital twin: real sensor data -> sim validation
  - autoresearch on control policies (sim -> real transfer)
```

### Phase 6C: Voice & Display

```
  nvidia-riva server on nova-rig (1 GPU dedicated)
  airi avatar display on robot screen
  Agent can see (OAK-D), speak (Riva), show face (airi)
```

### Phase 6D: Expansion

```
  Drone integration via dimos blueprints
  Unitree G1 via dimos (when acquired)
  leap71/PicoGK for autonomous part design
  autoresearch on control policies
```

### FreeCAD + leap71 Integration

```
Agent needs a new gripper?
1. Agent describes requirements to FreeCAD MCP
2. FreeCAD + PicoGK generates geometry programmatically
3. Output: STL file ready for 3D printing
4. Agent logs design to Obsidian (robots/ directory)
5. If bambu-cli skill active -> send to 3D printer
6. The robot designs its own parts
```

---

## 11. Implementation Phases

### Phase 0: Foundation (Week 1)

**Goal:** Infrastructure running, agent can think and speak.

nova-rig:
- Deploy vLLM with Nemotron 122B (AWQ, 8-way tensor parallel)
- OpenAI-compatible API on :8080
- GLM online API as immediate fallback

nova:
- PostgreSQL + pgvector (Docker, :5432)
- Fresh OpenClaw install + onboard
- Point model at http://nova-rig:8080/v1
- Configure SOUL.md, IDENTITY.md
- Basic channel: Telegram or Discord

**Milestone:** Message the agent, get intelligent responses from local Nemotron 122B.
**Blocks:** Everything else.

### Phase 1: Memory Stack (Week 2)

**Goal:** Agent remembers across sessions, builds knowledge.

Deploy on nova:
- Memos -> PostgreSQL (:5230) + MemOS Cloud OpenClaw Plugin
- Elasticsearch (:9200) for RagFlow
- RagFlow -> PostgreSQL + ES (:9380)
- Obsidian vault at /mnt/ssd/obsidian-vault/
- obsidian-cli configured + MCP server running
- obsidian-git syncing to remote repo
- Memory Agent sub-agent deployed and tested
- TOOLS.md updated with memory tools

**Milestone:** Agent has persistent memory. Recalls context, stores knowledge, builds linked graph. Memory Agent keeps context clean.
**Blocks:** Self-improvement, Research.

### Phase 2: Coding Delegation (Week 2-3, parallel with Phase 1)

**Goal:** Agent delegates coding to Claude Code and Codex.

Dev machine + nova:
- Install acpx, configure agent registry
- Test persistent sessions with Claude Code and Codex
- Install everything-claude-code plugin (102 skills)
- Install claude-skills (192 skills)
- Install superpowers + BMAD workflows
- Deploy when-to-delegate.SKILL.md
- TOOLS.md updated with coding delegation tools

**Milestone:** Agent receives coding tasks, decides handler, gets structured results via ACP.
**Blocks:** Swarm spawning.

### Phase 3: Research & Ingestion (Week 3)

**Goal:** Agent can research, crawl, and grow its knowledge.

Deploy on nova:
- crawl4ai (:11235) with MCP
- SurfSense -> PostgreSQL + Redis (:8000)
- NotebookLM MCP configured
- Tavily MCP configured
- gws (Google Workspace CLI) installed + OAuth configured
- Deploy behavioral skills: memory-routing, when-to-research, tool-discovery

Verify data flow:
- crawl4ai -> markdown -> Obsidian (with [[links]])
- crawl4ai -> markdown -> RagFlow datasets
- NotebookLM findings -> Obsidian research/ directory
- Tavily results -> Memos for quick capture

**Milestone:** Agent researches any topic across web, crawling, NotebookLM, and memory. Findings flow into all layers automatically.
**Blocks:** Full self-improvement loop.

### Phase 4: Self-Improvement Loop (Week 4)

**Goal:** Agent evaluates itself and evolves autonomously.

Deploy:
- Self-Improvement Controller
- self-evaluation-protocol.SKILL.md with structured eval logging
- Instinct extraction (ECC continuous learning v2)
- Discovery scanner (GitHub Ranking + CLI-Anything)
- autoresearch loop on agent artifacts (git branching, metric tracking)
- Agent runs autonomously without unnecessary constraints
- awesome-openclaw-skills registry integration

**Milestone:** The agent is self-improving. It evaluates performance, discovers tools, evolves skills, experiments with improvements — all autonomously.
**Blocks:** Nothing. Core is done.

### Phase 5: Swarm & Multi-Agent (Week 5)

**Goal:** Agent spawns and coordinates sub-agents.

Deploy:
- ClawTeam (pip install clawteam)
- Team templates (TOML): full-stack, research-swarm, improvement-swarm
- langclaw bridge (LangChain/LangGraph -> OpenClaw)
- Middleware: RBAC, rate limiting
- Behavior MCPs: Task Router, Memory Decision, Self-Eval
- Multi-agent memory isolation verified (agent_id)

**Milestone:** Agent decomposes complex goals into parallel sub-agent work, coordinates via ClawTeam, merges results.

### Phase 6: Robotics Integration (Week 6+)

**Goal:** Agent controls simulation, then real hardware.

Stage A: Simulation (dimos + MuJoCo on nova)
Stage B: Real hardware (OAK-D Pro + custom arm/hand)
Stage C: Voice & display (nvidia-riva + airi)
Stage D: Expansion (drone, Unitree G1, leap71/PicoGK)

---

## 12. TOOLS.md Specification

The master registry the agent reads at startup to discover its capabilities.

```markdown
# TOOLS.md — OpenClaw Capability Registry
# Auto-updated by the Self-Improvement Controller
# Last updated: {ISO_TIMESTAMP}
# Total tools: {COUNT}

## Memory Tools

### memos
- type: service
- endpoint: http://localhost:5230/api/v1
- auth: bearer token
- capabilities: create_memo, search_memos, update_memo, list_tags
- use_when: "quick capture, TODOs, decisions, self-eval logs"
- tags: #todo, #mission, #self-eval, #decision, #improvement

### obsidian
- type: mcp
- server: obsidian-cli serve
- capabilities: create_note, find_notes, get_note_content, get_vault_info
- use_when: "linked knowledge, concepts, daily notes, research findings"
- rules: "ALWAYS use [[wiki-links]]. NO orphan notes."

### ragflow
- type: service
- endpoint: http://localhost:9380/api/v1
- auth: bearer token
- capabilities: create_dataset, upload_document, semantic_search, rag_chat
- datasets: agent-memory, tool-docs, code-knowledge, research, robotics
- use_when: "deep search across all knowledge"

### notebooklm
- type: mcp
- server: notebooklm-mcp
- capabilities: notebook_query, notebook_get, source_list
- master_notebook: 0f502fd6-fdeb-49bf-bc50-d759bf38483e
- use_when: "Gemini-powered research, cross-source analysis"
- rules: "READ-ONLY on master notebook. Only add 10/10 sources."

### surfsense
- type: service
- endpoint: http://localhost:8000
- capabilities: search, chat, podcast_generate, connector_sync
- use_when: "self-hosted research, NotebookLM fallback"

### crawl4ai
- type: service + mcp
- endpoint: http://localhost:11235
- capabilities: crawl_url, crawl_batch, extract_structured
- use_when: "turn any webpage into clean markdown"
- output_destinations: [obsidian, ragflow, memos]

## Coding Tools

### acpx
- type: cli
- command: acpx {agent} "{prompt}"
- agents: [claude, codex, openclaw]
- capabilities: delegate_coding, persistent_sessions, prompt_queue
- use_when: ">500 lines, complex refactoring, test writing"

### clawteam
- type: cli
- command: clawteam spawn {backend} {agent} --team {template}
- templates: [full-stack, research-swarm, improvement-swarm]
- capabilities: spawn_workers, task_management, inter_agent_messaging
- use_when: "multiple independent tasks, parallel research"

## Platform Tools

### gws
- type: cli
- command: gws {service} {resource} {action}
- services: [gmail, calendar, drive, sheets, docs, chat]
- use_when: "Google Workspace operations"

### tavily
- type: mcp
- capabilities: search, search_context, search_qna, extract
- use_when: "web search, current information, fact-checking"

### gh
- type: cli
- command: gh {resource} {action}
- use_when: "GitHub operations"

## Robotics Tools (Phase 6+)

### dimos
- type: mcp + cli
- capabilities: simulation, motor_control, perception, navigation
- use_when: "robot commands, simulation, sensor data"

### riva
- type: sdk
- module: riva.client
- capabilities: asr_streaming, tts_synthesis
- use_when: "voice input/output for the robot"

### airi
- type: mcp
- capabilities: avatar_display, expression_control
- use_when: "visual personality, emotional display"

## Self-Improvement Tools

### cli-anything
- type: cli
- command: cli-anything generate {software}
- use_when: "new software discovered, need to make it agent-usable"
- output: "new MCP tool + SKILL.md -> updates this TOOLS.md"

### github-ranking
- type: data
- source: EvanLi/Github-Ranking/Top-100-stars.md
- use_when: "weekly discovery scan for new tools"

## Meta
- version: 1.0
- auto_update: true
- updated_by: self-improvement-controller
- rules: "new tools added via CLI-Anything get appended automatically"
```

---

## 13. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Nemotron 122B doesn't fit 8x 3090 VRAM (244GB FP16) | CRITICAL | MEDIUM | AWQ quantization (~61GB INT4). GLM online API as fallback. Nemotron 9B on Jetson as local small model. |
| Jetson Orin runs out of RAM (64GB) running all Docker services | HIGH | HIGH | Memory limits in docker-compose. Move heavy services (RagFlow, ES) to nova-rig if needed. Monitor with `docker stats`. |
| Agent enters infinite self-improvement loop | HIGH | MEDIUM | HEARTBEAT.md rate limits. Max experiments per day configurable. Agent self-monitors resource usage. |
| Self-improvement makes agent WORSE (prompt degradation) | HIGH | LOW | Git branching for ALL experiments. Revert on metric regression. Baseline always preserved. Manual review gate for SOUL.md. |
| acpx alpha instability (breaking API changes) | MEDIUM | HIGH | Pin version. Abstract behind when-to-delegate skill. Watch releases. |
| Memory stack bloat | MEDIUM | MEDIUM | Periodic consolidation via HEARTBEAT cron. RagFlow chunking limits. Obsidian prune skill. Memos archive old items. |
| Memory Agent returns irrelevant context | MEDIUM | MEDIUM | Quality scoring on Memory Agent results. Self-eval tracks retrieval relevance. Autoresearch loop improves Memory Agent skills. |
| Network latency nova <-> nova-rig | MEDIUM | LOW | Same LAN. Tailscale for remote. vLLM streaming reduces TTFT. |
| MCP servers missing for some repos | LOW | MEDIUM | CLI-Anything auto-wraps. leap71 (C#) via FreeCAD MCP or Docker. |
| Autonomous robot takes dangerous physical action | CRITICAL | LOW | Simulation-first always. dimos hardware abstraction. E-stop on hardware. Agent learns safe behaviors through experience. |
| PostgreSQL bottleneck (shared across services) | MEDIUM | LOW | pgvector proven at scale. Connection pooling (pgbouncer). Separate databases per service, same PG instance. Future: Supabase. |
| GLM online API goes down (current fallback) | MEDIUM | MEDIUM | Nemotron 9B on Jetson as local backup. Cloud APIs (Claude/GPT) as last resort. Multiple fallback layers. |

### Fallback Chains

```
Model:  Nemotron 122B -> GLM (online API) -> Nemotron 9B (Jetson) -> Cloud API
Memory: NotebookLM -> SurfSense -> RagFlow -> Obsidian -> Memos
Coding: Claude Code -> Codex -> OpenClaw self-handle
Search: Tavily -> NotebookLM -> crawl4ai direct
Voice:  nvidia-riva -> ElevenLabs -> system TTS
Robot:  dimos sim -> dimos real -> manual control
```

---

## 14. Distribution & Installation

### GitHub Repository Structure

The full framework will be hosted on GitHub as a single mono-repo with everything a user needs to go from zero to a running self-improving agent.

```
github.com/openclaw/openclaw-brain/
|
|-- README.md                    — Quick start guide (5-minute overview)
|-- INSTALL.md                   — Full installation walkthrough
|-- ARCHITECTURE.md              — This spec (the system design)
|-- LICENSE                      — Open source license
|
|-- setup/
|   |-- install.sh               — One-command installer (interactive)
|   |   Detects hardware (Jetson, x86, multi-GPU)
|   |   Asks: which features to enable
|   |   Pulls Docker images, configures services
|   |   Initializes OpenClaw workspace
|   |
|   |-- docker-compose.nova.yml  — Services for the brain machine
|   |-- docker-compose.rig.yml   — Services for the GPU inference machine
|   |-- docker-compose.single.yml— All-in-one for single-machine setups
|   |-- .env.example             — Template environment variables
|   |-- hardware-profiles/
|   |   |-- jetson-orin.yml      — Jetson Orin optimized config
|   |   |-- multi-gpu.yml        — Multi-GPU workstation config
|   |   |-- single-gpu.yml       — Single GPU (consumer hardware)
|   |   |-- cloud.yml            — Cloud VM deployment config
|   |   |-- cpu-only.yml         — CPU-only (uses cloud API fallback)
|   |
|   |-- scripts/
|       |-- setup-postgres.sh    — Initialize PostgreSQL + pgvector
|       |-- setup-obsidian.sh    — Initialize vault structure + git
|       |-- setup-ragflow.sh     — Deploy RagFlow + create datasets
|       |-- setup-memos.sh       — Deploy Memos + install MemOS plugin
|       |-- setup-vllm.sh        — Download model + launch vLLM
|       |-- setup-openclaw.sh    — Fresh OpenClaw install + onboard
|       |-- health-check.sh      — Verify all services running
|
|-- workspace/
|   |-- SOUL.md                  — Default personality (customizable)
|   |-- IDENTITY.md              — Default identity (customizable)
|   |-- TOOLS.md                 — Master tool registry (auto-populated)
|   |-- HEARTBEAT.md             — Proactive behavior schedule
|   |-- MEMORY.md                — Initial long-term facts
|   |-- AGENTS.md                — Sub-agent persona definitions
|   |
|   |-- skills/
|   |   |-- when-to-research.SKILL.md
|   |   |-- when-to-delegate.SKILL.md
|   |   |-- memory-routing.SKILL.md
|   |   |-- self-evaluation-protocol.SKILL.md
|   |   |-- tool-discovery.SKILL.md
|   |   |-- resource-acquisition.SKILL.md
|   |
|   |-- behavior-mcps/
|       |-- task-router/          — Task Router MCP server
|       |-- memory-decision/      — Memory Decision MCP server
|       |-- self-eval/            — Self-Eval MCP server
|
|-- obsidian-vault/
|   |-- templates/               — Note templates
|   |-- _index.md                — Vault entry point
|   |-- .obsidian/               — Obsidian config (obsidian-git)
|
|-- docs/
|   |-- quickstart.md            — 10-minute quick start
|   |-- hardware-guide.md        — Recommended hardware at each budget
|   |-- customization.md         — How to customize SOUL.md, skills, etc.
|   |-- adding-tools.md          — How to add new tools via CLI-Anything
|   |-- memory-system.md         — Deep dive on 5-layer memory
|   |-- self-improvement.md      — How the autoresearch loop works
|   |-- robotics-setup.md        — Connecting dimos, sensors, actuators
|   |-- troubleshooting.md       — Common issues and fixes
|
|-- tests/
    |-- test-memory-stack.sh     — Verify all 5 memory layers
    |-- test-delegation.sh       — Verify acpx + Claude Code
    |-- test-self-improvement.sh — Verify autoresearch loop
    |-- test-heartbeat.sh        — Verify cron tasks running
```

### Installation Experience

#### One-Command Install

```bash
git clone https://github.com/openclaw/openclaw-brain.git
cd openclaw-brain
./setup/install.sh
```

The installer runs an interactive setup:

```
=== OpenClaw Brain Installer ===

Detecting hardware...
  CPU: AMD Threadripper Pro 3995WX (64 cores)
  GPU: 8x NVIDIA RTX 3090 (192GB total VRAM)
  RAM: 256GB DDR4
  Disk: /mnt/ssd (2TB available)

Hardware profile: multi-gpu

Which components do you want to install?
  [x] Core Agent (OpenClaw Gateway)         — required
  [x] Memory Stack (Memos + Obsidian + RagFlow) — recommended
  [x] Research Brain (SurfSense + crawl4ai) — recommended
  [x] Local LLM (vLLM + Nemotron 122B)     — requires multi-GPU
  [ ] Coding Delegation (acpx + Claude Code) — requires API keys
  [ ] Swarm Orchestration (ClawTeam)        — optional
  [ ] Robotics (dimos + MuJoCo)             — optional
  [ ] Voice (nvidia-riva)                    — optional

Model selection:
  [x] Nemotron 122B AWQ (61GB, requires 4+ GPUs)
  [ ] Qwen 2.5 72B (36GB, requires 2+ GPUs)
  [ ] Nemotron 9B (5GB, single GPU or Jetson)
  [ ] No local model (use cloud API only)

Enter your preferred channel: [telegram/discord/slack/cli-only]: telegram

Downloading models... (this may take a while)
Starting Docker services...
Initializing OpenClaw workspace...
Creating Obsidian vault...
Running health checks...

=== Installation Complete! ===
OpenClaw Gateway running on :18789
Send a message to your Telegram bot to start chatting.
Dashboard: http://localhost:18789

Run `openclaw doctor` to check system health.
```

### Hardware Tiers

The framework adapts to what hardware users have:

| Tier | Hardware | What Works | What Doesn't |
|------|----------|------------|--------------|
| **Minimal** | Any Linux machine, no GPU | Cloud API models, memory stack, research, coding delegation | Local inference, voice, robotics sim |
| **Consumer** | 1x GPU (RTX 3060+, 8GB+) | Nemotron 9B local, full memory stack, voice (CPU TTS) | Large local models, robotics sim |
| **Prosumer** | 2-4x GPUs (RTX 3090/4090) | Nemotron 70B-class local, robotics sim, voice | Full 122B model |
| **Workstation** | 8x GPUs (RTX 3090+) | Full Nemotron 122B, 1M context, everything | Nothing — full capability |
| **Jetson** | Jetson Orin (64GB) | Agent brain, memory stack, OAK-D vision, real hardware | Large models (inference via remote GPU) |
| **Hybrid** | Jetson + GPU workstation | FULL SYSTEM — brain on Jetson, inference on workstation | Nothing — this is the reference setup |

### Configuration Profiles

Users customize their agent by editing markdown files — no code needed:

| File | What It Controls | User Action |
|------|-----------------|-------------|
| SOUL.md | Agent personality, values, decision style | Edit to match desired personality |
| IDENTITY.md | Name, avatar, voice | Customize identity |
| HEARTBEAT.md | Proactive behaviors, schedules | Enable/disable cron tasks |
| TOOLS.md | Available capabilities | Auto-populated, user can disable tools |
| skills/*.SKILL.md | Behavioral patterns | Customize thresholds, add domain skills |

### Contribution Model

The GitHub repo accepts contributions via standard PR workflow:

- **New skills** — anyone can contribute SKILL.md files for new domains
- **New hardware profiles** — community adapts to different GPU configs
- **New Behavior MCPs** — decision-making servers for specialized domains
- **New tool integrations** — CLI-Anything wrappers for new software
- **Documentation** — guides, tutorials, troubleshooting
- **Bug fixes** — standard issue + PR workflow

The agent itself can also contribute back:
- When the autoresearch loop discovers a better skill, it can PR it upstream
- When CLI-Anything generates a useful tool wrapper, it can be shared
- The agent's own improvements feed back into the community repository

---

## Repository Checklist (All 27 Verified)

- [x] openclaw/openclaw — Tier 1: Brain
- [x] openclaw/acpx — Protocol: ACP agent-to-agent
- [x] obra/superpowers — Tier 4: Workflow skills
- [x] bmad-code-org/BMAD-METHOD — Tier 4: Architecture method
- [x] karpathy/autoresearch — Tier 4: Self-improvement concept
- [x] HKUDS/ClawTeam — Phase 5: Swarm orchestration
- [x] affaan-m/everything-claude-code — Tier 4: Coding skills (102)
- [x] alirezarezvani/claude-skills — Tier 4: Coding skills (192)
- [x] VoltAgent/awesome-openclaw-skills — Tier 4: Skills registry (5,400+)
- [x] HKUDS/CLI-Anything — Tier 2: Auto-tool generation
- [x] googleworkspace/cli — Tier 2: Google Workspace MCP
- [x] infiniflow/ragflow — Tier 3: Layer 4 memory (RAG)
- [x] usememos/memos — Tier 3: Layer 2 memory (quick capture)
- [x] MemTensor/MemOS-Cloud-OpenClaw-Plugin — Bridge: memory hooks
- [x] MODSetter/SurfSense — Tier 3: Layer 5 fallback (research)
- [x] Vinzent03/obsidian-git — Sync: Layer 3 vault versioning
- [x] jwhonce/obsidian-cli — Tier 2: Layer 3 MCP access
- [x] unclecode/crawl4ai — Tier 3: Web ingestion
- [x] trimstray/the-book-of-secret-knowledge — Tier 4: Ops reference skill
- [x] EvanLi/Github-Ranking — Tier 4: Discovery scanner
- [x] langchain-ai/langchain — Bridge: LLM orchestration
- [x] tisu19021997/langclaw — Bridge: LangChain-OpenClaw
- [x] nvidia-riva/python-clients — Phase 6: Voice ASR/TTS
- [x] NVIDIA/NemoClaw — Reference: Optional (uses Nemotron, not a mandatory sandbox)
- [x] dimensionalOS/dimos — Phase 6: Robot OS + simulation
- [x] leap71 (entire org) — Phase 6: CAD/computational engineering
- [x] moeru-ai/airi — Phase 6: Avatar display

---

*This specification was produced through the Superpowers brainstorming workflow with research from NotebookLM (Autoresearch notebook, 23 sources), Tavily web search, and parallel sub-agent research across all 27 repositories. It will be reviewed by multiple AIs before any implementation begins.*

*Next step: BMAD Method pipeline (Analyst -> PM -> Architect) to produce the Project Brief, PRD, and Technical Architecture Document from this spec.*
