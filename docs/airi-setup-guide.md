# airi Avatar Setup Guide

## Current Status
- Node.js v22.22.0: AVAILABLE
- Cargo/Rust: NOT INSTALLED (needed for Tauri native app)
- Display ($DISPLAY): NOT SET (no display connected)
- airi requires a display — Eve can set this up when HDMI/DP is connected

## Prerequisites
- Display connected to nova (HDMI or DisplayPort)
- Node.js (already installed v22)
- For native app: Cargo/Rust (for Tauri)

## Steps
1. Clone: git clone https://github.com/moeru-ai/airi.git /mnt/ssd/airi
2. Install: cd /mnt/ssd/airi && npm install
3. Start: DISPLAY=:0 npm run start -- --mode=robot
4. Configure expressions via API: http://localhost:3030

## Integration
- Lip sync driven by Riva TTS via voice-avatar-bridge.py
- Expressions mapped to agent state (thinking, speaking, error, happy)
