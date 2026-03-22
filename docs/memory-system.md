# Memory System Deep Dive

OpenClaw Brain uses a 5-layer memory hierarchy to manage knowledge across different time scales, access patterns, and levels of structure. This document explains each layer, how they interact, and how to extend the system.

---

## Architecture Overview

```
Layer 1: Active Context          (ephemeral, in-model, 1M tokens)
    |
Layer 2: Memos                   (persistent, fast, tagged notes)
    |
Layer 3: Obsidian                (persistent, linked knowledge graph)
    |
Layer 4: RagFlow                 (persistent, vector + full-text search)
    |
Layer 5: NotebookLM / SurfSense (external research, Gemini-powered)
```

Each layer serves a distinct purpose. Information flows downward for storage and upward for retrieval. The Memory Agent orchestrates search across all layers.

---

## Layer 1: Active Context Window

**What it is:** The LLM's working memory -- the tokens currently loaded into the model's context window.

**Capacity:** Up to 1,048,576 tokens (1M) with Nemotron 122B on the full reference setup. Smaller setups have 32K-512K depending on model and VRAM.

**Persistence:** Ephemeral. Lost when the session ends or context is cleared.

### Pinned Files

These files are always loaded at session start, consuming a fixed portion of the context:

| File | Approx. Tokens | Purpose |
|------|----------------|---------|
| `SOUL.md` | ~500 | Agent personality and decision framework |
| `TOOLS.md` | ~1,500 | Capability registry |
| `HEARTBEAT.md` | ~300 | Proactive behavior schedule |
| `MEMORY.md` | ~300 | Permanent long-term facts |
| Active TODO list (from Memos) | ~500 | Current task queue |
| Mission statements (from Memos) | ~300 | Core directives |
| Key interaction memories | ~1,500 | Recent important context |
| **Total pinned** | **~5,000** | ~0.5% of 1M context |

### Dynamic Loading

Beyond pinned files, context is loaded on-demand:

- **Memory Agent results** -- curated search results from Layers 2-5
- **Sub-agent responses** -- results from Claude Code, Codex, or ClawTeam
- **Active conversation** -- current user interaction
- **Task context** -- code files, documents, references for the current task

### Context Management

The agent actively manages its context window:

- **Self-monitoring:** The agent tracks approximate context usage. At ~80% capacity, it triggers compression.
- **`/compact` command:** Summarizes the current context, preserving key facts while reducing token count by 60-80%.
- **Overflow to Layer 2:** When context is cleared, important facts are persisted to Memos before they are lost.
- **Selective loading:** The Memory Agent returns only relevant results (500-2000 tokens) rather than dumping raw search results (which could be 50,000+ tokens).

---

## Layer 2: Memos (Quick-Access Persistent Storage)

**What it is:** A fast, tagged note system for capturing quick thoughts, decisions, evaluations, and TODOs.

**Service:** [usememos/memos](https://github.com/usememos/memos) running in Docker on port 5230
**Database:** PostgreSQL (shared instance with pgvector extension)
**Bridge:** MemOS Cloud OpenClaw Plugin (lifecycle hooks for automatic memory persistence)

### Content Categories

| Category | Tag | Examples |
|----------|-----|---------|
| TODO items | `#todo` | Tasks the agent needs to complete |
| Mission statements | `#mission` | Core directives and goals |
| Self-evaluations | `#self-eval` | Quality scores, bottleneck analysis |
| Decisions | `#decision` | Choices made and reasoning |
| Improvements | `#improvement` | Ideas for making the agent better |
| Revenue tracking | `#revenue` | Earnings from agent services |
| Hardware needs | `#hardware-need` | Identified hardware bottlenecks |
| Interactions | `#interaction` | Important conversation summaries |
| Actionable items | `#actionable` | Concrete next steps from research |

### MemOS Plugin Integration

The MemOS Cloud OpenClaw Plugin provides automatic lifecycle hooks:

- **`before_agent_start`:** Automatically recalls relevant memos and injects them into the context window. Filters by relevance using an LLM-based curator.
- **`agent_end`:** Automatically persists important information from the conversation to Memos.

This means memory works even if the agent does not explicitly call the Memos API -- the plugin handles the hot path automatically.

### API Access

```bash
# Create a memo
curl -X POST http://localhost:5230/api/v1/memos \
  -H "Authorization: Bearer YOUR_MEMOS_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"content": "Discovered that RagFlow supports MCP server mode #discovery"}'

# Search memos by tag
curl "http://localhost:5230/api/v1/memos?tag=self-eval" \
  -H "Authorization: Bearer YOUR_MEMOS_API_KEY"
```

### Multi-Agent Isolation

Each sub-agent has its own `agent_id`, ensuring memory isolation:

- Main agent memos are tagged with `agent_id=eve`
- Memory Agent memos are tagged with `agent_id=memory-agent`
- Research Agent memos are tagged with `agent_id=research-agent`

This prevents sub-agent scratch notes from polluting the main agent's memory.

---

## Layer 3: Obsidian Vault (Linked Knowledge Graph)

**What it is:** A graph of interconnected markdown notes, where the power comes from `[[wiki-links]]` and backlinks that create a web of connected knowledge.

**Location:** `/mnt/ssd/obsidian-vault/` (on the brain machine)
**Access:** `obsidian-cli` (CLI tool + MCP server mode)
**Sync:** `obsidian-git` (auto-commits every 10 minutes to a git remote)

### Vault Structure

```
obsidian-vault/
├── _index.md              # Vault map and key entry points
├── daily/                 # Chronological logs (YYYY-MM-DD.md)
├── projects/              # Project-specific knowledge
├── tools/                 # Tool documentation (from crawl4ai)
├── research/              # Research findings (from NotebookLM)
├── improvements/          # Self-improvement experiment logs
├── robots/                # Robotics knowledge
└── templates/             # Note templates
    ├── daily.md
    ├── research-finding.md
    ├── self-improvement.md
    └── tool-doc.md
```

### The Power of Links

The key difference between Obsidian and flat file storage is linking. Every note connects to related notes:

```markdown
# vLLM Configuration

Serves [[Nemotron 122B]] on [[nova-rig]] with 8-way
[[tensor parallelism]].

Performance: ~25 tokens/sec. See [[inference benchmarks]]
for detailed measurements.

Configured in [[docker-compose.rig.yml]]. Uses [[AWQ quantization]]
for optimal VRAM utilization.

Related: [[model hot-loading]], [[context window management]]
```

When the Memory Agent searches for "vLLM", it finds this note AND can follow backlinks to discover related context about Nemotron, tensor parallelism, and benchmarks -- even if those terms were not in the original search query.

### Rules for Notes

1. **Every note MUST have `[[wiki-links]]`** to related notes. No orphan notes.
2. **Every note MUST have tags** (#category, #source).
3. **Every note MUST have a creation date** in frontmatter.
4. **Use templates** from the `templates/` directory for consistency.

### MCP Tools

Access the vault through the `obsidian-cli` MCP server:

| Tool | Purpose |
|------|---------|
| `create_note` | Create a new note with links and tags |
| `find_notes` | Search by name, content, or backlinks |
| `get_note_content` | Read a specific note |
| `get_vault_info` | Vault statistics and graph structure |

### Data Flow Into Obsidian

| Source | Destination | Example |
|--------|-------------|---------|
| crawl4ai web crawls | `tools/` directory | Tool documentation as linked markdown |
| NotebookLM findings | `research/` directory | Research summaries with source links |
| Daily activity | `daily/` directory | Chronological log with task links |
| Self-improvement experiments | `improvements/` directory | Experiment results with metric links |
| Memos consolidation (daily) | Appropriate directory | Promoted memos become linked notes |

---

## Layer 4: RagFlow (Deep Vector + Full-Text Search)

**What it is:** A RAG (Retrieval-Augmented Generation) system that provides semantic vector search and full-text search across all ingested documents.

**Service:** [infiniflow/ragflow](https://github.com/infiniflow/ragflow) running in Docker on port 9380
**Search backend:** Elasticsearch (vectors + full-text indexing)
**Database:** PostgreSQL (metadata storage)

### Datasets (Knowledge Bases)

RagFlow organizes knowledge into datasets. Each dataset has its own chunking strategy and can be searched independently or together.

| Dataset | Content | Chunking Strategy |
|---------|---------|-------------------|
| `agent-memory` | Conversation history, self-eval logs | Paragraph-based with overlap |
| `tool-docs` | Tool documentation (from crawl4ai) | Markdown header-based |
| `code-knowledge` | Code snippets, patterns, solutions | AST-aware (function/class boundaries) |
| `research` | Papers, articles, deep research | Paragraph-based with overlap |
| `robotics` | Simulation configs, sensor data, CAD specs | Document-type dependent |
| `ops-reference` | Sysadmin docs, operational knowledge | Markdown header-based |

### How Search Works

RagFlow combines two search strategies:

1. **Semantic search (vector):** Converts the query into an embedding and finds documents with similar meaning. Good for conceptual queries like "how to handle context overflow."

2. **Full-text search (BM25):** Traditional keyword matching via Elasticsearch. Good for specific terms like "VLLM_TENSOR_PARALLEL" or error messages.

3. **Hybrid:** Both strategies run in parallel, results are merged using Reciprocal Rank Fusion (RRF). This is the default and recommended mode.

### API Access

```bash
# Semantic search across datasets
curl -X POST http://localhost:9380/api/v1/retrieval \
  -H "Authorization: Bearer YOUR_RAGFLOW_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"question":"how does the self-improvement loop work","datasets":["agent-memory","research"],"top_k":10}'

# Upload a document to a dataset
curl -X POST http://localhost:9380/api/v1/datasets/DATASET_ID/documents \
  -H "Authorization: Bearer YOUR_RAGFLOW_API_KEY" \
  -F "file=@my-document.md"

# RAG chat (search + LLM answer)
curl -X POST http://localhost:9380/api/v1/chats/CHAT_ID/completions \
  -H "Authorization: Bearer YOUR_RAGFLOW_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"question":"what were the last 5 self-eval scores?"}'
```

### Ingestion Pipeline

```
New document arrives
    |
    v
Chunking (strategy depends on dataset):
    Code       -> AST-aware (function/class boundaries)
    Markdown   -> Header-based sections
    Research   -> Paragraph-based with 200-token overlap
    |
    v
Embedding generation (via inference model)
    |
    v
Stored in Elasticsearch (vector index + full-text index)
    |
    v
Metadata stored in PostgreSQL
    |
    v
Available for search immediately
```

---

## Layer 5: Research Brain (NotebookLM + SurfSense)

**What it is:** External research capabilities that go beyond the agent's local knowledge. Two systems that serve complementary roles.

### NotebookLM (Primary)

**What:** Google's AI notebook, powered by Gemini. The agent's direct line to cutting-edge research.
**Access:** NotebookLM MCP CLI
**Master notebook:** `0f502fd6-fdeb-49bf-bc50-d759bf38483e` (23 sources, READ-ONLY)

**Capabilities:**
- Ingest sources (PDFs, URLs, text) and get Gemini-powered analysis across them
- Cross-source analysis that discovers connections the local model might miss
- Audio overview generation for complex topics
- Natural language queries across all ingested sources

**Rules:**
- The master notebook is READ-ONLY unless adding a 10/10 quality source
- The agent CAN create new notebooks for new research topics
- Research findings flow into Obsidian (Layer 3) and RagFlow (Layer 4)

### SurfSense (Fallback / Self-Hosted)

**What:** A self-hosted research platform with hybrid search and multi-source connectors.
**Service:** Docker on port 8000 (FastAPI + PostgreSQL + Redis)

**Capabilities:**
- Hybrid search (semantic + BM25 + Reciprocal Rank Fusion)
- 25+ connectors (Obsidian, Memos, GitHub, Slack, Google, etc.)
- Cited answers (Perplexity-style with sources)
- Podcast generation (audio summaries of research)
- Team RBAC for multi-operator scenarios

**Switchover Logic:**

| Condition | Action |
|-----------|--------|
| Default | Use NotebookLM (faster, Gemini-powered) |
| NotebookLM unreachable | Fallback to SurfSense |
| Research needs private data | SurfSense only (stays local) |
| Cross-validation needed | Query both in parallel |

---

## The Memory Agent

The Memory Agent is the orchestrator that searches across all layers. The main agent never searches memory directly -- it delegates to the Memory Agent.

### Why a Dedicated Sub-Agent?

1. **Context isolation.** The Memory Agent has its own context window. Raw search results (potentially 50,000+ tokens from 5 layers) never pollute the main agent's context.

2. **Curation.** The Memory Agent filters by relevance, deduplicates across layers, and summarizes. The main agent receives 500-2000 clean tokens instead of raw dumps.

3. **Quality tracking.** The main agent's self-evaluation tracks memory retrieval quality. If results are consistently irrelevant, the self-improvement loop adjusts the Memory Agent's search strategies.

### How It Works

```
Main Agent: "Find everything relevant to vLLM configuration"
    |
    v
Memory Agent (sub-agent, isolated context):
    |
    |-- Layer 2 (Memos): search tags #vllm, keywords "vLLM", "inference"
    |   Found: 3 memos about vLLM tuning
    |
    |-- Layer 3 (Obsidian): find_notes "vLLM"
    |   Found: 2 notes with [[vLLM]] links, 4 notes via backlinks
    |
    |-- Layer 4 (RagFlow): semantic search "vLLM configuration"
    |   Found: 5 chunks from tool-docs, 2 from ops-reference
    |
    |-- Layer 5 (SurfSense): search "vLLM configuration best practices"
    |   Found: 3 results from web sources
    |
    |-- FILTER: score each result by relevance to original query
    |-- DEDUPLICATE: remove near-identical content across layers
    |-- SUMMARIZE: compress to 500-2000 tokens
    |
    v
Returns to Main Agent:
  "vLLM is configured with 8-way tensor parallelism on nova-rig.
   Key settings: VLLM_MAX_MODEL_LEN=1048576, gpu_memory_utilization=0.95.
   Recent tuning (2026-03-18): reduced max_model_len for stability.
   Best practice: always set --trust-remote-code for Nemotron models.
   [Sources: Memos #vllm-tuning, Obsidian [[vLLM Configuration]],
   RagFlow tool-docs chunk #47]"
```

### Spawning the Memory Agent

```bash
acpx openclaw --session memory-agent "search all memory layers for: QUERY"
```

The Memory Agent is persistent per main agent session. It stays alive across tasks and is restarted on session reset.

---

## Data Flow Diagrams

### New Information Arrives

```
NEW INFORMATION
    |
    v
Memory Routing Decision (memory-routing.SKILL.md):
    |
    |-- Quick actionable item?
    |   -> Layer 2 (Memos) with appropriate tag
    |
    |-- Linked knowledge worth connecting?
    |   -> Layer 3 (Obsidian) with [[wiki-links]]
    |
    |-- Searchable content (docs, code, articles)?
    |   -> Layer 4 (RagFlow) in appropriate dataset
    |
    |-- Deep research material?
    |   -> Layer 5 (NotebookLM/SurfSense)
    |
    |-- Multiple of the above?
    |   -> Store in ALL relevant layers simultaneously
```

### Before Any Task

```
TASK BEGINS
    |
    v
1. MemOS Plugin: auto-recall from Memos (before_agent_start hook)
    |
    v
2. Main Agent: spawn Memory Agent with search query
    |
    v
3. Memory Agent: search Layers 2-5, filter, summarize
    |
    v
4. Memory Agent: return curated context (500-2000 tokens)
    |
    v
5. Main Agent: load curated results into Layer 1 (context window)
    |
    v
6. Main Agent: proceed with task using enriched context
```

### After Task Completes

```
TASK COMPLETE
    |
    v
1. MemOS Plugin: auto-persist to Memos (agent_end hook)
    |
    v
2. Self-evaluation: log quality score -> Layer 2 (#self-eval)
    |
    v
3. If new knowledge: create/update Obsidian note -> Layer 3
    |
    v
4. If new documents: ingest into RagFlow -> Layer 4
    |
    v
5. If groundbreaking research: add to Layer 5 notebook
```

### Periodic Maintenance (HEARTBEAT.md)

```
DAILY:
  Memos (#todo, #decision, #interaction)
    -> Consolidate into Obsidian daily note (Layer 3)
    -> Re-index Obsidian vault into RagFlow (Layer 4)

WEEKLY:
  Self-eval memos (#self-eval)
    -> Aggregate into improvement patterns
    -> Store pattern analysis in Obsidian (improvements/)
    -> Update skills if patterns warrant it

MONTHLY:
  All memos older than 30 days
    -> Archive completed TODOs
    -> Prune resolved decisions
    -> Keep mission statements and self-evals
```

---

## Adding New Knowledge Sources

### Adding a Website as Knowledge

```bash
# 1. Crawl the website to markdown
curl -X POST http://localhost:11235/crawl \
  -H "Content-Type: application/json" \
  -d '{"urls": ["https://docs.example.com"]}'

# 2. The agent stores the markdown in Obsidian (tools/ directory)
#    with [[wiki-links]] to related notes

# 3. The agent ingests the markdown into RagFlow (tool-docs dataset)
#    for semantic search
```

### Adding a PDF or Document

```bash
# Upload directly to RagFlow
curl -X POST http://localhost:9380/api/v1/datasets/DATASET_ID/documents \
  -H "Authorization: Bearer YOUR_RAGFLOW_API_KEY" \
  -F "file=@document.pdf"
```

### Adding a Code Repository

```bash
# 1. Clone the repo
git clone https://github.com/example/repo.git

# 2. The agent ingests relevant files into RagFlow (code-knowledge dataset)
#    AST-aware chunking preserves function/class boundaries

# 3. Key patterns are noted in Obsidian with links to related concepts
```

### Adding a Research Source to NotebookLM

Only add sources rated 10/10 to the master notebook. For other research, create a new notebook:

1. Create a new notebook in NotebookLM
2. Add your sources (PDFs, URLs, text)
3. Query the notebook via NotebookLM MCP
4. Store findings in Obsidian (research/ directory) with [[wiki-links]]
5. Ingest findings into RagFlow (research dataset)

---

## Memory System Configuration

### Environment Variables

```bash
# Memos
MEMOS_PORT=5230
MEMOS_DRIVER=postgres
MEMOS_API_KEY=your-memos-api-key

# MemOS Plugin (lifecycle hooks)
MEMOS_BASE_URL=https://memos.memtensor.cn/api/openmem/v1
MEMOS_USER_ID=openclaw-user
MEMOS_RECALL_GLOBAL=true          # Recall across all agents
MEMOS_MULTI_AGENT_MODE=true       # Enable agent_id isolation

# RagFlow
RAGFLOW_PORT=9380
RAGFLOW_API_KEY=your-ragflow-api-key

# Obsidian
OBSIDIAN_VAULT_PATH=/mnt/ssd/obsidian-vault
OBSIDIAN_GIT_REMOTE=your-git-remote-url

# NotebookLM
NOTEBOOKLM_NOTEBOOK_ID=0f502fd6-fdeb-49bf-bc50-d759bf38483e

# SurfSense
SURFSENSE_PORT=8000
```

### Tuning Memory Retrieval

If the Memory Agent returns irrelevant results, adjust these:

1. **RagFlow chunking:** Change chunk sizes in dataset settings. Smaller chunks = more precise but more results. Larger chunks = more context per result but less precise.

2. **RagFlow top_k:** Increase `top_k` in search requests for broader results, decrease for more focused.

3. **Memos tags:** Ensure consistent tagging. The Memory Agent searches by tags first, then keywords.

4. **Obsidian links:** More `[[wiki-links]]` = better backlink traversal = better discovery of related context.

5. **Memory Agent prompts:** The Memory Agent's search and filtering behavior is defined in its skills. Adjust via the self-improvement loop or manually edit its session prompt.
