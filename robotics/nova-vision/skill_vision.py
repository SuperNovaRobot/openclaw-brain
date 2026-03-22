#!/usr/bin/env python3
"""
Nova Vision Skill — OpenClaw integration.

This script provides vision capabilities that Nova's AI can invoke:
- look: Describe what's in front of Nova
- find <object>: Search for a specific object
- snapshot: Take a photo
- spatial: Get spatial awareness data
- status: Vision system status
- who: Identify people

Usage from OpenClaw or command line:
    python3 skill_vision.py look
    python3 skill_vision.py find "cup"
    python3 skill_vision.py snapshot
    python3 skill_vision.py spatial
    python3 skill_vision.py who
    python3 skill_vision.py status
"""

import sys
import json
import time
import logging
from pathlib import Path

# Suppress noisy logs for skill invocations
logging.basicConfig(level=logging.WARNING)

PROJECT_DIR = Path(__file__).parent
sys.path.insert(0, str(PROJECT_DIR))


def get_vision():
    """Initialize and return NovaVision instance."""
    from main import NovaVision, load_config
    config = load_config(str(PROJECT_DIR / "config.yaml"))
    vision = NovaVision(config)
    if not vision.initialize():
        print(json.dumps({"error": "Failed to initialize vision system"}))
        sys.exit(1)
    return vision


def warm_up(vision, frames=5):
    """Run a few perception cycles to warm up."""
    for _ in range(frames):
        vision.perceive()
        time.sleep(0.03)


def cmd_look():
    """Describe what Nova sees."""
    vision = get_vision()
    warm_up(vision)
    perception = vision.perceive()
    description = vision.describe()
    vision.shutdown()
    print(json.dumps({
        "description": description,
        "perception": perception,
    }, indent=2))


def cmd_find(target: str):
    """Search for a specific object."""
    vision = get_vision()
    warm_up(vision, frames=10)

    found = []
    for _ in range(15):  # Search across multiple frames
        perception = vision.perceive()
        if perception and perception.get("detections"):
            for det in perception["detections"]:
                if target.lower() in det["label"].lower():
                    found.append(det)

    vision.shutdown()

    if found:
        # Deduplicate by taking the highest confidence
        best = max(found, key=lambda d: d.get("confidence", 0))
        dist = best.get("distance_m")
        pos = best.get("position")
        msg = f"Found {best['label']} with {best['confidence']:.0%} confidence"
        if dist:
            msg += f" at {dist:.1f}m"
        if pos:
            msg += f" (X:{pos['x_mm']}mm, Y:{pos['y_mm']}mm, Z:{pos['z_mm']}mm)"
        print(json.dumps({"found": True, "message": msg, "detection": best}, indent=2))
    else:
        print(json.dumps({"found": False, "message": f"I don't see any '{target}' right now."}))


def cmd_snapshot():
    """Take a photo."""
    vision = get_vision()
    warm_up(vision)
    path = vision.snapshot()
    vision.shutdown()
    if path:
        print(json.dumps({"success": True, "path": path, "message": f"Photo saved to {path}"}))
    else:
        print(json.dumps({"success": False, "message": "Failed to capture photo"}))


def cmd_spatial():
    """Get spatial awareness data."""
    vision = get_vision()
    warm_up(vision)
    perception = vision.perceive()
    vision.shutdown()

    if perception:
        spatial_info = {
            "nearest_distance_m": perception.get("nearest_distance", 0),
            "safe_to_move": perception.get("safe_to_move", False),
            "best_direction": perception.get("best_direction", "unknown"),
            "intimate_space_alert": perception.get("intimate_space_alert", False),
            "persons_count": perception.get("persons_count", 0),
        }
        print(json.dumps(spatial_info, indent=2))
    else:
        print(json.dumps({"error": "No spatial data available"}))


def cmd_who():
    """Identify people in view."""
    vision = get_vision()
    warm_up(vision)
    perception = vision.perceive()
    vision.shutdown()

    if perception:
        persons = perception.get("persons_count", 0)
        faces = perception.get("faces_count", 0)
        recognized = perception.get("recognized_faces", [])

        if persons == 0:
            msg = "I don't see anyone."
        elif recognized:
            msg = f"I see {persons} person(s). Recognized: {', '.join(recognized)}."
        else:
            nearest = perception.get("nearest_person_distance", 0)
            msg = f"I see {persons} person(s)"
            if nearest > 0:
                msg += f", nearest at {nearest:.1f}m"
            msg += "."

        print(json.dumps({"persons": persons, "faces": faces,
                          "recognized": recognized, "message": msg}, indent=2))
    else:
        print(json.dumps({"error": "No data available"}))


def cmd_status():
    """Get vision system status."""
    vision = get_vision()
    status = vision.get_status()
    vision.shutdown()
    print(json.dumps(status, indent=2))


COMMANDS = {
    "look": cmd_look,
    "find": lambda: cmd_find(sys.argv[2] if len(sys.argv) > 2 else "person"),
    "snapshot": cmd_snapshot,
    "spatial": cmd_spatial,
    "who": cmd_who,
    "status": cmd_status,
}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        print(f"Usage: {sys.argv[0]} <{'|'.join(COMMANDS.keys())}> [args]")
        print("\nCommands:")
        print("  look      - Describe what Nova sees")
        print("  find <obj> - Search for a specific object")
        print("  snapshot  - Take a photo")
        print("  spatial   - Get spatial awareness data")
        print("  who       - Identify people")
        print("  status    - Vision system status")
        sys.exit(1)

    COMMANDS[sys.argv[1]]()
