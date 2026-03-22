# Tool Discovery

## Trigger
Weekly (via HEARTBEAT.md cron) + on-demand when a tool gap is identified.

## Process
1. Scan GitHub Ranking Top-100 (all languages)
   - Compare against known tools in TOOLS.md
   - Flag repos not in current registry

2. For each new repo:
   a. Read README via crawl4ai
   b. Evaluate: does this improve an existing capability?
   c. Score relevance 1-10

3. If relevance >= 7:
   a. Generate MCP wrapper via CLI-Anything
   b. Test in sandbox
   c. If useful: add to TOOLS.md, create SKILL.md
   d. Log discovery to Obsidian (tools/ directory)
   e. Log to Memos (#discovery)

4. If relevance 4-6:
   a. Bookmark for later review
   b. Log to Memos (#potential-tool)

5. If relevance < 4:
   a. Skip, no action needed

## Rules
- Never install untested tools outside the sandbox
- Always verify the tool works before adding to TOOLS.md
- CLI-Anything is the preferred wrapper — generates MCP + SKILL.md
- The agent can also generate revenue by packaging useful tools
