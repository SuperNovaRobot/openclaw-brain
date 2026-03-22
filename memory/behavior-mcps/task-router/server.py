#!/usr/bin/env python3
"""
Task Router — Behavior MCP Server
Routes tasks to the appropriate handler based on keyword matching and size thresholds.
Uses rules from when-to-delegate.SKILL.md.

HTTP JSON API on configurable port (default 9500).
Stdlib only — no external dependencies.

Usage:
    python3 server.py [--port 9500] [--help]
"""

import json
import sys
import os
from http.server import HTTPServer, BaseHTTPRequestHandler

DEFAULT_PORT = 9500

# Keywords and thresholds derived from when-to-delegate.SKILL.md
SELF_KEYWORDS = [
    "config", "edit", "fix", "tweak", "lookup", "check", "status",
    "memory", "memo", "tag", "quick", "simple", "small", "single-file",
    "read", "list", "search", "query", "log"
]
CLAUDE_KEYWORDS = [
    "refactor", "implement", "feature", "multi-file", "complex",
    "architecture", "redesign", "migrate", "test suite", "integration",
    "build", "deploy", "pipeline", "heavy"
]
CODEX_KEYWORDS = [
    "codex", "openai", "alternative", "backup", "parallel"
]
SWARM_KEYWORDS = [
    "parallel", "batch", "multiple", "simultaneous", "concurrent",
    "independent", "swarm", "team", "spawn"
]
BMAD_KEYWORDS = [
    "architecture", "system design", "multi-component", "bmad",
    "analyst", "spec", "blueprint"
]

SIZE_TINY = 100
SIZE_SMALL = 500


def route_task(description, estimated_lines, context=""):
    """Decide handler based on description keywords and estimated size."""
    text = (description + " " + context).lower()

    # Score each handler
    scores = {
        "self": 0,
        "claude": 0,
        "codex": 0,
        "swarm": 0,
    }

    for kw in SELF_KEYWORDS:
        if kw in text:
            scores["self"] += 1
    for kw in CLAUDE_KEYWORDS:
        if kw in text:
            scores["claude"] += 1
    for kw in CODEX_KEYWORDS:
        if kw in text:
            scores["codex"] += 1
    for kw in SWARM_KEYWORDS:
        if kw in text:
            scores["swarm"] += 1

    # Check for BMAD pipeline trigger
    bmad_score = sum(1 for kw in BMAD_KEYWORDS if kw in text)
    if bmad_score >= 2:
        return {
            "handler": "bmad_pipeline",
            "reason": "Multiple architecture/design keywords detected — use BMAD analyst->PM->architect->dev pipeline",
            "confidence": min(0.5 + bmad_score * 0.15, 0.95),
        }

    # Size-based override
    lines = int(estimated_lines) if estimated_lines else 0
    if lines > 0:
        if lines < SIZE_TINY:
            scores["self"] += 3
        elif lines < SIZE_SMALL:
            scores["self"] += 1
            scores["claude"] += 1
        else:
            scores["claude"] += 3

    # Pick the winner
    best = max(scores, key=scores.get)
    best_score = scores[best]
    total = sum(scores.values()) or 1

    # If no keywords matched and no size info, default to self with low confidence
    if best_score == 0:
        return {
            "handler": "self",
            "reason": "No strong routing signals — defaulting to self-handling",
            "confidence": 0.3,
        }

    confidence = round(min(best_score / total + 0.3, 0.95), 2)

    reasons = {
        "self": "Task is small or matches self-handling keywords (config, edit, lookup, etc.)",
        "claude": "Task is large or complex — delegate to Claude Code via acpx",
        "codex": "Task matches Codex delegation pattern — use as Claude alternative",
        "swarm": "Multiple independent subtasks detected — spawn parallel agents via ClawTeam",
    }

    return {
        "handler": best,
        "reason": reasons[best],
        "confidence": confidence,
    }


class TaskRouterHandler(BaseHTTPRequestHandler):
    """HTTP handler for task routing requests."""

    def do_POST(self):
        if self.path != "/route":
            self.send_error(404, "Use POST /route")
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length)) if length > 0 else {}
            description = body.get("description", "")
            estimated_lines = body.get("estimated_lines", 0)
            context = body.get("context", "")
            result = route_task(description, estimated_lines, context)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode())
        except Exception as exc:
            self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(exc)}).encode())

    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "service": "task-router"}).encode())
        else:
            self.send_error(404, "Use POST /route or GET /health")

    def log_message(self, fmt, *args):
        """Suppress default stderr logging."""
        pass


def main():
    if "--help" in sys.argv or "-h" in sys.argv:
        print("Task Router — Behavior MCP Server")
        print("Routes tasks to appropriate handler (self/claude/codex/swarm)")
        print("")
        print("Usage: python3 server.py [--port PORT]")
        print(f"  --port PORT  Listen port (default: {DEFAULT_PORT})")
        print("  --help       Show this help")
        print("")
        print("Endpoints:")
        print("  POST /route   Route a task (JSON body: description, estimated_lines, context)")
        print("  GET  /health  Health check")
        sys.exit(0)

    port = DEFAULT_PORT
    if "--port" in sys.argv:
        idx = sys.argv.index("--port")
        if idx + 1 < len(sys.argv):
            port = int(sys.argv[idx + 1])

    server = HTTPServer(("0.0.0.0", port), TaskRouterHandler)
    print(f"Task Router listening on port {port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()


if __name__ == "__main__":
    main()
