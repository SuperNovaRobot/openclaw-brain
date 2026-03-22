# Hardware Guide

OpenClaw Brain is designed to run on a range of hardware, from a single consumer GPU to a multi-machine setup with dedicated inference servers. This guide covers hardware recommendations at four budget tiers, with specific product suggestions and expected performance.

---

## Hardware Tiers at a Glance

| Tier | Hardware | Approx. Cost | What You Get |
|------|----------|-------------|--------------|
| **Minimal** | Single GPU 8GB+, 32GB RAM | ~$800 | Local inference (7B-13B models), full memory stack, basic self-improvement |
| **Recommended** | Multi-GPU 2-4x (24GB each), 64GB+ RAM | ~$3,000-5,000 | Full 70B+ models, all features, single machine |
| **Full** | Jetson Orin + multi-GPU rig (8x RTX 3090) | ~$8,000-12,000 | 122B model with 1M context, two-machine architecture, robotics-ready |
| **Cloud** | Any cloud GPU (A100, H100) | Pay-as-you-go | Full features, elastic scaling, no upfront cost |

---

## Tier 1: Minimal (~$800)

**Target audience:** Developers who want to experiment with OpenClaw Brain on a budget.

### Hardware Specifications

| Component | Recommendation | Notes |
|-----------|---------------|-------|
| **GPU** | NVIDIA RTX 3060 12GB | Best value for 12GB VRAM. RTX 3060 Ti or RTX 4060 Ti 16GB also work. |
| **CPU** | AMD Ryzen 5 5600 or Intel i5-12400 | 6 cores minimum for Docker services |
| **RAM** | 32GB DDR4 | 16GB for the OS/Docker, 16GB headroom |
| **Storage** | 500GB NVMe SSD | Models take 5-15GB (quantized), services need ~50GB |
| **PSU** | 550W 80+ Bronze | Adequate for single-GPU builds |

### Specific Products

- **GPU:** EVGA/MSI/Gigabyte RTX 3060 12GB (~$250 used, ~$330 new)
- **CPU:** AMD Ryzen 5 5600 (~$120)
- **Motherboard:** B550 ATX (MSI B550-A Pro) (~$100)
- **RAM:** 2x16GB DDR4-3200 (Corsair Vengeance LPX) (~$55)
- **SSD:** Samsung 980 Pro 500GB NVMe (~$50)
- **PSU:** Corsair CX550M (~$60)
- **Case:** Fractal Design Focus G (~$60)

### What Works at This Tier

| Feature | Status | Notes |
|---------|--------|-------|
| Local inference (7B models) | Full speed | Mistral 7B, Llama 3.1 8B run well in 12GB VRAM |
| Local inference (13B models) | Good | Llama 3.1 13B with Q4 quantization fits in 12GB |
| Local inference (70B+ models) | Not feasible | Insufficient VRAM |
| Memory stack (all 5 layers) | Full | PostgreSQL, Elasticsearch, Redis, Memos, RagFlow, Obsidian all run fine |
| Self-improvement loop | Full | All evaluation, research, and skill evolution works |
| Sub-agent delegation (acpx) | Full | Claude Code and Codex delegation via API |
| Context window | ~32K-128K tokens | Limited by model and VRAM; use `/compact` frequently |
| Docker services | All core services | May need to reduce Elasticsearch heap (`-Xms2g -Xmx2g`) |

### Performance Expectations

- **Inference speed:** ~20-40 tokens/sec with Mistral 7B (Q4_K_M)
- **Context window:** 32K-128K tokens depending on model
- **Startup time:** ~2 minutes for all Docker services
- **RAM usage:** ~18-22GB total (Docker services + inference)

### Configuration Tips

```bash
# In setup/.env, adjust for minimal hardware:
VLLM_MAX_MODEL_LEN=131072          # Reduced context window
ES_JAVA_OPTS=-Xms2g -Xmx2g        # Reduced Elasticsearch heap
```

---

## Tier 2: Recommended (~$3,000-5,000)

**Target audience:** Serious users who want the full OpenClaw Brain experience on a single machine.

### Hardware Specifications

| Component | Recommendation | Notes |
|-----------|---------------|-------|
| **GPU** | 2x NVIDIA RTX 3090 24GB or 1x RTX 4090 24GB | 48GB total VRAM for 70B models; 4090 if you prefer single-GPU simplicity |
| **CPU** | AMD Ryzen 9 5900X or Intel i7-13700K | 12+ cores for Docker + inference concurrency |
| **RAM** | 64GB DDR4 | Comfortable headroom for all services |
| **Storage** | 1TB NVMe SSD + 2TB SATA SSD | NVMe for models and databases, SATA for vault/logs |
| **PSU** | 1000W 80+ Gold | Dual 3090s pull ~700W under load |
| **Cooling** | Tower cooler + good case airflow | 3090s run hot; mesh front panel recommended |

### Specific Products

- **GPU Option A:** 2x NVIDIA RTX 3090 24GB (~$700 each used, ~$1,400 total)
- **GPU Option B:** 1x NVIDIA RTX 4090 24GB (~$1,600 new)
- **CPU:** AMD Ryzen 9 5900X (~$250)
- **Motherboard:** X570 ATX with 2+ PCIe x16 slots (ASUS TUF X570-Plus) (~$160)
- **RAM:** 2x32GB DDR4-3600 (G.Skill Ripjaws V) (~$90)
- **SSD:** Samsung 980 Pro 1TB NVMe (~$90) + Samsung 870 EVO 2TB (~$120)
- **PSU:** Corsair RM1000x (~$170)
- **Case:** Fractal Design Meshify 2 XL or Phanteks Enthoo Pro 2 (~$150)

### What Works at This Tier

| Feature | Status | Notes |
|---------|--------|-------|
| Local inference (70B models) | Full speed | Llama 3.1 70B, Qwen 2.5 72B, Nemotron 70B |
| Local inference (122B models) | Partial | Requires aggressive quantization (Q3/Q4) on 2x 3090 |
| Context window | 128K-512K tokens | Depends on model and quantization |
| All memory layers | Full | Generous RAM for all Docker services |
| Self-improvement loop | Full | Fast enough for real-time evaluation |
| ClawTeam swarms | Full | Enough CPU/RAM for parallel sub-agents |
| vLLM tensor parallelism | 2-way | With 2x 3090 via NVLink bridge or PCIe |

### Performance Expectations

- **Inference speed:** ~15-25 tokens/sec with Llama 3.1 70B (AWQ, 2x 3090)
- **Inference speed:** ~30-50 tokens/sec with Llama 3.1 70B (AWQ, 1x 4090)
- **Context window:** Up to 512K tokens with vLLM PagedAttention
- **Startup time:** ~3 minutes for all services + model loading
- **RAM usage:** ~35-45GB total

### Configuration Tips

```bash
# In setup/.env, for dual 3090 setup:
VLLM_TENSOR_PARALLEL=2
VLLM_MAX_MODEL_LEN=524288
VLLM_MODEL=Qwen2.5-72B-Instruct-AWQ

# For single 4090:
VLLM_TENSOR_PARALLEL=1
VLLM_MAX_MODEL_LEN=131072
VLLM_MODEL=Qwen2.5-72B-Instruct-AWQ
```

---

## Tier 3: Full Reference Setup (~$8,000-12,000)

**Target audience:** Users building the complete OpenClaw Brain with robotics support, matching the reference two-machine architecture.

This is the setup OpenClaw Brain was designed around. The brain runs on a compact, power-efficient Jetson Orin while heavy inference is offloaded to a dedicated multi-GPU server.

### Machine 1: Nova (The Brain)

| Component | Specification | Notes |
|-----------|--------------|-------|
| **Platform** | NVIDIA Jetson AGX Orin 64GB | JetPack 6, CUDA 12.6, unified memory |
| **RAM** | 64GB LPDDR5 (unified with GPU) | Shared between CPU and GPU workloads |
| **Storage** | 512GB NVMe SSD (via M.2) | Mount as /mnt/ssd for all data |
| **Networking** | 10GbE or Wi-Fi 6E | Low-latency connection to nova-rig |
| **Peripherals** | OAK-D Pro (depth camera), USB serial (robot arm/hand) | Phase 6 robotics |

**Approximate cost:** ~$1,500-2,000 (Jetson Orin Developer Kit)

**Nova runs:**
- OpenClaw Gateway (agent runtime)
- All Docker services (PostgreSQL, Elasticsearch, Redis, RagFlow, Memos, SurfSense, crawl4ai)
- MCP servers (obsidian-cli, Behavior MCPs)
- Obsidian vault
- ~22GB RAM used by services, ~37GB headroom

### Machine 2: Nova-Rig (The Muscle)

| Component | Specification | Notes |
|-----------|--------------|-------|
| **GPU** | 8x NVIDIA RTX 3090 24GB | 192GB total VRAM, 8-way tensor parallelism |
| **CPU** | AMD Threadripper Pro 3995WX (64 cores) | Handles data loading for 8 GPUs |
| **RAM** | 256GB DDR4 ECC | Model weights + KV cache for 1M context |
| **Storage** | 2TB NVMe SSD | Models + swap space |
| **PSU** | 2x 1600W Titanium | 8x 3090 at full load draw ~2800W |
| **Cooling** | Custom loop or industrial fans | 8 GPUs generate serious heat |

**Approximate cost:** ~$6,000-10,000 (varies heavily with used GPU prices)

**Nova-rig runs:**
- vLLM serving Nemotron 122B with 8-way tensor parallelism
- OpenAI-compatible API on port 8080
- AWQ quantization for optimal VRAM utilization

### What Works at This Tier

| Feature | Status | Notes |
|---------|--------|-------|
| Nemotron 122B inference | Full | 8-way tensor parallel on 192GB VRAM |
| 1M token context window | Full | vLLM PagedAttention across 8 GPUs |
| All memory layers | Full | Generous resources on Jetson |
| Self-improvement loop | Full | Fast inference enables rapid iteration |
| Robotics (Phase 6) | Ready | Jetson has camera/serial ports, CUDA for perception |
| ClawTeam swarms | Full | Both machines have plenty of compute |
| Model hot-swapping | Full | Switch models without restarting vLLM |
| Voice (nvidia-riva) | Ready | Can run ASR/TTS on nova-rig spare capacity |

### Performance Expectations

- **Inference speed:** ~20-35 tokens/sec with Nemotron 122B (AWQ, 8x 3090)
- **Context window:** Full 1M tokens (1,048,576)
- **Time to first token:** ~2-5 seconds at high context lengths
- **Nova services startup:** ~3 minutes
- **Model loading:** ~2-5 minutes (122B weights across 8 GPUs)
- **Nova RAM usage:** ~22GB (37GB headroom)
- **Nova-rig VRAM usage:** ~170GB of 192GB

### Network Configuration

The two machines must communicate with low latency:

```bash
# On nova (the brain), in setup/.env:
RIG_HOST=nova-rig                      # or the IP address of your GPU rig
INFERENCE_HOST=http://nova-rig:8080    # vLLM endpoint on the rig

# On nova-rig, start inference:
docker compose -f setup/docker-compose.rig.yml up -d
```

**Recommended networking:** Direct Ethernet connection (10GbE ideal, 1GbE acceptable). The primary traffic is API requests and responses -- not large data transfers -- so even 1GbE is fine for most workloads.

---

## Tier 4: Cloud (Pay-as-you-go)

**Target audience:** Users who want full capabilities without owning hardware, or who need elastic scaling.

### Recommended Cloud GPUs

| Provider | GPU | VRAM | Approx. Cost | Best For |
|----------|-----|------|-------------|----------|
| **RunPod** | 1x A100 80GB | 80GB | ~$1.50/hr | 70B models with long context |
| **RunPod** | 8x A100 80GB | 640GB | ~$12/hr | 122B+ models, 1M context |
| **Lambda** | 1x H100 80GB | 80GB | ~$2.50/hr | Fastest single-GPU inference |
| **Lambda** | 8x H100 80GB | 640GB | ~$20/hr | Maximum performance |
| **Vast.ai** | Various | Varies | ~$0.30-2/hr | Budget cloud, variable availability |
| **AWS** | p4d.24xlarge (8x A100) | 320GB | ~$32/hr | Enterprise, managed infrastructure |

### Architecture for Cloud

Run the brain locally (even on a laptop) and point inference to the cloud:

```
Your Machine (brain)                    Cloud GPU (muscle)
  OpenClaw Gateway                        vLLM serving your model
  Docker services                         OpenAI-compatible API
  Obsidian vault
  
  INFERENCE_HOST=http://cloud-ip:8080
```

### Setup

1. **Spin up a cloud GPU instance** with the vLLM Docker image
2. **Upload your model** to the instance
3. **Start vLLM:**
   ```bash
   docker run --gpus all -p 8080:8000 \
     -v /models:/models \
     vllm/vllm-openai:latest \
     --model /models/your-model \
     --tensor-parallel-size 8 \
     --max-model-len 1048576 \
     --gpu-memory-utilization 0.95
   ```
4. **Point your local install at the cloud:**
   ```bash
   # In setup/.env on your local machine:
   RIG_HOST=your-cloud-ip
   INFERENCE_HOST=http://your-cloud-ip:8080
   ```
5. **Run the installer locally** -- it will set up all services except inference

### Cost Optimization

- **Use spot instances** on RunPod/Vast.ai for 50-70% savings
- **Stop the GPU when idle** -- the brain machine handles all non-inference tasks
- **Use a smaller model** (70B instead of 122B) for 8x cost reduction
- **Batch inference** -- the self-improvement loop can queue evaluations

---

## GPU Comparison Table

For quick reference, here is how common GPUs compare for LLM inference:

| GPU | VRAM | FP16 TFLOPS | Approx. Price (Used) | Max Model Size (AWQ) |
|-----|------|------------|----------------------|---------------------|
| RTX 3060 12GB | 12GB | 12.7 | ~$250 | 7B-13B |
| RTX 3070 Ti | 8GB | 21.7 | ~$280 | 7B |
| RTX 3080 10GB | 10GB | 29.8 | ~$350 | 7B-13B |
| RTX 3090 24GB | 24GB | 35.6 | ~$700 | 13B-30B |
| RTX 4060 Ti 16GB | 16GB | 22.1 | ~$400 | 13B |
| RTX 4070 Ti Super | 16GB | 40.0 | ~$650 | 13B |
| RTX 4090 24GB | 24GB | 82.6 | ~$1,600 | 13B-30B |
| A100 80GB | 80GB | 77.9 | ~$8,000 | 70B |
| H100 80GB | 80GB | 267.6 | ~$25,000 | 70B |
| Jetson Orin 64GB | 64GB (unified) | 5.3 | ~$1,500 | 30B (or offload) |

**Multi-GPU scaling:** Combine GPUs via tensor parallelism in vLLM. 2x RTX 3090 = 48GB effective VRAM, 4x = 96GB, 8x = 192GB. NVLink helps but is not required; PCIe works fine for inference.

---

## Storage Recommendations

| Use Case | Type | Minimum | Recommended |
|----------|------|---------|-------------|
| Model weights | NVMe SSD | 50GB | 500GB (multiple models) |
| Docker volumes (PostgreSQL, Elasticsearch) | NVMe SSD | 50GB | 200GB |
| Obsidian vault + logs | Any SSD | 10GB | 50GB |
| Model download cache | Any | 100GB | 500GB |

**Important:** Always mount your data directory on SSD, not spinning disk. Elasticsearch and PostgreSQL performance degrades significantly on HDD.

---

## Upgrade Path

The beauty of OpenClaw Brain's architecture is that you can start minimal and upgrade incrementally:

```
Tier 1 (Single GPU)
  │
  ├── Add a second GPU → Tier 2 (dual GPU, 70B models)
  │
  ├── Add more GPUs → Tier 2+ (4x GPU, larger context)
  │
  ├── Add a Jetson Orin → Tier 3 (two-machine, robotics-ready)
  │
  └── Add cloud GPUs → Tier 4 (elastic scaling)
```

Each upgrade requires only changing `setup/.env` and restarting services. The agent, its memory, its skills, and its personality carry over unchanged. The self-improvement loop even identifies when hardware is the bottleneck and can recommend the next upgrade (see [Self-Improvement Guide](self-improvement.md)).
