# Quick Start Guide

Get OpenClaw Brain running in 10 minutes. This guide walks you through cloning the repository, running the installer, configuring a communication channel, and sending your first message to the agent.

---

## Prerequisites

Before you begin, make sure you have:

- **Linux machine** with Ubuntu 22.04+ (or JetPack 6 for Jetson)
- **NVIDIA GPU** with 8GB+ VRAM and working drivers (`nvidia-smi` should show your GPU)
- **Docker** and **Docker Compose V2** installed
- **Git** installed
- **50GB+ free disk space** (100GB recommended)
- **A Telegram account** (for the channel example below; Discord/Slack also supported)

### Verify your prerequisites

```bash
# Check GPU
nvidia-smi

# Check Docker
docker --version
docker compose version

# Check disk space
df -h /
```

If Docker is not installed:

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in for group changes to take effect
```

---

## Step 1: Clone the Repository

```bash
git clone https://github.com/openclaw/openclaw-brain.git
cd openclaw-brain
```

---

## Step 2: Run the Installer

The interactive installer detects your hardware, lets you choose services, and sets everything up.

```bash
bash setup/install.sh
```

The installer will:

1. **Detect your hardware** -- GPU count, VRAM, RAM, disk space
2. **Select a hardware profile** -- minimal, single-gpu, multi-gpu, or jetson-orin
3. **Configure your environment** -- generate a `.env` file from the template
4. **Select services** -- choose which Docker services to run
5. **Pull Docker images** -- download all required containers
6. **Start services** -- bring up PostgreSQL, Elasticsearch, Redis, RagFlow, Memos, and more
7. **Initialize the Obsidian vault** -- set up the linked knowledge graph
8. **Initialize RagFlow datasets** -- create the 6 default knowledge bases
9. **Run health checks** -- verify every service is responding
10. **Print a summary** -- show what is running and where

> **Tip:** For a non-interactive install with sensible defaults, run:
> ```bash
> bash setup/install.sh --defaults
> ```

### What the installer asks you

| Prompt | What it means | Default |
|--------|---------------|---------|
| Hardware profile | How much GPU power you have | Auto-detected |
| Inference backend | llama.cpp (day 1) or vLLM (production) | llama.cpp |
| Inference host | Where inference runs (localhost or remote IP) | localhost |
| Model path | Path to your GGUF/AWQ model files | /mnt/ssd/models |
| Services to enable | Toggle individual Docker services on/off | All core services on |
| Telegram bot token | For the Telegram channel (optional) | Skip |
| Data directory | Where to store persistent data | /mnt/ssd |

---

## Step 3: Configure a Channel (Telegram Example)

OpenClaw Brain communicates through channels. Telegram is the simplest to set up.

### Create a Telegram Bot

1. Open Telegram and search for **@BotFather**
2. Send `/newbot`
3. Choose a name (e.g., "Eve Agent") and a username (e.g., `eve_openclaw_bot`)
4. BotFather gives you a **bot token** -- copy it

### Add the Token to Your Environment

```bash
# Edit the environment file
nano setup/.env

# Find this line and replace the placeholder:
TELEGRAM_BOT_TOKEN=your-telegram-token

# Replace with your actual token:
TELEGRAM_BOT_TOKEN=7123456789:AAH...your-actual-token
```

### Restart the Gateway

```bash
# Restart the OpenClaw gateway to pick up the new token
docker compose -f setup/docker-compose.nova.yml restart
```

---

## Step 4: Send Your First Message

1. Open Telegram and find your bot by the username you chose
2. Send `/start`
3. Send a message:

```
Hello Eve! What can you do?
```

The agent will respond, drawing on its SOUL.md personality, searching its memory layers, and using the tools defined in TOOLS.md.

### Try These First Commands

| Message | What happens |
|---------|-------------|
| `What do you know about yourself?` | Agent reads its SOUL.md and IDENTITY.md |
| `Create a memo: test first memo` | Agent creates a note in Memos (Layer 2) |
| `Search your memory for "self-improvement"` | Memory Agent searches all 5 layers |
| `Run a health check` | Agent checks all services via health-check.sh |
| `What tools do you have?` | Agent reads TOOLS.md and lists capabilities |

---

## Step 5: Verify Everything Is Working

Run the health check script to confirm all services are up:

```bash
bash setup/scripts/health-check.sh
```

Expected output:

```
=== OpenClaw Brain Health Check ===

Services:
  [PASS] PostgreSQL
  [PASS] Elasticsearch
  [PASS] Redis
  [PASS] RagFlow
  [PASS] Memos
  [PASS] SurfSense
  [PASS] crawl4ai

Inference:
  [PASS] vLLM

MCP Servers:
  [PASS] obsidian-cli

Agent:
  [PASS] OpenClaw Gateway

Disk:
  [PASS] Disk usage: 42%

=== Results: 11 passed, 0 failed ===
```

If any service fails, see the [Troubleshooting Guide](troubleshooting.md).

---

## What Happens Next

Once your agent is running, it will:

1. **Load its personality** from `workspace/SOUL.md`
2. **Pin core files** (SOUL.md, TOOLS.md, HEARTBEAT.md) into its context window
3. **Start the heartbeat** -- proactive behaviors on schedule (TODOs, self-evaluation, discovery)
4. **Begin the self-improvement loop** -- after every task, the agent evaluates itself and researches ways to get better

### Explore Further

- **[Customization Guide](customization.md)** -- change the agent's personality, behaviors, and skills
- **[Memory System Deep Dive](memory-system.md)** -- understand the 5-layer memory hierarchy
- **[Self-Improvement Loop](self-improvement.md)** -- how the agent makes itself better
- **[Hardware Guide](hardware-guide.md)** -- hardware recommendations for every budget
- **[Troubleshooting](troubleshooting.md)** -- common issues and fixes

---

## Project Structure (Quick Reference)

```
openclaw-brain/
├── setup/
│   ├── install.sh                    # The installer you just ran
│   ├── .env.example                  # Environment template
│   ├── docker-compose.nova.yml       # Brain machine services
│   ├── docker-compose.rig.yml        # GPU inference (vLLM)
│   ├── docker-compose.rig-llamacpp.yml  # GPU inference (llama.cpp)
│   └── scripts/
│       ├── health-check.sh           # Service health verification
│       ├── setup-postgres.sh         # Database initialization
│       ├── setup-ragflow.sh          # RagFlow datasets
│       ├── setup-memos.sh            # Memos configuration
│       ├── setup-obsidian.sh         # Vault initialization
│       ├── setup-surfsense.sh        # SurfSense setup
│       ├── setup-crawl4ai.sh         # crawl4ai setup
│       ├── setup-vllm.sh             # vLLM configuration
│       ├── setup-acpx.sh             # Agent protocol setup
│       └── setup-openclaw.sh         # Gateway setup
├── workspace/
│   ├── SOUL.md                       # Agent personality and values
│   ├── TOOLS.md                      # Capability registry
│   ├── HEARTBEAT.md                  # Proactive behavior schedule
│   ├── MEMORY.md                     # Long-term facts
│   ├── IDENTITY.md                   # Name, avatar, version
│   ├── AGENTS.md                     # Sub-agent definitions
│   └── skills/                       # Behavioral skills
├── obsidian-vault/                   # Linked knowledge graph
├── ARCHITECTURE.md                   # Full technical specification
└── docs/                             # You are here
```
