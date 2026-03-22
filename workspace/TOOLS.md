# TOOLS.md — OpenClaw Capability Registry
# Auto-updated by the Self-Improvement Controller
# Last updated: 2026-03-21T00:00:00Z
# Total tools: 15

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
