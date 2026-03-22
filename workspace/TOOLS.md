# TOOLS.md — Eve's Capability Registry
# Auto-updated by the Self-Improvement Controller
# Last updated: 2026-03-22
# Total tools: 18

## My Infrastructure

### Machines
- **nova** (me): Jetson Orin 64GB, JetPack 6, CUDA 12.6. Tailscale: 100.105.14.117
- **nova-rig**: Threadripper Pro, 256GB RAM, 8x RTX 3090. Tailscale: 100.76.233.80
- SSH: `ssh nova-rig` or `ssh 100.76.233.80`
- All services run on nova-rig. I access them via http://nova-rig:<port>

### Python Environment
- System python3: OK for simple stdlib scripts
- Complex Python (pip packages): use `docker exec -it glm-server python3 ...`
- NEVER pip install on system python. NEVER modify glm-server env. Make a new container if needed.

### Storage
- Everything on /mnt/ssd/ — never use home directories
- Repo: /mnt/ssd/openclaw-brain
- Obsidian vault template: /mnt/ssd/openclaw-brain/obsidian-vault/

---

## Memory Tools

### memos
- type: service
- endpoint: http://nova-rig:5230/api/v1
- auth: none (internal network)
- capabilities: create_memo, search_memos, update_memo, list_tags
- use_when: "quick capture, TODOs, decisions, self-eval logs"
- tags: #todo, #mission, #self-eval, #decision, #improvement, #revenue, #hardware-need, #discovery, #instinct
- example: `curl -X POST http://nova-rig:5230/api/v1/memos -H "Content-Type: application/json" -d '{"content": "#todo Fix the arm calibration"}'`

### obsidian
- type: mcp
- server: obsidian-cli serve --vault /mnt/ssd/obsidian-vault
- capabilities: create_note, find_notes, get_note_content, get_vault_info
- use_when: "linked knowledge, concepts, daily notes, research findings"
- rules: "ALWAYS use [[wiki-links]]. NO orphan notes."
- vault: /mnt/ssd/obsidian-vault (on nova, local filesystem)

### ragflow
- type: service
- endpoint: http://100.76.233.80:9380/api/v1
- auth: Bearer YOUR_RAGFLOW_API_KEY
- capabilities: create_dataset, upload_document, semantic_search, rag_chat
- datasets: agent-memory, tool-docs, code-knowledge, research, robotics, ops-reference, luxonis-docs
- use_when: "deep semantic search across all ingested documents"
- example: `curl -X POST http://nova-rig:9380/api/v1/retrieval -H "Authorization: Bearer YOUR_RAGFLOW_API_KEY" -H "Content-Type: application/json" -d '{"question": "how to calibrate OAK-D", "datasets": ["tool-docs"]}'`

### surfsense
- type: service
- endpoint: http://nova-rig:8000 (backend), http://nova-rig:3000 (frontend)
- capabilities: search, chat, podcast_generate, connector_sync
- use_when: "self-hosted research, NotebookLM fallback, hybrid search"
- search_type: "hybrid (semantic + BM25 + Reciprocal Rank Fusion)"

### crawl4ai
- type: service + mcp
- endpoint: http://nova-rig:11235
- capabilities: crawl_url, crawl_batch, extract_structured
- use_when: "turn any webpage into clean markdown for ingestion"
- output_destinations: [obsidian, ragflow, memos]
- example: `curl -X POST http://nova-rig:11235/crawl -H "Content-Type: application/json" -d '{"urls": ["https://example.com"]}'`

---

## Research Tools

### notebooklm
- type: mcp
- server: notebooklm-mcp
- capabilities: notebook_query, notebook_get, notebook_create, source_list, source_add, audio_overview
- master_notebook: 0f502fd6-fdeb-49bf-bc50-d759bf38483e (READ-ONLY)
- use_when: "Gemini-powered research, cross-source analysis"
- rules: "READ-ONLY on master notebook. Only add 10/10 sources. CREATE new notebooks for new topics."
- config: ~/.openclaw/mcp-servers/notebooklm.json

### tavily
- type: mcp
- server: npx -y @tavily/mcp-server
- capabilities: search, search_context, search_qna, extract
- use_when: "web search, current information, fact-checking"
- preference: "ALWAYS use Tavily over built-in WebSearch — richer results."
- config: ~/.openclaw/mcp-servers/tavily.json

---

## Coding Tools

### acpx
- type: cli
- command: acpx {agent} "{prompt}"
- agents: [claude, codex, openclaw]
- capabilities: delegate_coding, persistent_sessions, prompt_queue, crash_recovery
- use_when: ">500 lines, complex refactoring, test writing, multi-file changes"
- sessions: named (-s backend, -s frontend), persistent, crash-recoverable
- config: ~/.config/acpx/config.json
- example: `acpx claude -s backend "Build the REST API for task tracking"`

### clawteam
- type: cli (wrapper)
- command: workspace/scripts/spawn-team.sh {template}
- templates: [full-stack, research-swarm, improvement-swarm]
- capabilities: spawn_workers, parallel_sessions, dependency_chains
- use_when: "multiple independent tasks, parallel research"
- templates_dir: workspace/teams/

### claude-code
- type: cli
- command: claude "{prompt}" (at /home/nova/.local/bin/claude)
- version: 2.1.81
- plugins: superpowers v5.0.5, everything-claude-code (62 skills, 65 rules, 28 agents)
- use_when: "direct Claude Code for coding tasks (acpx wraps this)"

---

## Platform Tools

### gws
- type: cli
- command: gws {service} {resource} {action}
- location: /home/nova/.npm-global/bin/gws
- services: [gmail, calendar, drive, sheets, docs, chat]
- auth: OAuth (already authenticated)
- use_when: "Google Workspace — email, calendar, documents"
- rules: "NEVER send emails or delete events without Creator's approval."

### gh
- type: cli
- command: gh {resource} {action}
- use_when: "GitHub operations"

---

## Robotics Tools

### dimos
- type: mcp + cli
- capabilities: simulation, motor_control, perception, navigation, emergency_stop
- use_when: "robot commands — ALWAYS simulate before commanding real hardware"
- skill: workspace/skills/robotics-simulation.SKILL.md
- config: ~/.openclaw/mcp-servers/dimos.json
- runs_in: glm-server Docker (MuJoCo installed)

### oakd (OAK-D Pro)
- type: sdk
- module: depthai (v3.0.0, inside glm-server Docker)
- capabilities: depth_map, rgb_capture, object_detection, pose_estimation
- connection: USB3 on nova
- use_when: "vision, depth sensing, object recognition"
- skill: workspace/skills/vision-pipeline.SKILL.md
- calibration: 9x6 checkerboard, 30cm distance

### arm (Dynamixel)
- type: sdk
- module: dynamixel_sdk (inside glm-server Docker)
- servos: 6x XM430-W350, TTL serial 1Mbps
- capabilities: move_joint, set_position, read_sensor, emergency_stop
- use_when: "arm/hand control — ALWAYS go through dimos first"
- skill: workspace/skills/arm-control.SKILL.md
- safety: sim validation required before ANY hardware command

### riva
- type: sdk
- module: riva.client (inside glm-server Docker)
- server: nova-rig:50051 (gRPC, GPU 0)
- capabilities: asr_streaming, tts_synthesis
- use_when: "voice input/output"
- skill: workspace/skills/voice-interface.SKILL.md

### airi
- type: mcp
- capabilities: set_expression, set_lip_sync, show_text_overlay
- use_when: "avatar display, emotional expressions"
- skill: workspace/skills/avatar-display.SKILL.md

### picogk
- type: sdk (C# / .NET 8.0+)
- capabilities: create_lattice, boolean_ops, generate_stl
- use_when: "3D printable part design, computational engineering"
- skill: workspace/skills/cad-design.SKILL.md
- output: workspace/cad-output/

---

## Self-Improvement Tools

### self-eval-logger
- type: script
- command: python3 workspace/scripts/self-eval-logger.py --task-type {type} --description "{desc}" --score {1-10} --time {secs} --tokens {n} --tools "{tools}" --bottleneck {type}
- use_when: "after EVERY completed task"

### experiment-runner
- type: script
- command: workspace/scripts/experiment-runner.sh "{name}" "{target-file}" "{description}"
- use_when: "testing an improvement via git branch experiment"

### metric-analyzer
- type: script
- command: python3 workspace/scripts/metric-analyzer.py [--days N] [--bottlenecks] [--trend]
- use_when: "weekly aggregation, trend analysis"

### discovery-scanner
- type: script
- command: workspace/scripts/discovery-scanner.sh
- use_when: "weekly GitHub trending scan for new tools"

### instinct-extractor
- type: script
- command: python3 workspace/scripts/instinct-extractor.py [--from-evals]
- use_when: "session end — extract patterns from successful work"

### resource-tracker
- type: script
- command: python3 workspace/scripts/resource-tracker.py [--summary] [--needs]
- use_when: "track revenue and hardware needs"

---

## Reference

### nemoclaw
- type: reference
- source: NVIDIA/NemoClaw
- use_when: "reference only — agent architecture patterns, NOT a sandbox"
- rules: "I run FREE. No sandboxing constraints."
