# Research Pipeline — Orchestration Skill

## Purpose
Orchestrate the full research pipeline: discover → crawl → analyze → ingest → store.
This skill coordinates crawl4ai, NotebookLM, Tavily, SurfSense, and memory routing.

## When to Trigger
- when-to-research.SKILL.md says confidence < 70%
- Weekly tool discovery scan (HEARTBEAT.md)
- On-demand when operator requests deep research
- When a new topic or tool is discovered

## Pipeline Steps

### Step 1: Web Search (Tavily)
```bash
# Search for current information
tavily search --query "{topic}" --depth advanced --max-results 10
```
Output: List of relevant URLs + synthesized answer.

### Step 2: Crawl Sources (crawl4ai)
```bash
# Crawl the top URLs from Tavily results
curl -X POST http://nova-rig:11235/crawl \
  -H "Content-Type: application/json" \
  -d '{"urls": [<top_urls>], "word_count_threshold": 50}'
```
Output: Clean markdown for each URL.

### Step 3: Deep Analysis (NotebookLM — optional)
For research-grade topics, create a NotebookLM notebook:
```bash
notebooklm-mcp create --title "{topic} Research"
notebooklm-mcp add-source --notebook {id} --url {url}
notebooklm-mcp query --notebook {id} --query "{analysis question}"
```
Output: Gemini-powered cross-source analysis.

### Step 4: Store in Memory Layers

Route findings using memory-routing.SKILL.md:

| Finding Type | Destination | Format |
|-------------|-------------|--------|
| Quick actionable item | Layer 2: Memos | #topic tag + content |
| Linked knowledge | Layer 3: Obsidian | Note with [[wiki-links]] |
| Full documents | Layer 4: RagFlow | Via ingest-to-ragflow.sh |
| Deep research | Layer 5: SurfSense | Via connector sync |

```bash
# Store in Memos (quick capture)
curl -X POST http://nova-rig:5230/api/v1/memos \
  -H "Content-Type: application/json" \
  -d '{"content": "#research #{topic} Key finding: {summary}"}'

# Store in Obsidian (linked note)
obsidian-cli new "research/{topic}" \
  --vault /mnt/ssd/obsidian-vault \
  --content "{full_note_with_links}"

# Ingest into RagFlow (vector search)
./setup/scripts/ingest-to-ragflow.sh research /tmp/{topic}.md

# Sync to SurfSense (via periodic connector sync)
```

### Step 5: Log Research Activity
```bash
# Log to Memos for self-evaluation
curl -X POST http://nova-rig:5230/api/v1/memos \
  -H "Content-Type: application/json" \
  -d '{"content": "#self-eval #research topic={topic} sources={count} quality={score}/10 time={seconds}s"}'
```

## Fallback Chain
1. Primary: Tavily → crawl4ai → NotebookLM
2. If NotebookLM unavailable: Tavily → crawl4ai → SurfSense
3. If crawl4ai unavailable: Tavily → direct ingest
4. If Tavily unavailable: crawl4ai with manual URLs → SurfSense
5. If all external down: Search RagFlow + Obsidian (local only)

## Quality Metrics
- Sources discovered per research session
- Relevance score of stored findings (self-evaluated)
- Time from query to stored findings
- Cross-reference density (Obsidian link count)
