---
title: OAK-D Pro Vision Pipeline
tags: [robotics, vision, camera, depth, oakd, depthai]
created: 2026-03-22
---

# OAK-D Pro Vision Pipeline

## Hardware
- Luxonis OAK-D Pro stereo depth camera
- RGB 4K sensor + stereo depth pair + IR dot projector
- On-device Intel Movidius Myriad X VPU for neural inference
- Connection: USB3 to nova (Jetson Orin)

## Capabilities
- Depth mapping (stereo + active IR)
- RGB capture up to 4K
- On-device object detection (YOLO, MobileNet)
- On-device pose estimation
- 3D point cloud generation
- Hardware-accelerated encoding (H.264/H.265)

## Calibration
- 9x6 checkerboard pattern, 25mm squares
- Hold pattern at 10+ positions covering full FOV
- Verify: depth accuracy < 2% error at 1m distance
- Re-calibrate after any physical mounting change

## Related Notes
- [[dimos-simulation]] — visual data feeds simulation for scene matching
- [[arm-control.SKILL]] — camera must verify before arm commands
- [[robotics-simulation.SKILL]] — sim uses depth data for collision avoidance
- [[TOOLS]] — OAK-D registered as MCP tool

## Source
- https://docs.luxonis.com/
- DepthAI SDK: pip install depthai (inside Docker)
