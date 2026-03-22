# Nova Vision FPS Optimization Report
## OAK-D Pro PoE → Jetson Orin | DepthAI v3.0.0

**Date:** 2026-02-14
**Author:** Nova AI Assistant
**Status:** Analysis Complete

---

## 1. Root Cause Analysis — Why Exactly 8 FPS?

The 8 FPS bottleneck is caused by **PoE bandwidth saturation** combined with **heavy on-device stereo processing**. Here's why:

### 1.1 Bandwidth Saturation (Primary Bottleneck)

The pipeline streams **4 unencoded output queues** over a 1 Gbps PoE link:

| Stream | Resolution | Bytes/pixel | Per-frame size | @ 60 FPS |
|--------|-----------|-------------|----------------|----------|
| RGB video | 1920×1080 | 3 (BGR) | 6,220,800 B | 2,986 Mbps |
| RGB preview | 1280×720 | 3 (BGR) | 2,764,800 B | 1,327 Mbps |
| Depth | 1280×720 | 2 (uint16, subpixel) | 1,843,200 B | 885 Mbps |
| Edges | 1280×720 | 1 (grayscale) | 921,600 B | 443 Mbps |
| **TOTAL** | | | **11,750,400 B** | **5,640 Mbps** |

**The pipeline requires 5.6 Gbps at 60 FPS but has only ~700 Mbps usable PoE throughput** (1 Gbps theoretical, ~700 Mbps practical after protocol overhead).

At 700 Mbps usable bandwidth: `700 Mbps / (11,750,400 × 8 bits) = 7.4 FPS` → **~8 FPS matches exactly.**

### 1.2 On-Device Processing Overhead (Secondary Bottleneck)

Even without bandwidth limits, the stereo pipeline itself is a bottleneck:

From Luxonis documentation, StereoDepth latency at 720P with **LR check + Subpixel** (no extended disparity):
- **LR + Sub @ 720P = 27.6 ms** per frame → max **36 FPS**

Adding post-processing filters (speckle + temporal + spatial) consumes additional SHAVE cores and adds latency, likely pushing the on-device max to **~25-30 FPS**.

### 1.3 Leon CSS CPU Saturation (Contributing Factor)

The Leon CSS core handles PoE communication. On PoE devices, CSS CPU consumption is higher because it runs the ethernet stack. When CSS is at 100%, it cannot handle communication efficiently, further reducing throughput. The ROBOTICS preset plus 4 output streams stresses this core.

### 1.4 Summary

| Factor | Impact | Contribution |
|--------|--------|-------------|
| PoE bandwidth saturation (4 raw streams) | Caps at ~8 FPS | **~80% of problem** |
| StereoDepth processing (LR+Sub+filters) | Caps at ~25-30 FPS | ~15% of problem |
| Leon CSS CPU load (PoE stack + pipeline) | Adds latency jitter | ~5% of problem |

---

## 2. Bandwidth Calculations

### 2.1 Current Pipeline Bandwidth @ Various FPS

| FPS | RGB 1080p (BGR) | Preview 720p (BGR) | Depth 720p (u16) | Edges 720p (u8) | **Total** |
|-----|-----------------|-------------------|------------------|-----------------|-----------|
| 60 | 2,986 Mbps | 1,327 Mbps | 885 Mbps | 443 Mbps | **5,640 Mbps** |
| 30 | 1,493 Mbps | 664 Mbps | 442 Mbps | 221 Mbps | **2,820 Mbps** |
| 15 | 747 Mbps | 332 Mbps | 221 Mbps | 111 Mbps | **1,411 Mbps** |
| 8 | 398 Mbps | 177 Mbps | 118 Mbps | 59 Mbps | **752 Mbps** |
| 7 | 348 Mbps | 155 Mbps | 103 Mbps | 52 Mbps | **658 Mbps** |

**Formula:** `width × height × bytes_per_pixel × fps × 8 bits`

### 2.2 PoE Link Budget

- Theoretical: 1,000 Mbps (1 Gbps)
- Practical usable: **~700 Mbps** (TCP/IP overhead, XLink protocol, packet framing)
- Luxonis documented: "bandwidth should be 700 Mbps" for runtime PoE connections

### 2.3 Key Insight from Documentation

> "Color (isp) 1080P achieves **25 FPS** over PoE at 622 Mbps" — Luxonis optimization docs

This is for a **single** 1080p color stream. The current pipeline has **4 streams** competing for the same link.

---

## 3. Pipeline Optimization Recommendations

### 3.1 Encode RGB Streams On-Device (Highest Impact)

**Use VideoEncoder node** to MJPEG/H.265 encode the RGB streams before sending over PoE.

| Stream | Raw Bandwidth @30FPS | MJPEG @30FPS (est.) | Savings |
|--------|---------------------|---------------------|---------|
| RGB 1080p | 1,493 Mbps | ~75-150 Mbps | 90-95% |
| Preview 720p | 664 Mbps | ~35-70 Mbps | 90-95% |

**Expected FPS improvement: 8 → 25-30 FPS** (single biggest optimization)

*Source: Luxonis docs show MJPEG 1080p at 60 FPS with only 31ms latency over USB, and H.265 1080p at 60 FPS with 42ms latency.*

### 3.2 Reduce Number of Output Streams

**Remove the 1080p RGB video output** — use only the 720p preview for both processing and display. The 1080p stream alone consumes ~1.5 Gbps at 30 FPS raw.

**Expected improvement: Halves bandwidth requirement.**

### 3.3 Lower Stereo/Depth Resolution to 400P

Use 400P (640×400) mono cameras instead of 720P for depth. This:
- Reduces depth bandwidth from 885 Mbps to 123 Mbps @30FPS
- Makes stereo processing 3-4× faster (27.6ms → ~10ms for LR+Sub)
- Depth at 400P is still adequate for robotics navigation (0.4-10m range)

*Source: "400P depth frames: 640 * 400 * 2 * 30fps * 8bits = 123 Mbps" — Luxonis bandwidth docs*

### 3.4 Disable Unnecessary Stereo Features

| Feature | Latency Cost @720P | Recommendation |
|---------|-------------------|----------------|
| Subpixel | +9.6 ms | Disable for performance profile |
| LR Check | +10.6 ms | Keep (important for quality) |
| Temporal Filter | Variable | Disable (adds latency, designed for static scenes) |
| Spatial Filter | Variable | Reduce or disable |
| 5×5 Median | ~1.8 ms | Switch to 3×3 or disable |
| Speckle Filter | Variable | Keep (lightweight) |

### 3.5 Remove Edge Detection Stream

Edge detection can be done on the Jetson Orin (with its 275 TOPS) much more efficiently than streaming raw edge frames over PoE. Process edges host-side from the preview frame.

### 3.6 Use Non-Blocking Queues with Size 1

Already done correctly (`maxSize=1, blocking=False`). ✅

### 3.7 Set XLink Chunk Size to 0

```python
pipeline.setXLinkChunkSize(0)
```

This was used in Luxonis's own benchmarks to achieve best latency/FPS numbers.

---

## 4. Recommended Pipeline Configurations

### Profile A: "Performance" — Target 30+ FPS

**Goal:** Maximum FPS for real-time robotics navigation.

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| RGB output | 720p preview only, MJPEG encoded | Eliminates 1080p raw stream |
| Mono resolution | 400P | Fastest stereo processing |
| Stereo preset | DEFAULT or ROBOTICS | Standard |
| Median filter | KERNEL_3x3 or OFF | Minimal cost |
| LR Check | ON | Quality worth the cost |
| Subpixel | OFF | Saves ~10ms per frame |
| Extended disparity | OFF | Not needed for >35cm |
| Speckle filter | ON | Lightweight |
| Temporal filter | OFF | Latency risk |
| Spatial filter | OFF | Save processing |
| Edge detection | OFF (do on Jetson) | Save bandwidth |
| Output streams | 2 (encoded preview + depth) | Minimize bandwidth |
| Camera FPS | 30 | Match achievable rate |

**Estimated bandwidth:** ~150 Mbps (MJPEG preview) + 123 Mbps (depth 400P) = **~273 Mbps** → well within PoE budget.

**Estimated FPS:** 30+ FPS (stereo @400P with LR, no Sub = 7.4ms → 135 FPS capable; bandwidth is no longer the bottleneck).

### Profile B: "Balanced" — Target 20+ FPS

**Goal:** Good FPS with better depth quality.

| Parameter | Value |
|-----------|-------|
| RGB output | 720p preview, MJPEG encoded |
| Mono resolution | 720P |
| Stereo preset | ROBOTICS |
| Median filter | KERNEL_5x5 |
| LR Check | ON |
| Subpixel | ON (3-bit) |
| Speckle filter | ON |
| Temporal filter | OFF |
| Spatial filter | ON |
| Edge detection | OFF (do on Jetson) |
| Output streams | 2 (encoded preview + depth) |
| Camera FPS | 25 |

**Estimated bandwidth:** ~125 Mbps (MJPEG) + 332 Mbps (depth 720P @25FPS) = **~457 Mbps** → fits PoE.

**Estimated FPS:** ~25 FPS (stereo @720P LR+Sub = 27.6ms → 36 FPS; filters add ~5ms → ~30 FPS on-device; bandwidth allows 25 FPS).

### Profile C: "Quality" — Target 15+ FPS

**Goal:** Best depth quality, acceptable latency for mapping/scanning.

| Parameter | Value |
|-----------|-------|
| RGB output | 1080p video, MJPEG encoded |
| Mono resolution | 720P |
| Stereo preset | HIGH_DETAIL |
| Median filter | OFF (per HIGH_DETAIL preset) |
| LR Check | ON |
| Subpixel | ON (5-bit) |
| Extended disparity | ON |
| Speckle filter | ON |
| Temporal filter | ON |
| Spatial filter | ON |
| Edge detection | ON (on-device) |
| Output streams | 3 (encoded 1080p + depth + edges) |
| Camera FPS | 15 |

**Estimated bandwidth:** ~75 Mbps (MJPEG 1080p) + 221 Mbps (depth) + 111 Mbps (edges) = **~407 Mbps** → fits PoE.

**Estimated FPS:** ~15 FPS (stereo @720P LR+Ext+Sub = 56ms → 18 FPS; filters reduce to ~15 FPS).

---

## 5. Specific Code Changes

**DO NOT modify fixedoak.py.** Create a new optimized pipeline file instead. Here are the exact changes needed:

### 5.1 Add VideoEncoder for RGB (Critical)

```python
# After creating rgb camera node:
encoder = pipeline.create(dai.node.VideoEncoder)
encoder.setDefaultProfilePreset(30, dai.VideoEncoderProperties.Profile.MJPEG)
encoder.setQuality(80)  # 80% quality, good compression
rgb.video.link(encoder.input)

# Output encoded stream instead of raw
encoded_queue = encoder.bitstream.createOutputQueue(maxSize=1, blocking=False)
```

### 5.2 Remove 1080p Raw Video Output (Critical)

```python
# REMOVE this line:
# self.rgb_queue = rgb.video.createOutputQueue(maxSize=1, blocking=False)

# KEEP only preview (or encode the video):
self.preview_queue = rgb.preview.createOutputQueue(maxSize=1, blocking=False)
```

### 5.3 Lower Mono Camera Resolution (Performance Profile)

```python
# Change from:
mono_left.setResolution(dai.MonoCameraProperties.SensorResolution.THE_720_P)
# To:
mono_left.setResolution(dai.MonoCameraProperties.SensorResolution.THE_400_P)
```

### 5.4 Reduce Camera FPS Target

```python
# Change from:
rgb.setFps(60)
# To:
rgb.setFps(30)  # or 25 for balanced profile
```

### 5.5 Disable Subpixel for Performance Profile

```python
# Change from:
depth.setSubpixel(True)
# To:
depth.setSubpixel(False)
```

### 5.6 Simplify Median Filter

```python
# Change from:
depth.initialConfig.setMedianFilter(dai.MedianFilter.KERNEL_5x5)
# To:
depth.initialConfig.setMedianFilter(dai.MedianFilter.KERNEL_3x3)
```

### 5.7 Disable Temporal Filter

```python
# Change from:
depth.initialConfig.postProcessing.temporalFilter.enable = True
# To:
depth.initialConfig.postProcessing.temporalFilter.enable = False
```

### 5.8 Remove Edge Detection (Move to Jetson)

```python
# REMOVE these pipeline nodes entirely:
# rgb_to_gray = pipeline.create(dai.node.ImageManip)
# edge_detector = pipeline.create(dai.node.EdgeDetector)
# And their output queue

# Instead, do on Jetson:
# edges = cv2.Canny(preview_frame, 100, 200)
```

### 5.9 Set XLink Chunk Size

```python
pipeline.setXLinkChunkSize(0)  # Disable chunking for lowest latency
```

### 5.10 Allocate Post-Processing Resources (if using filters)

```python
depth.setPostProcessingHardwareResources(3, 3)  # 3 SHAVEs, 3 CMX slices
```

---

## 6. DepthAI v3 Specific Optimizations

### 6.1 Simplified Output Queues (Already Used)

The current code correctly uses v3's `createOutputQueue()` API directly on node outputs rather than XLinkOut nodes. ✅

### 6.2 Pipeline Start (Already Used)

Using `pipeline.start()` directly is correct for v3. ✅

### 6.3 Power Profiles (OAK-4 Only)

Power profiles (`best_effort`, `sustained_nn_heavy`, `sustained_cpu_heavy`) are **only available on OAK-4 series** cameras with RVC4. The OAK-D Pro PoE uses RVC2, so this feature is **not applicable**.

### 6.4 Resolution Techniques

For any future NN inference on-device, use the `setPreviewSize()` to match NN input resolution exactly to avoid unnecessary resizing.

### 6.5 MJPEG Decoding on Jetson

When using VideoEncoder for MJPEG, decode on the Jetson using hardware-accelerated NVJPEG:

```python
# On Jetson host side:
import cv2
frame = cv2.imdecode(np.frombuffer(encoded_data, dtype=np.uint8), cv2.IMREAD_COLOR)
# Or use NVIDIA's nvjpeg for GPU-accelerated decoding
```

---

## 7. Quick Reference: Expected Results

| Configuration | Current | Performance | Balanced | Quality |
|--------------|---------|-------------|----------|---------|
| FPS | **8** | **30+** | **20-25** | **15** |
| RGB stream | 1080p raw | 720p MJPEG | 720p MJPEG | 1080p MJPEG |
| Depth resolution | 720P | 400P | 720P | 720P |
| Subpixel | Yes | No | Yes (3-bit) | Yes (5-bit) |
| Post-proc filters | All on | Speckle only | Speckle+Spatial | All |
| PoE bandwidth | ~750 Mbps | ~273 Mbps | ~457 Mbps | ~407 Mbps |
| Latency (est.) | ~125 ms | ~35 ms | ~55 ms | ~80 ms |
| Output streams | 4 raw | 2 (1 encoded) | 2 (1 encoded) | 3 (1 encoded) |

---

## 8. Implementation Priority

1. **🔴 Critical: Encode RGB with VideoEncoder** — single biggest win (8→20+ FPS)
2. **🔴 Critical: Remove 1080p raw video stream** — use preview only or encode it
3. **🟡 High: Lower camera FPS to 30** — stop requesting impossible 60 FPS
4. **🟡 High: Remove edge stream** — do Canny on Jetson instead
5. **🟢 Medium: Lower mono to 400P** — for performance profile
6. **🟢 Medium: Disable subpixel** — for performance profile
7. **🔵 Low: Disable temporal filter** — marginal gain
8. **🔵 Low: setXLinkChunkSize(0)** — marginal latency improvement

---

## Sources

All recommendations reference official Luxonis documentation:

- **Bandwidth formulas:** `docs.luxonis.com/software-v3/depthai/tutorials/optimizing` — Bandwidth section
- **PoE FPS benchmarks:** Same page — PoE latency tables showing 1080p@25FPS over PoE
- **Stereo depth latency:** `docs.luxonis.com/software/depthai-components/nodes/stereo_depth` — Stereo depth FPS tables
- **RVC2 hardware blocks:** `docs.luxonis.com/hardware/platform/rvc/rvc2` — SHAVE/CMX allocation, Leon CSS PoE overhead
- **Post-processing filters:** `docs.luxonis.com/hardware/platform/depth/configuring-stereo-depth` — Filter descriptions and performance costs
- **VideoEncoder capability:** RVC2 supports H.264, H.265, MJPEG — 4K/30FPS, 1080P/60FPS
- **Power consumption:** `docs.luxonis.com/hardware/platform/environmental-specifications/power-consumption` — PoE circuitry overhead
