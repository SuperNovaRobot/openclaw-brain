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
import re
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


# ── 9-Dimension Quality Scoring ──────────────────────────────────────────────

# Keyword lists for each dimension
_PERSONAL_WORDS = {"i", "my", "me", "prefer", "like", "feel", "want", "need"}
_RELATIONSHIP_WORDS = {"friend", "partner", "team", "colleague", "mentor", "creator", "user"}
_IDENTITY_WORDS = {"eve", "agent", "brain", "memory", "self", "identity", "mission", "soul"}
_DURABLE_WORDS = {"always", "never", "birthday", "rule", "principle", "goal", "forever"}
_NOISE_WORDS = {"cron", "pipeline", "api key", "script", "curl", "systemctl",
                "docker", "config", "port", "localhost"}
_HEDGE_WORDS = {"maybe", "might", "possibly", "uncertain"}

# Retrieval utility tag scores
_TAG_SCORES = {
    "#decision": 0.95,
    "#completed": 0.85,
    "#error": 0.80,
    "#research": 0.90,
}

# Dimension weights
_WEIGHTS = {
    "personal_relevance": 0.19,
    "relationship_signal": 0.15,
    "agent_identity": 0.18,
    "durable_signal": 0.12,
    "retrieval_utility": 0.20,
    "recency_temporal": 0.08,
    "specificity": 0.08,
    "operational_noise": -0.15,
}


def _keyword_ratio(words, keyword_set):
    """Return fraction of words in content that match the keyword set (0-1)."""
    if not words:
        return 0.0
    hits = sum(1 for w in words if w in keyword_set)
    return min(hits / max(len(words), 1), 1.0)


def score_memo_quality(content):
    """Score memo content across 9 dimensions. Returns dict with score, tier, dimensions, confidence."""
    if not content or not content.strip():
        return {
            "score": 0.0,
            "tier": "reject",
            "dimensions": {k: 0.0 for k in _WEIGHTS},
            "confidence": 0.0,
        }

    text_lower = content.lower()
    # Tokenize: split on non-alpha and flatten
    words = re.findall(r"[a-z]+", text_lower)

    # ── Dimension scores ──

    # 1. Personal relevance — keyword hit ratio, scaled up for visibility
    personal_relevance = min(_keyword_ratio(words, _PERSONAL_WORDS) * 5.0, 1.0)

    # 2. Relationship signal
    relationship_signal = min(_keyword_ratio(words, _RELATIONSHIP_WORDS) * 8.0, 1.0)

    # 3. Agent identity
    agent_identity = min(_keyword_ratio(words, _IDENTITY_WORDS) * 5.0, 1.0)

    # 4. Durable signal
    durable_signal = min(_keyword_ratio(words, _DURABLE_WORDS) * 8.0, 1.0)

    # 5. Retrieval utility — tag-based
    retrieval_utility = 0.5  # default
    for tag, tag_score in _TAG_SCORES.items():
        if tag in text_lower:
            retrieval_utility = max(retrieval_utility, tag_score)

    # 6. Recency temporal — always 1.0 at capture time
    recency_temporal = 1.0

    # 7. Specificity — ratio of distinct words >= 4 chars to total words
    if words:
        long_words = {w for w in words if len(w) >= 4}
        specificity = len(long_words) / len(words)
    else:
        specificity = 0.0

    # 8. Operational noise — check for noise phrases/words
    noise_hits = sum(1 for nw in _NOISE_WORDS if nw in text_lower)
    operational_noise = min(noise_hits / max(len(_NOISE_WORDS), 1), 1.0)

    # 9. Confidence — default 0.7, drop to 0.4 if hedging
    confidence = 0.7
    if any(hw in words for hw in _HEDGE_WORDS):
        confidence = 0.4

    dimensions = {
        "personal_relevance": round(personal_relevance, 4),
        "relationship_signal": round(relationship_signal, 4),
        "agent_identity": round(agent_identity, 4),
        "durable_signal": round(durable_signal, 4),
        "retrieval_utility": round(retrieval_utility, 4),
        "recency_temporal": round(recency_temporal, 4),
        "specificity": round(specificity, 4),
        "operational_noise": round(operational_noise, 4),
    }

    # Composite = weighted sum * confidence
    raw = sum(dimensions[dim] * weight for dim, weight in _WEIGHTS.items())
    score = max(0.0, min(1.0, round(raw * confidence, 4)))

    # Tier assignment
    if score >= 0.78:
        tier = "keep"
    elif score >= 0.18:
        tier = "archive"
    else:
        tier = "reject"

    return {
        "score": score,
        "tier": tier,
        "dimensions": dimensions,
        "confidence": confidence,
    }


class SelfEvalHandler(BaseHTTPRequestHandler):
    """HTTP handler for self-evaluation requests."""

    def _read_json_body(self):
        """Read and parse JSON request body."""
        length = int(self.headers.get("Content-Length", 0))
        return json.loads(self.rfile.read(length)) if length > 0 else {}

    def _send_json(self, code, data):
        """Send a JSON response."""
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data, indent=2).encode())

    def do_POST(self):
        if self.path == "/evaluate":
            self._handle_evaluate()
        elif self.path == "/quality_score":
            self._handle_quality_score()
        else:
            self.send_error(404, "Use POST /evaluate or POST /quality_score")

    def _handle_evaluate(self):
        try:
            body = self._read_json_body()
            result = evaluate_task(
                task_result=body.get("task_result", ""),
                original_goal=body.get("original_goal", ""),
                time_taken_seconds=body.get("time_taken_seconds", 0),
                tool_count=body.get("tool_count", 0),
                files_changed=body.get("files_changed", 0),
                errors_encountered=body.get("errors_encountered", 0),
            )
            self._send_json(200, result)
        except Exception as exc:
            self._send_json(400, {"error": str(exc)})

    def _handle_quality_score(self):
        try:
            body = self._read_json_body()
            content = body.get("content", "")
            if not content:
                self._send_json(400, {"error": "Missing 'content' field"})
                return
            result = score_memo_quality(content)
            self._send_json(200, result)
        except Exception as exc:
            self._send_json(400, {"error": str(exc)})

    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "service": "self-eval"}).encode())
        else:
            self.send_error(404, "Use POST /evaluate, POST /quality_score, or GET /health")

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
        print("  POST /evaluate       Evaluate a completed task")
        print("                       (JSON body: task_result, original_goal,")
        print("                        time_taken_seconds, tool_count, files_changed,")
        print("                        errors_encountered)")
        print("  POST /quality_score  Score memo quality (9 dimensions)")
        print("                       (JSON body: content)")
        print("  GET  /health         Health check")
        print("")
        print("Output /evaluate:      quality_score (1-10), bottleneck, suggestion")
        print("Output /quality_score: score (0-1), tier, dimensions, confidence")
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
