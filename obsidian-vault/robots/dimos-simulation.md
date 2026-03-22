---
title: dimos Simulation Environment
tags: [robotics, simulation, mujoco, dimos, safety]
created: 2026-03-22
---

# dimos Simulation Environment

## Purpose
dimos provides a unified abstraction layer over simulation (MuJoCo) and real hardware.
The agent ALWAYS validates actions in simulation before executing on real hardware.

## Sim-First Safety Protocol
1. Plan trajectory in dimos simulation
2. Validate: no collisions, within joint limits, torque limits OK
3. Execute on real hardware through dimos abstraction
4. Verify: compare real result to simulated expectation
5. Log discrepancies to [[arm-control.SKILL]] and Memos #hardware

## Related Notes
- [[vision-pipeline.SKILL]] — camera feeds into sim for reality matching
- [[arm-control.SKILL]] — arm commands routed through dimos
- [[self-evaluation-protocol.SKILL]] — sim results feed self-eval loop
- [[TOOLS]] — dimos registered as MCP tool

## Source
- https://github.com/dimensionalOS/dimos
- MuJoCo: https://mujoco.org/
