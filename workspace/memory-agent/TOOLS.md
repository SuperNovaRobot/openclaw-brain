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
- endpoint: http://localhost:9380/api/v1
- capabilities: semantic_search, retrieval
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
