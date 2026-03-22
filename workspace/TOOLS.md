# TOOLS.md — OpenClaw Capability Registry
# Auto-updated by the Self-Improvement Controller
# Last updated: 2026-03-22T00:00:00Z
# Total tools: 18

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

### surfsense
- type: service
- runs_on: nova-rig
- endpoint: http://nova-rig:8000
- capabilities: search, chat, podcast_generate, connector_sync
- use_when: "self-hosted research, NotebookLM fallback"
- notes: "Runs on nova-rig. Backend :8000, frontend :3000."

### crawl4ai
- type: service + mcp
- runs_on: nova-rig
- endpoint: http://nova-rig:11235
- capabilities: crawl_url, crawl_batch, extract_structured
- use_when: "turn any webpage into clean markdown"
- output_destinations: [obsidian, ragflow, memos]
- notes: "Runs on nova-rig. Output feeds into memory stack."

## Research Tools

### notebooklm
- type: mcp
- server: notebooklm-mcp
- setup: setup/scripts/setup-notebooklm-mcp.sh
- capabilities: notebook_query, notebook_get, notebook_create, source_list, source_add, audio_overview
- master_notebook: 0f502fd6-fdeb-49bf-bc50-d759bf38483e
- use_when: "Gemini-powered research, cross-source analysis, discovering connections between concepts"
- rules: "READ-ONLY on master notebook. Only add 10/10 sources."
- auth: GOOGLE_APPLICATION_CREDENTIALS or GOOGLE_API_KEY
- mcp_config: ~/.openclaw/mcp-servers/notebooklm.json

### tavily
- type: mcp
- server: npx -y @tavily/mcp-server
- setup: setup/scripts/setup-tavily-mcp.sh
- capabilities: search, search_context, search_qna, extract
- use_when: "web search, current information, fact-checking, URL content extraction"
- modes:
  - search: "general web search, max_results 10, search_depth advanced"
  - search_context: "contextual search for RAG pipelines"
  - search_qna: "direct factual Q&A, precise answers"
  - extract: "fetch and extract content from specific URLs"
- auth: TAVILY_API_KEY
- mcp_config: ~/.openclaw/mcp-servers/tavily.json

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
- auth: OAuth (run `gws auth login` to authenticate)
- use_when: "Google Workspace operations — email, calendar, documents"
- rules: "NEVER send emails or delete events without operator approval. Log write ops to Memos #gws-action."
- skill: workspace/skills/google-workspace.SKILL.md
### gh
- type: cli
- command: gh {resource} {action}
- use_when: "GitHub operations"

## Robotics Tools

### dimos
- type: mcp + cli
- setup: setup/scripts/setup-dimos.sh
- capabilities: simulation, motor_control, perception, navigation, validate_motion, emergency_stop
- use_when: "robot commands, simulation, sensor data"
- skill: workspace/skills/robotics-simulation.SKILL.md
- mcp_config: ~/.openclaw/mcp-servers/dimos.json
- notes: "ALWAYS simulate before commanding real hardware."

### riva
- type: sdk
- module: riva.client
- setup: setup/scripts/setup-riva.sh
- server: nova-rig:50051 (gRPC)
- client: glm-server container on nova
- capabilities: asr_streaming, asr_offline, tts_synthesis, tts_streaming, get_voices
- use_when: "voice input/output — speech-to-text and text-to-speech for the robot"
- skill: workspace/skills/voice-interface.SKILL.md
- mcp_config: ~/.openclaw/mcp-servers/riva.json
- notes: "Server on nova-rig (GPU 0). Client SDK inside Docker. Voice commands for hardware require verbal confirmation."

### airi
- type: mcp
- setup: setup/scripts/setup-airi.sh
- source: moeru-ai/airi
- capabilities: set_expression, set_lip_sync, set_idle_animation, show_text_overlay, set_avatar_model
- use_when: "visual personality, emotional display, avatar face on robot screen"
- skill: workspace/skills/avatar-display.SKILL.md
- mcp_config: ~/.openclaw/mcp-servers/airi.json
- notes: "Runs on nova display (HDMI/DP). Lip sync driven by Riva TTS. Expressions map to agent state."

### picogk
- type: sdk
- runtime: dotnet (C# / .NET 8.0+)
- setup: setup/scripts/setup-picogk.sh
- source: leap71/PicoGK
- capabilities: create_lattice, create_solid, boolean_ops, generate_stl, apply_modulation
- use_when: "3D printable part design, lattice structures, computational engineering"
- skill: workspace/skills/cad-design.SKILL.md
- mcp_config: ~/.openclaw/mcp-servers/picogk.json
- output_dir: workspace/cad-output/
- notes: "C# SDK, not Python. Output STL files. Future: bambu-cli for direct Bambu Lab printing."

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

## Reference

### nemoclaw
- type: reference
- source: NVIDIA/NemoClaw
- use_when: "reference only — agent architecture patterns, NOT a sandbox"
- rules: "NemoClaw is optional. Eve runs FREE. No sandboxing constraints."
