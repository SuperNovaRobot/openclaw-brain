# Troubleshooting Guide

This guide covers common issues with OpenClaw Brain and how to resolve them. Start with the health check, then find your specific issue below.

---

## First Step: Run the Health Check

Before diving into specific issues, run the health check to see which services are having problems:

```bash
cd /mnt/ssd/openclaw-brain
bash setup/scripts/health-check.sh
```

The output tells you exactly which services pass and which fail. Use the relevant section below to fix any failures.

---

## Installation Issues

### Prerequisites Not Met

**Symptom:** Installer exits with "missing prerequisite" errors.

**Solution:** Install the required dependencies:

```bash
# Docker (required)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in, then verify:
docker --version
docker compose version

# NVIDIA drivers (required for GPU)
# Ubuntu:
sudo apt install nvidia-driver-535
sudo reboot
# Verify:
nvidia-smi

# NVIDIA Container Toolkit (required for GPU in Docker)
distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt update && sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
# Verify:
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

### Docker Compose Version Mismatch

**Symptom:** `docker-compose` commands fail, or compose files are not recognized.

**Solution:** OpenClaw Brain requires Docker Compose V2 (the `docker compose` plugin, not the standalone `docker-compose` binary):

```bash
# Check your version
docker compose version
# Should show: Docker Compose version v2.x.x

# If you only have docker-compose (V1), install V2:
sudo apt install docker-compose-plugin

# If compose files fail to parse, ensure no "version:" key at top
# Docker Compose V2 does not require a version field
```

### Disk Space Insufficient

**Symptom:** Docker image pulls fail, or services fail to start with "no space left on device."

**Solution:**

```bash
# Check disk space
df -h /mnt/ssd   # or df -h / if not using /mnt/ssd

# Clean Docker resources
docker system prune -a    # WARNING: removes all unused images
docker volume prune       # WARNING: removes unused volumes

# Check which images are largest
docker images --format "table {{.Repository}}\t{{.Size}}" | sort -k2 -h

# If using /mnt/ssd, ensure it is mounted and has space:
mount | grep ssd
```

You need at least 50GB free for a minimal install (Docker images + databases), 100GB recommended.

---

## Services Will Not Start

### General Docker Troubleshooting

```bash
# Check which containers are running
docker compose -f setup/docker-compose.nova.yml ps

# Check resource usage
docker stats --no-stream

# View logs for a specific service
docker compose -f setup/docker-compose.nova.yml logs postgres
docker compose -f setup/docker-compose.nova.yml logs elasticsearch
docker compose -f setup/docker-compose.nova.yml logs ragflow

# Restart a single service
docker compose -f setup/docker-compose.nova.yml restart memos

# Restart all services
docker compose -f setup/docker-compose.nova.yml down
docker compose -f setup/docker-compose.nova.yml up -d
```

### PostgreSQL Will Not Start

**Symptom:** `[FAIL] PostgreSQL` in health check.

**Common causes and fixes:**

```bash
# Check logs
docker compose -f setup/docker-compose.nova.yml logs postgres

# Cause: Port 5432 already in use
sudo lsof -i :5432
# Fix: Stop the conflicting process or change POSTGRES_PORT in .env

# Cause: Corrupted data directory
# Fix: Back up and reinitialize (WARNING: destroys data)
sudo mv /mnt/ssd/pgdata /mnt/ssd/pgdata.backup
docker compose -f setup/docker-compose.nova.yml up -d postgres
# Then re-run setup scripts:
bash setup/scripts/setup-postgres.sh

# Cause: Insufficient shared memory
# Fix: Add to docker-compose.nova.yml under postgres service:
#   shm_size: 256m
```

### Elasticsearch Will Not Start

**Symptom:** `[FAIL] Elasticsearch` in health check.

**Common causes and fixes:**

```bash
# Check logs
docker compose -f setup/docker-compose.nova.yml logs elasticsearch

# Cause: vm.max_map_count too low (most common)
# Error in logs: "max virtual memory areas vm.max_map_count [65530] is too low"
sudo sysctl -w vm.max_map_count=262144
# Make permanent:
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

# Cause: Insufficient memory
# Fix: Reduce heap size in .env:
ES_JAVA_OPTS=-Xms2g -Xmx2g    # Reduce from default 4g

# Cause: Data directory permissions
sudo chown -R 1000:1000 /mnt/ssd/esdata
```

### RagFlow Will Not Start

**Symptom:** `[FAIL] RagFlow` in health check.

```bash
# Check logs
docker compose -f setup/docker-compose.nova.yml logs ragflow

# Cause: PostgreSQL or Elasticsearch not ready yet
# Fix: Restart RagFlow after dependencies are healthy:
docker compose -f setup/docker-compose.nova.yml restart ragflow

# Cause: Port conflict
sudo lsof -i :9380

# Cause: Insufficient memory
# Check if the container was OOM-killed:
docker inspect ragflow-container-name | grep -i oom
```

### Memos Will Not Start

**Symptom:** `[FAIL] Memos` in health check.

```bash
# Check logs
docker compose -f setup/docker-compose.nova.yml logs memos

# Cause: PostgreSQL not ready
# Fix: Ensure PostgreSQL is healthy first, then restart Memos:
docker compose -f setup/docker-compose.nova.yml restart memos

# Cause: Wrong DSN format
# Check .env has correct format:
# MEMOS_DSN should NOT be set directly -- Memos uses POSTGRES_USER/PASSWORD from compose
```

---

## vLLM and Inference Issues

### vLLM Out of Memory (OOM)

**Symptom:** vLLM crashes with CUDA out of memory errors.

```bash
# Check GPU memory
nvidia-smi

# Solution 1: Reduce max model length
# In setup/.env:
VLLM_MAX_MODEL_LEN=524288     # Reduce from 1048576
# Or further:
VLLM_MAX_MODEL_LEN=131072     # 128K context

# Solution 2: Reduce GPU memory utilization
# In docker-compose.rig.yml, change the command:
#   --gpu-memory-utilization 0.90   # Reduce from 0.95

# Solution 3: Use more aggressive quantization
# Switch from FP16 to AWQ or GPTQ model:
VLLM_MODEL=nemotron-122b-awq   # Instead of nemotron-122b

# Solution 4: Reduce tensor parallelism overhead
# If you have 4 GPUs but OOM with TP=4, try TP=2:
VLLM_TENSOR_PARALLEL=2

# After any change, restart:
docker compose -f setup/docker-compose.rig.yml down
docker compose -f setup/docker-compose.rig.yml up -d
```

### Slow Inference

**Symptom:** Token generation is slower than expected (< 10 tokens/sec for 70B models).

```bash
# Check 1: GPU utilization
nvidia-smi -l 1
# GPUs should show high utilization during inference

# Check 2: Tensor parallelism is working
# In vLLM logs, look for "tensor_parallel_size"
docker compose -f setup/docker-compose.rig.yml logs vllm | grep tensor

# Check 3: NVLink (for multi-GPU)
nvidia-smi topo -m
# NVLink connections show as "NV#" -- PCIe shows as "PHB" or "SYS"
# PCIe is slower but still functional

# Check 4: Model quantization
# AWQ models are faster than FP16 on consumer GPUs
# GPTQ is another option but may be slightly slower than AWQ

# Check 5: Thermal throttling
nvidia-smi -q -d TEMPERATURE
# If GPU temp > 85C, improve cooling

# Check 6: Power limit
nvidia-smi -q -d POWER
# Ensure power limit is not artificially reduced
```

### vLLM Cannot Load Model

**Symptom:** vLLM fails to start, logs show model loading errors.

```bash
# Check the model path
ls -la /mnt/ssd/models/
# Ensure the model directory/files exist

# Check the model name matches
# In .env:
VLLM_MODEL=nemotron-122b-awq
# The directory /mnt/ssd/models/nemotron-122b-awq/ must exist

# For GGUF models (llama.cpp), check file exists:
ls -la /mnt/ssd/models/*.gguf

# Common issue: model download was interrupted
# Re-download if files are incomplete
```

### Inference Host Unreachable

**Symptom:** Brain machine cannot reach the inference API on nova-rig.

```bash
# From the brain machine, test connectivity:
curl -sf http://nova-rig:8080/health
# Or with IP:
curl -sf http://192.168.1.X:8080/health

# Check 1: Is vLLM running on nova-rig?
ssh nova-rig "docker ps | grep vllm"

# Check 2: Is the port open?
ssh nova-rig "ss -tlnp | grep 8080"

# Check 3: Firewall
ssh nova-rig "sudo ufw status"
# If active, allow port 8080:
ssh nova-rig "sudo ufw allow 8080/tcp"

# Check 4: DNS resolution
ping nova-rig
# If it does not resolve, use the IP address in .env instead:
# RIG_HOST=192.168.1.X
# INFERENCE_HOST=http://192.168.1.X:8080
```

---

## Context Window Issues

### Context Window Full

**Symptom:** Agent becomes slow, loses track of conversation, or returns incomplete responses.

**Solutions:**

```bash
# Solution 1: Run /compact
# In the agent conversation, type:
/compact

# Solution 2: Check pinned files
# Review which files are loaded at session start:
wc -w workspace/SOUL.md workspace/TOOLS.md workspace/HEARTBEAT.md workspace/MEMORY.md
# If TOOLS.md has grown very large, prune unnecessary entries

# Solution 3: Reduce MEMORY.md
# Keep only essential permanent facts
# Move detailed information to Obsidian (Layer 3) instead

# Solution 4: Increase model context length
# In .env:
VLLM_MAX_MODEL_LEN=1048576    # Full 1M if VRAM allows
# Note: larger context = more VRAM usage

# Solution 5: Check if Memory Agent is returning too much
# Review Memory Agent results -- should be 500-2000 tokens
# If returning more, adjust search filtering
```

### Memory Not Recalling

**Symptom:** Agent does not remember things it should know.

```bash
# Check 1: Is Memos running?
curl -sf http://localhost:5230/api/v1/memos
# If not, restart:
docker compose -f setup/docker-compose.nova.yml restart memos

# Check 2: Is MemOS Plugin configured?
# Verify in .env:
# MEMOS_API_KEY should be set to your actual key, not the placeholder
# MEMOS_RECALL_GLOBAL=true
# MEMOS_MULTI_AGENT_MODE=true

# Check 3: Are memos actually stored?
# Search for recent memos:
curl "http://localhost:5230/api/v1/memos" \
  -H "Authorization: Bearer YOUR_MEMOS_API_KEY"

# Check 4: Is RagFlow indexing working?
curl -sf http://localhost:9380/api/v1/datasets \
  -H "Authorization: Bearer YOUR_RAGFLOW_API_KEY"
# Verify datasets exist and have documents

# Check 5: Is obsidian-cli running?
obsidian-cli info
# If not, restart the MCP server

# Check 6: Check memory tags
# Memory Agent searches by tags first -- ensure consistent tagging
# Review memory-routing.SKILL.md for tag conventions
```

---

## Obsidian Vault Issues

### Obsidian Sync Failing

**Symptom:** Vault changes are not syncing to the git remote.

```bash
# Check 1: Is obsidian-git configured?
cd /mnt/ssd/obsidian-vault
git remote -v
# Should show your git remote URL

# Check 2: Is the remote reachable?
git fetch origin

# Check 3: Are there uncommitted changes?
git status
# If there are conflicts:
git stash
git pull --rebase origin main
git stash pop
# Resolve any conflicts manually

# Check 4: SSH keys
# If using SSH remote:
ssh -T git@github.com    # or your git host
# If auth fails, check SSH key configuration

# Check 5: Auto-commit timer
# obsidian-git should auto-commit every 10 minutes
# Check if the obsidian-git plugin is configured:
cat /mnt/ssd/obsidian-vault/.obsidian/plugins/obsidian-git/data.json 2>/dev/null
```

### Orphan Notes Warning

**Symptom:** Notes exist without any `[[wiki-links]]`, breaking the knowledge graph.

```bash
# Find notes without wiki-links (rough check):
cd /mnt/ssd/obsidian-vault
grep -rL "\[\[" --include="*.md" . | grep -v templates | grep -v _index | grep -v .gitkeep

# For each orphan note, add links to related notes:
# Open the note and add [[wiki-links]] to at least 2 related notes
```

---

## Service-Specific Health Check Failures

### SurfSense Not Responding

```bash
# Check logs
docker compose -f setup/docker-compose.nova.yml logs surfsense

# Common issue: Redis not ready
docker compose -f setup/docker-compose.nova.yml restart redis
docker compose -f setup/docker-compose.nova.yml restart surfsense

# Check if port is in use
sudo lsof -i :8000
```

### crawl4ai Not Responding

```bash
# Check logs
docker compose -f setup/docker-compose.nova.yml logs crawl4ai

# Common issue: Chromium crashes (memory)
# Increase memory limit in docker-compose.nova.yml:
#   mem_limit: 4g    # Increase from 3g

# Restart
docker compose -f setup/docker-compose.nova.yml restart crawl4ai
```

### Redis Connection Refused

```bash
# Check if Redis is running
docker compose -f setup/docker-compose.nova.yml ps redis

# Check logs
docker compose -f setup/docker-compose.nova.yml logs redis

# Test connectivity
docker compose -f setup/docker-compose.nova.yml exec redis redis-cli ping
# Should return: PONG

# If corrupted, reset Redis (WARNING: clears cache):
docker compose -f setup/docker-compose.nova.yml rm -f redis
docker compose -f setup/docker-compose.nova.yml up -d redis
```

---

## Performance Issues

### High RAM Usage

```bash
# Check per-container memory usage
docker stats --no-stream

# If a service exceeds its mem_limit, it gets OOM-killed
# Check for OOM kills:
dmesg | grep -i "oom\|killed"

# Solutions:
# 1. Reduce Elasticsearch heap: ES_JAVA_OPTS=-Xms2g -Xmx2g
# 2. Reduce RagFlow memory limit in docker-compose
# 3. Move heavy services to nova-rig (if using 2-machine setup)
```

### High Disk Usage

```bash
# Check disk usage
df -h /mnt/ssd

# Check Docker disk usage
docker system df

# Find largest directories
du -sh /mnt/ssd/* | sort -h

# Clean up:
# 1. Prune old Docker images
docker image prune -a

# 2. Clean Elasticsearch old indices
curl -X DELETE "http://localhost:9200/old-index-name"

# 3. Compress old logs
find /mnt/ssd -name "*.log" -mtime +30 -exec gzip {} \;

# 4. Run the agent's monthly prune (HEARTBEAT.md monthly task)
```

### High CPU Usage

```bash
# Identify the culprit
docker stats --no-stream
top -o %CPU

# Common causes:
# 1. Elasticsearch indexing: temporary, will settle
# 2. RagFlow chunking new documents: temporary
# 3. crawl4ai running Chromium: expected during web crawls
# 4. vLLM inference: expected during model queries

# If a service is stuck at 100% CPU:
docker compose -f setup/docker-compose.nova.yml restart service-name
```

---

## Quick Reference: Port Map

| Port | Service | Health Check |
|------|---------|-------------|
| 5230 | Memos | `curl -sf http://localhost:5230/api/v1/memos` |
| 5432 | PostgreSQL | `pg_isready -h localhost -U openclaw` |
| 6379 | Redis | `redis-cli ping` |
| 8000 | SurfSense | `curl -sf http://localhost:8000/health` |
| 8080 | vLLM (on rig) | `curl -sf http://nova-rig:8080/health` |
| 9200 | Elasticsearch | `curl -sf http://localhost:9200/_cluster/health` |
| 9380 | RagFlow | `curl -sf http://localhost:9380/api/v1/datasets` |
| 11235 | crawl4ai | `curl -sf http://localhost:11235/health` |
| 18789 | OpenClaw Gateway | `curl -sf http://localhost:18789/health` |

---

## Getting Help

If you cannot resolve an issue with this guide:

1. **Check the logs** -- almost every problem leaves a trace in Docker logs
2. **Check ARCHITECTURE.md** -- the full technical specification may explain expected behavior
3. **Search the Obsidian vault** -- the agent may have logged relevant troubleshooting steps
4. **Open an issue** on the [GitHub repository](https://github.com/openclaw/openclaw-brain/issues) with:
   - Output of `bash setup/scripts/health-check.sh`
   - Output of `docker compose -f setup/docker-compose.nova.yml logs service-name`
   - Output of `nvidia-smi` (if GPU-related)
   - Your hardware profile (from `setup/.env`)
