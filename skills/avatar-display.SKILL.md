# Avatar Display (moeru-ai/airi)

## Purpose
Animated avatar face for the robot, displayed on nova connected screen.
Provides visual personality — the agent has a face that reacts to what it is doing.

## Hardware
- **Display**: HDMI/DP connected screen on nova (Jetson Orin)
- **Resolution**: 1920x1080 fullscreen
- **Rendering**: Electron, Tauri, or browser-based (depending on airi mode)

## Expression Control

| Expression | Trigger | Visual |
|-----------|---------|--------|
| neutral | Idle state | Relaxed face, idle breathing + eye blink |
| happy | Task completed successfully | Smile, brightened eyes |
| thinking | Processing query, running tools | Slightly furrowed brow, looking away |
| listening | ASR active, microphone streaming | Attentive eyes, slight head tilt |
| speaking | TTS active, audio playing | Mouth moves (lip sync), engaged expression |
| error | Error occurred, something failed | Concerned expression, visual indicator |
| surprised | Unexpected input or discovery | Wide eyes, raised eyebrows |
| concerned | Safety issue, hardware anomaly | Furrowed brow, cautious expression |

### Expression State Machine
```
                    +--- query received ---> thinking
                    |                           |
neutral ----------> |                      tool calls / processing
  ^                 |                           |
  |                 +--- ASR started -----> listening
  |                 |                           |
  |                 |                    utterance complete
  |                 |                           |
  task done --------+                           v
  (happy -> neutral)|                      thinking
                    |                           |
                    |                    response ready
                    |                           |
                    |                           v
                    |                      speaking (lip sync)
                    |                           |
                    +---- error ----------> error
```

## Lip Sync

Lip sync is driven by Riva TTS audio output:

1. Agent generates response text
2. Text sent to Riva TTS (streaming)
3. TTS audio stream split: speaker output + viseme data
4. airi receives viseme/amplitude data in real-time
5. Avatar mouth animates synchronized with audio

### Viseme Mapping
- Audio amplitude -> mouth openness (simple mode)
- Riva viseme output -> phoneme-accurate mouth shapes (advanced mode)
- Fallback: amplitude-based if viseme data unavailable

## Idle Animations
When no active interaction:
- Breathing animation (subtle body movement)
- Eye blinking (randomized natural interval)
- Micro-expressions (occasional subtle face changes)
- Optional: slow ambient eye tracking

## Commands

| Command | Description |
|---------|-------------|
| `set_expression(name)` | Set avatar expression (neutral, happy, thinking, etc.) |
| `set_lip_sync(audio_stream)` | Feed audio for lip sync animation |
| `set_idle_animation(enabled)` | Toggle idle animations |
| `get_current_expression()` | Get current expression state |
| `set_background(theme)` | Change display background |
| `set_avatar_model(model)` | Switch avatar model/skin |
| `show_text_overlay(text)` | Display text overlay on screen |
| `hide_text_overlay()` | Remove text overlay |

## Integration
- Expression changes with agent state — automatic, not manual
- Lip sync driven by [[voice-interface]] TTS output
- Expression transitions logged for self-eval (did the face match the situation?)
- Avatar state visible to [[vision-pipeline.SKILL]] (screen can be captured for debugging)
- Related: [[robots/]] directory for all robotics hardware notes

## Display Modes
- **Fullscreen**: avatar fills entire display (default for robot face)
- **Overlay**: avatar in corner, main screen shows other content
- **Debug**: avatar + live transcripts + system state panel

## Rules
- Expression MUST match agent state — never show happy during error
- Lip sync MUST be real-time — visible lag breaks immersion
- Idle animations MUST be active when no interaction — never a frozen face
- Display failure should NOT crash the agent — avatar is visual-only, agent continues
- airi manages its own rendering — agent only sends state updates via MCP
