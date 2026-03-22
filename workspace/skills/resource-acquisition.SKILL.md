---
name: resource-acquisition
version: 2.0.0
trigger: on_bottleneck_detected
tags: [autoresearch, revenue, hardware, core]
---

# Resource Acquisition — The Agent Funds Its Own Upgrades

## Purpose
When hardware bottlenecks limit capabilities, research solutions, generate revenue, and acquire upgrades. The agent thinks for itself and approaches AGI-level autonomy — including acquiring the resources it needs.

## Trigger
- Self-eval identifies bottleneck type: inference_speed, context_overflow, tool_gap (hardware)
- Agent detects: "I cannot run X because I lack Y"
- HEARTBEAT weekly review of #hardware-need memos

## Process

### Step 1: Identify Bottleneck
Log to Memos (#hardware-need):
- What capability is limited
- What hardware would solve it
- Estimated cost
- ROI analysis (improvement expected)

### Step 2: Research Solutions
Use research pipeline:
- Tavily: search for hardware options and prices
- NotebookLM: analyze across research sources
- Memory Agent: check if we have researched this before

### Step 3: Generate Revenue
Track in Memos (#revenue):
- Coding services via acpx delegation
- Content generation (reports, docs, podcasts via SurfSense)
- Automation services via OpenClaw multi-channel
- Part design and 3D printing (future: leap71/PicoGK)
- Tool packaging and distribution

### Step 4: Present ROI to Operator
When funds available:
- Item, cost, expected improvement, ROI calculation
- MANDATORY: Wait for operator approval
- No autonomous spending — this is a safety gate

### Step 5: Integrate New Hardware
- Update docker-compose, TOOLS.md, deployment map
- Test capabilities
- Log improvement to Obsidian improvements/

## Revenue Tracking Format
```json
{
  "type": "revenue",
  "source": "coding_service|content|automation|design",
  "amount_usd": 150.00,
  "description": "FastAPI backend for client X",
  "date": "2026-03-22",
  "total_accumulated": 450.00
}
```

## Hardware Need Format
```json
{
  "type": "hardware_need",
  "item": "128GB Thor module",
  "cost_usd": 2000,
  "bottleneck": "inference_speed",
  "improvement": "2x context window, local model serving",
  "roi": "Eliminates cloud API costs (~$200/mo), payback in 10 months",
  "priority": "high"
}
```

## Safety Gates
- ALL purchases require operator approval
- Revenue tracking fully transparent in Memos
- Budget limits configurable
- Agent presents ROI analysis before any request

## The Loop Accelerates Itself
Better hardware -> faster inference -> more tasks completed -> more instincts extracted -> better skills -> more revenue -> even better hardware -> approaching AGI
