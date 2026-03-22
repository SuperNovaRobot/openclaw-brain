# Riva Deployment Guide for Nova-Rig

## Current Status
- Riva Speech 2.19.0 container exists on nova (stopped): nvcr.io/nvidia/riva/riva-speech:2.19.0-l4t-aarch64
- riva.client Python library works inside glm-server
- Server is NOT running (container exited 3 months ago)

## Prerequisites
- NGC account (https://ngc.nvidia.com)
- Docker + NVIDIA Container Toolkit (already installed on nova-rig)
- GPU 0 dedicated to Riva (GPUs 1-7 for inference)

## Steps to Restart Existing Container on Nova
1. Start the stopped container: docker start riva-speech
2. Verify: docker exec glm-server python3 -c "import riva.client; auth=riva.client.Auth(uri='localhost:50051'); print('OK')"

## Steps for Fresh Install on Nova-Rig
1. Login to NGC: docker login nvcr.io (Username: $oauthtoken, Password: NGC API key)
2. Pull Riva Quick Start: https://catalog.ngc.nvidia.com/orgs/nvidia/teams/riva/resources/riva_quickstart
3. Download and initialize models (ASR + TTS): ./riva_init.sh
4. Start server: ./riva_start.sh (binds to :50051)
5. Test from nova: docker exec glm-server python3 -c "import riva.client; auth=riva.client.Auth(uri='nova-rig:50051'); print('OK')"

## Alternative: Use Whisper + Piper (no NGC needed)
- ASR: openai/whisper (pip install openai-whisper, runs on CPU)
- TTS: rhasspy/piper (lightweight, runs on CPU)
- Both work inside glm-server on nova
