#!/usr/bin/env python3
"""
Self-Eval — Behavior MCP Server
Evaluates task completion quality using heuristic scoring.
Produces a quality score, identifies bottlenecks, and suggests improvements.

HTTP JSON API on configurable port (default 9502).
Stdlib only — no external dependencies.

Usage:
    python3 server.py [--port 9502] [--help]
"""

import json
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler

DEFAULT_PORT = 9502

# Time thresholds in seconds for different task sizes
TIME_THRESHOLDS = {
    "tiny": 60,       # < 1 min expected
    "small": 300,     # < 5 min expected
    "medium": 1800,   # < 30 min expected
    "large": 7200,    # < 2 hours expected
}

BOTTLENECK_PATTERNS = {
    "slow_tool_selection": ["tried multiple tools", "wrong tool first", "tool error"],
    "poor_context": ["missing context", "had to re-read", "lost context", "context window"],
    "unclear_goal": ["ambiguous", "unclear", "had to clarify", "misunderstood"],
    "dependency_wait": ["waiting for", "blocked by", "dependency", "rate limited"],
    "complexity_underestimate": ["took longer", "more complex", "unexpected", "scope creep"],
    "memory_miss": ["forgot", "already knew", "rediscovered", "duplicate work"],
}


def evaluate_task(task_result, original_goal, time_taken_seconds, tool_count=0,
                  files_changed=0, errors_encountered=0):
    """Score task completion quality on a 1-10 scale."""
    score = 10.0  # Start perfect, deduct for issues
    bottleneck = "none"
    suggestions = []

    # --- Completion check ---
    result_lower = task_result.lower() if task_result else ""
    goal_lower = original_goal.lower() if original_goal else ""

    # Check for failure signals
    failure_signals = ["failed", "error", "could not", "unable to", "broken", "crash"]
    failure_count = sum(1 for sig in failure_signals if sig in result_lower)
    if failure_count > 0:
        score -= min(failure_count * 1.5, 4.0)
        suggestions.append("Task had failure signals — review error handling")

    # Check for partial completion
    partial_signals = ["partial", "incomplete", "skipped", "todo", "later", "workaround"]
    partial_count = sum(1 for sig in partial_signals if sig in result_lower)
    if partial_count > 0:
        score -= min(partial_count * 1.0, 3.0)
        suggestions.append("Task appears partially complete — consider follow-up")

    # --- Time analysis ---
    time_taken = float(time_taken_seconds) if time_taken_seconds else 0

    # Estimate expected time from goal complexity (word count heuristic)
    goal_words = len(goal_lower.split())
    if goal_words < 10:
        expected_category = "tiny"
    elif goal_words < 30:
        expected_category = "small"
    elif goal_words < 80:
        expected_category = "medium"
    else:
        expected_category = "large"

    expected_time = TIME_THRESHOLDS[expected_category]

    if time_taken > 0 and expected_time > 0:
        time_ratio = time_taken / expected_time
        if time_ratio > 3.0:
            score -= 2.0
            bottleneck = "time_overrun"
            suggestions.append(
                f"Task took {time_ratio:.1f}x longer than expected for a {expected_category} task"
            )
        elif time_ratio > 2.0:
            score -= 1.0
            if bottleneck == "none":
                bottleneck = "time_overrun"
        elif time_ratio < 0.3:
            # Suspiciously fast — might be incomplete
            suggestions.append("Completed very quickly — verify completeness")

    # --- Tool efficiency ---
    tools = int(tool_count) if tool_count else 0
    if tools > 20:
        score -= 1.5
        if bottleneck == "none":
            bottleneck = "tool_thrashing"
        suggestions.append(f"Used {tools} tool calls — consider more targeted approaches")
    elif tools > 10:
        score -= 0.5

    # --- Error analysis ---
    errors = int(errors_encountered) if errors_encountered else 0
    if errors > 5:
        score -= 2.0
        if bottleneck == "none":
            bottleneck = "high_error_rate"
        suggestions.append(f"Encountered {errors} errors — improve pre-validation")
    elif errors > 2:
        score -= 1.0

    # --- Files changed analysis ---
    files = int(files_changed) if files_changed else 0
    if files > 20:
        suggestions.append(f"Changed {files} files — consider breaking into smaller tasks")

    # --- Bottleneck detection from result text ---
    if bottleneck == "none":
        for bn_name, patterns in BOTTLENECK_PATTERNS.items():
            if any(pat in result_lower for pat in patterns):
                bottleneck = bn_name
                break

    # Clamp score
    score = max(1.0, min(10.0, round(score, 1)))

    # Default suggestion if none generated
    if not suggestions:
        if score >= 8:
            suggestions.append("Good execution — log this pattern for reuse")
        else:
            suggestions.append("Review execution flow for optimization opportunities")

    return {
        "quality_score": score,
        "bottleneck": bottleneck,
        "suggestion": suggestions[0],
        "all_suggestions": suggestions,
        "expected_category": expected_category,
    }


class SelfEvalHandler(BaseHTTPRequestHandler):
    """HTTP handler for self-evaluation requests."""

    def do_POST(self):
        if self.path != "/evaluate":
            self.send_error(404, "Use POST /evaluate")
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length)) if length > 0 else {}
            result = evaluate_task(
                task_result=body.get("task_result", ""),
                original_goal=body.get("original_goal", ""),
                time_taken_seconds=body.get("time_taken_seconds", 0),
                tool_count=body.get("tool_count", 0),
                files_changed=body.get("files_changed", 0),
                errors_encountered=body.get("errors_encountered", 0),
            )
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
            self.wfile.write(json.dumps({"status": "ok", "service": "self-eval"}).encode())
        else:
            self.send_error(404, "Use POST /evaluate or GET /health")

    def log_message(self, fmt, *args):
        pass


def main():
    if "--help" in sys.argv or "-h" in sys.argv:
        print("Self-Eval — Behavior MCP Server")
        print("Evaluates task completion quality with heuristic scoring")
        print("")
        print("Usage: python3 server.py [--port PORT]")
        print(f"  --port PORT  Listen port (default: {DEFAULT_PORT})")
        print("  --help       Show this help")
        print("")
        print("Endpoints:")
        print("  POST /evaluate  Evaluate a completed task")
        print("                  (JSON body: task_result, original_goal,")
        print("                   time_taken_seconds, tool_count, files_changed,")
        print("                   errors_encountered)")
        print("  GET  /health    Health check")
        print("")
        print("Output: quality_score (1-10), bottleneck, suggestion")
        sys.exit(0)

    port = DEFAULT_PORT
    if "--port" in sys.argv:
        idx = sys.argv.index("--port")
        if idx + 1 < len(sys.argv):
            port = int(sys.argv[idx + 1])

    server = HTTPServer(("0.0.0.0", port), SelfEvalHandler)
    print(f"Self-Eval listening on port {port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()


if __name__ == "__main__":
    main()
