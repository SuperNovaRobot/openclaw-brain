#!/usr/bin/env python3
"""
Memory Decision — Behavior MCP Server
Decides which memory layers should store new information.
Uses rules from memory-routing.SKILL.md.

Memory layers:
  1 = Context (ephemeral, current session)
  2 = Memos (tagged quick notes)
  3 = Obsidian (linked knowledge graph)
  4 = RagFlow (vector search, large docs)
  5 = NotebookLM (Gemini research, read-only unless 10/10)

HTTP JSON API on configurable port (default 9501).
Stdlib only — no external dependencies.

Usage:
    python3 server.py [--port 9501] [--help]
"""

import json
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler

DEFAULT_PORT = 9501

# Keyword-to-layer routing rules from memory-routing.SKILL.md
LAYER_RULES = {
    2: {  # Memos
        "keywords": [
            "todo", "decision", "self-eval", "mission", "revenue",
            "hardware", "quick", "action", "reminder", "note",
            "budget", "cost", "plan", "blocker", "status"
        ],
        "tag_map": {
            "todo": "#todo",
            "decision": "#decision",
            "self-eval": "#self-eval",
            "mission": "#mission",
            "revenue": "#revenue",
            "hardware": "#hardware-need",
            "budget": "#revenue",
            "cost": "#revenue",
            "plan": "#todo",
            "blocker": "#todo",
            "status": "#decision",
        },
    },
    3: {  # Obsidian
        "keywords": [
            "concept", "knowledge", "link", "reference", "pattern",
            "architecture", "design", "tool", "research", "finding",
            "daily", "log", "documentation", "crawl", "wiki",
            "connection", "relationship", "graph"
        ],
    },
    4: {  # RagFlow
        "keywords": [
            "code", "pattern", "document", "large", "paper",
            "dataset", "index", "vector", "search", "corpus",
            "crawl", "documentation", "api"
        ],
    },
    5: {  # NotebookLM
        "keywords": [
            "research", "paper", "breakthrough", "cutting-edge",
            "gemini", "analysis", "cross-source", "discovery",
            "novel", "state-of-the-art", "important"
        ],
    },
}

URGENCY_KEYWORDS = {
    "high": ["urgent", "critical", "blocker", "asap", "immediately", "breaking", "crash"],
    "medium": ["important", "soon", "should", "need", "required"],
    "low": ["maybe", "someday", "nice-to-have", "optional", "later", "consider"],
}


def decide_memory(information, context=""):
    """Decide which memory layers to store information in."""
    text = (information + " " + context).lower()

    layers = []
    suggested_tags = []
    suggested_links = []

    # Check each layer
    for layer_num, rules in LAYER_RULES.items():
        score = 0
        for kw in rules["keywords"]:
            if kw in text:
                score += 1
                # Collect tags for memos layer
                if layer_num == 2 and "tag_map" in rules and kw in rules["tag_map"]:
                    tag = rules["tag_map"][kw]
                    if tag not in suggested_tags:
                        suggested_tags.append(tag)
        if score > 0:
            layers.append(layer_num)

    # Always include layer 1 (context) — current session always gets it
    if 1 not in layers:
        layers.insert(0, 1)

    # Generate wiki-links for Obsidian if layer 3 is selected
    if 3 in layers:
        # Extract potential link targets from notable words
        words = text.split()
        link_candidates = [
            "self-improvement", "autoresearch", "memory-stack", "ragflow",
            "obsidian", "notebooklm", "langchain", "openclaw", "nemotron",
            "crawl4ai", "acpx", "clawteam", "langclaw", "surfsense",
            "memos", "task-routing", "delegation"
        ]
        for candidate in link_candidates:
            if candidate in text:
                suggested_links.append("[[" + candidate + "]]")

    # Determine urgency
    urgency = "medium"
    for level, keywords in URGENCY_KEYWORDS.items():
        for kw in keywords:
            if kw in text:
                urgency = level
                break
        if urgency != "medium":
            break

    # Default if no layers matched beyond context
    if len(layers) == 1 and layers[0] == 1:
        layers.append(2)  # Default to memos
        suggested_tags.append("#note")

    return {
        "layers": sorted(layers),
        "urgency": urgency,
        "suggested_tags": suggested_tags if suggested_tags else ["#note"],
        "suggested_wiki_links": suggested_links,
    }


class MemoryDecisionHandler(BaseHTTPRequestHandler):
    """HTTP handler for memory routing decisions."""

    def do_POST(self):
        if self.path != "/decide":
            self.send_error(404, "Use POST /decide")
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length)) if length > 0 else {}
            information = body.get("information", "")
            context = body.get("context", "")
            result = decide_memory(information, context)
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
            self.wfile.write(json.dumps({"status": "ok", "service": "memory-decision"}).encode())
        else:
            self.send_error(404, "Use POST /decide or GET /health")

    def log_message(self, fmt, *args):
        pass


def main():
    if "--help" in sys.argv or "-h" in sys.argv:
        print("Memory Decision — Behavior MCP Server")
        print("Decides which memory layers should store new information")
        print("")
        print("Usage: python3 server.py [--port PORT]")
        print(f"  --port PORT  Listen port (default: {DEFAULT_PORT})")
        print("  --help       Show this help")
        print("")
        print("Endpoints:")
        print("  POST /decide  Route information to memory layers")
        print("                (JSON body: information, context)")
        print("  GET  /health  Health check")
        print("")
        print("Memory Layers:")
        print("  1 = Context (session), 2 = Memos, 3 = Obsidian,")
        print("  4 = RagFlow, 5 = NotebookLM")
        sys.exit(0)

    port = DEFAULT_PORT
    if "--port" in sys.argv:
        idx = sys.argv.index("--port")
        if idx + 1 < len(sys.argv):
            port = int(sys.argv[idx + 1])

    server = HTTPServer(("0.0.0.0", port), MemoryDecisionHandler)
    print(f"Memory Decision listening on port {port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()


if __name__ == "__main__":
    main()
