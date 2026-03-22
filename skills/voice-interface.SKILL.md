# Voice Interface (NVIDIA Riva ASR/TTS)

## Architecture
- **Riva Server**: nova-rig (GPU 0 dedicated), gRPC on port 50051
- **Riva Client**: nvidia-riva-client SDK inside glm-server on nova
- **Audio Hardware**: microphone + speaker connected to nova host
- **Protocol**: gRPC streaming for low-latency conversational interaction

## Pipeline

```
Microphone -> ASR (streaming) -> text -> agent pipeline -> response -> TTS (streaming) -> Speaker
                                          |
                                   same pipeline as
                                   text commands
```

Voice commands trigger the exact same agent pipeline as text commands — no separate logic.

## ASR (Speech-to-Text)

| Parameter | Value |
|-----------|-------|
| Language | en-US (primary) |
| Encoding | LINEAR_PCM |
| Sample Rate | 16000 Hz |
| Mode | Streaming (real-time) |
| Interim Results | Yes |
| Punctuation | Automatic |
| Endpointing | Voice activity detection |

### Streaming ASR Flow
1. Open gRPC streaming channel to nova-rig:50051
2. Stream microphone audio chunks (16kHz, 16-bit PCM)
3. Receive interim transcripts in real-time
4. Final transcript on utterance end (VAD-based)
5. Feed final transcript into agent text pipeline

## TTS (Text-to-Speech)

| Parameter | Value |
|-----------|-------|
| Language | en-US |
| Voice | English-US.Female-1 |
| Encoding | LINEAR_PCM |
| Sample Rate | 22050 Hz |
| Mode | Streaming |

### Streaming TTS Flow
1. Agent produces response text
2. Send text to Riva TTS via gRPC
3. Receive audio chunks as they are synthesized
4. Stream audio chunks to speaker immediately (low latency)
5. Simultaneously stream to [[avatar-display.SKILL]] for lip sync

## Commands

| Command | Description |
|---------|-------------|
| `asr_start_streaming()` | Begin streaming ASR from microphone |
| `asr_stop_streaming()` | Stop ASR stream, return final transcript |
| `asr_transcribe(audio_file)` | Offline transcription of audio file |
| `tts_synthesize(text)` | Synthesize speech from text, play on speaker |
| `tts_synthesize_to_file(text, path)` | Synthesize speech and save to WAV file |
| `get_available_voices()` | List available TTS voices |
| `set_voice(voice_name)` | Change active TTS voice |

## Safety — Voice Commands for Hardware

Voice commands that affect physical hardware require verbal confirmation:

1. User says: "Move the arm to the table"
2. Agent repeats via TTS: "I will move the arm to the table. Say confirm to proceed."
3. User says: "Confirm"
4. Agent executes through [[arm-control.SKILL]] safety chain

**Exempt from confirmation**: emergency stop ("stop", "halt", "freeze") — immediate execution.

### Confirmation Keywords
- **Execute**: "confirm", "yes", "do it", "go ahead", "proceed"
- **Cancel**: "cancel", "no", "stop", "abort", "never mind"
- **Emergency**: "stop", "halt", "freeze" — bypasses confirmation, triggers emergency stop

## Logging
- All transcripts logged to Memos #voice with timestamps
- Failed recognitions logged to Memos #voice-error
- Voice command history queryable for self-evaluation
- Audio recordings optionally saved to workspace/recordings/ for debugging

## Wake Word (Future)
- Not implemented yet — currently always-listening or push-to-talk
- Future: custom wake word via Riva keyword spotting
- Planned wake word: "Hey Eve" or configurable

## Integration
- Voice text feeds into the same pipeline as typed commands
- TTS output drives [[avatar-display.SKILL]] lip sync
- Hardware commands go through [[arm-control.SKILL]] safety chain
- Transcripts logged to Memos #voice for self-improvement analysis
- Voice interaction quality tracked in [[self-evaluation-protocol.SKILL]]

## Rules
- Voice commands for hardware ALWAYS require verbal confirmation
- Emergency stop voice command ALWAYS bypasses confirmation
- Riva client SDK runs inside Docker — not on system Python
- Riva server stays on nova-rig — never move to nova (needs dedicated GPU)
- Audio device failures gracefully fall back to text-only mode
