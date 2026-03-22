# TOOLS — Memory Agent

## memos-api
- type: service
- endpoint: http://localhost:5230/api/v1
- capabilities: search_memos, list_by_tag
- use_when: "search for quick captures, TODOs, decisions, evaluations"

## obsidian
- type: mcp
- server: obsidian-cli serve
- capabilities: find_notes, get_note_content, get_vault_info
- use_when: "search linked knowledge, concepts, documentation"

## ragflow
- type: service
- endpoint: http://100.76.233.80:9380/api/v1
- auth: Bearer ragflow-c5062fdd133375fcef53c7b91eca624c
- capabilities: semantic_search, upload_document
- datasets: agent-memory, tool-docs, code-knowledge, research, robotics, ops-reference, luxonis-docs
- use_when: "deep semantic search across all ingested documents"

## notebooklm
- type: mcp
- server: notebooklm-mcp
- capabilities: notebook_query
- use_when: "research questions requiring Gemini cross-source analysis"

## surfsense
- type: service
- endpoint: http://localhost:8000
- capabilities: search, hybrid_search
- use_when: "self-hosted research, NotebookLM fallback"

### lcm (Lossless Claw)
- type: openclaw-tool (native, provided by ContextEngine plugin)
- tools: lcm_grep, lcm_describe, lcm_expand_query
- use_when: "conversation reconstruction, drill-back into compressed context, finding exact quotes"
- lcm_grep: "Full-text search across ALL conversation history — nothing is ever deleted"
- lcm_expand_query: "Drill into a summary to get the original detailed conversation"
- lcm_describe: "Metadata about a specific summary (depth, message count, time range)"
- dataset: lcm-summaries (in RagFlow, auto-synced)
