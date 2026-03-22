#!/usr/bin/env python3
"""Instinct Extractor for OpenClaw Brain.

Reads session data and extracts "When X, do Y" patterns (instincts).
Posts each instinct to Memos API with #instinct tag.

Usage:
    echo '{"sessions": [...]}' | ./instinct-extractor.py
    ./instinct-extractor.py --file session-data.json
    ./instinct-extractor.py --from-evals
    ./instinct-extractor.py --help
"""

import argparse
import json
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone

MEMOS_API = "http://nova-rig:5230"

DOMAIN_KEYWORDS = {
    "memory": ["memory", "retrieval", "search", "ragflow", "obsidian", "recall", "context"],
    "delegation": ["delegate", "sub-agent", "acpx", "claude", "codex", "route"],
    "tool": ["tool", "grep", "edit", "read", "bash", "script", "command"],
    "research": ["research", "notebooklm", "tavily", "search", "discover", "paper"],
    "quality": ["quality", "test", "review", "refactor", "clean", "score", "rubric"],
}


def parse_args():
    parser = argparse.ArgumentParser(
        description="Extract instincts from session data and post to Memos."
    )
    parser.add_argument("--file", help="Path to session data JSON file")
    parser.add_argument("--from-evals", action="store_true",
                        help="Extract instincts from recent #self-eval memos (score >= 8)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print instincts without posting to Memos")
    return parser.parse_args()


def classify_domain(text):
    """Classify an instinct into a domain based on keyword matching."""
    text_lower = text.lower()
    scores = {}
    for domain, keywords in DOMAIN_KEYWORDS.items():
        scores[domain] = sum(1 for kw in keywords if kw in text_lower)
    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else "general"


def extract_from_session(session):
    """Extract instincts from a single session record."""
    instincts = []
    score = session.get("quality_score", session.get("score", 0))
    if score < 7:
        return instincts

    task_type = session.get("task_type", "unknown")
    description = session.get("description", "unnamed task")
    tools = session.get("tools_used", [])
    suggestion = session.get("suggestion", "")
    bottleneck = session.get("bottleneck", "none")
    session_id = session.get("id", "unknown")

    # Pattern 1: successful tool sequence
    if tools and score >= 8:
        tool_str = " -> ".join(tools) if isinstance(tools, list) else str(tools)
        instincts.append({
            "trigger": f"When doing {task_type} tasks",
            "action": f"Use tool sequence: {tool_str}",
            "evidence": f"Worked in session {session_id}, task '{description}', score {score}",
            "confidence": min(1.0, score / 10.0),
            "domain": classify_domain(f"{task_type} {tool_str}"),
        })

    # Pattern 2: suggestion that fixed a bottleneck
    if suggestion and bottleneck != "none":
        instincts.append({
            "trigger": f"When encountering {bottleneck}",
            "action": suggestion,
            "evidence": f"Identified in session {session_id}, task '{description}', score {score}",
            "confidence": min(1.0, (score - 4) / 6.0),
            "domain": classify_domain(f"{bottleneck} {suggestion}"),
        })

    # Pattern 3: high-score task approach
    if score >= 9:
        instincts.append({
            "trigger": f"When starting a {task_type} task similar to '{description}'",
            "action": f"Follow the approach that scored {score}/10",
            "evidence": f"Breakthrough in session {session_id}, score {score}",
            "confidence": 0.9,
            "domain": classify_domain(f"{task_type} {description}"),
        })

    return instincts


def fetch_recent_evals(min_score=8):
    """Fetch recent high-scoring self-eval memos from Memos API."""
    url = f"{MEMOS_API}/api/v1/memos?filter=tag%3D%3D%27self-eval%27&pageSize=20"
    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except (urllib.error.HTTPError, urllib.error.URLError) as e:
        print(f"ERROR: Cannot reach Memos API: {e}", file=sys.stderr)
        return []

    sessions = []
    for memo in data.get("memos", []):
        content = memo.get("content", "")
        # Extract score from memo content
        score = None
        for line in content.split("\n"):
            if "**Score:**" in line:
                try:
                    score = int(line.split("**Score:**")[1].strip().split("/")[0])
                except (ValueError, IndexError):
                    pass
        if score is not None and score >= min_score:
            # Build a session-like dict from memo content
            task_type = "unknown"
            description = ""
            for line in content.split("\n"):
                if "**Type:**" in line:
                    try:
                        task_type = line.split("**Type:**")[1].strip().split(" ")[0].strip("|").strip()
                    except IndexError:
                        pass
                if line.startswith("## Self-Evaluation:"):
                    description = line.replace("## Self-Evaluation:", "").strip()
            sessions.append({
                "quality_score": score,
                "task_type": task_type,
                "description": description,
                "id": memo.get("name", "unknown"),
            })
    return sessions


def post_instinct(instinct, dry_run=False):
    """Post a single instinct to Memos API."""
    domain = instinct.get("domain", "general")
    content = f"#instinct #{domain} #openclaw\n"
    content += f"## Instinct: {instinct['trigger']}\n\n"
    content += f"**Trigger:** {instinct['trigger']}\n"
    content += f"**Action:** {instinct['action']}\n"
    content += f"**Evidence:** {instinct['evidence']}\n"
    content += f"**Confidence:** {instinct['confidence']:.2f}\n"
    content += f"**Domain:** {domain}\n"

    if dry_run:
        print(f"  [DRY RUN] Would post: {instinct['trigger']} -> {instinct['action']}")
        return True

    payload = json.dumps({"content": content, "visibility": "PRIVATE"}).encode("utf-8")
    req = urllib.request.Request(
        f"{MEMOS_API}/api/v1/memos",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read().decode("utf-8"))
            print(f"  Posted: {result.get('name', 'ok')} [{domain}]")
            return True
    except (urllib.error.HTTPError, urllib.error.URLError) as e:
        print(f"  ERROR posting instinct: {e}", file=sys.stderr)
        return False


def main():
    args = parse_args()
    sessions = []

    if args.from_evals:
        print("Fetching high-scoring self-eval memos...")
        sessions = fetch_recent_evals(min_score=8)
        if not sessions:
            print("No high-scoring evals found.")
            return
        print(f"Found {len(sessions)} high-scoring sessions.")
    elif args.file:
        with open(args.file, "r") as f:
            data = json.load(f)
        sessions = data if isinstance(data, list) else data.get("sessions", [data])
    else:
        raw = sys.stdin.read().strip()
        if not raw:
            print("ERROR: No input. Use --file, --from-evals, or pipe JSON to stdin.", file=sys.stderr)
            sys.exit(1)
        data = json.loads(raw)
        sessions = data if isinstance(data, list) else data.get("sessions", [data])

    all_instincts = []
    for session in sessions:
        all_instincts.extend(extract_from_session(session))

    if not all_instincts:
        print("No instincts extracted (sessions may have low scores).")
        return

    print(f"\nExtracted {len(all_instincts)} instinct(s):")
    posted = 0
    for instinct in all_instincts:
        if post_instinct(instinct, dry_run=args.dry_run):
            posted += 1

    # Summary by domain
    domains = {}
    for inst in all_instincts:
        d = inst.get("domain", "general")
        domains[d] = domains.get(d, 0) + 1

    print(f"\n=== Summary ===")
    print(f"Total instincts: {len(all_instincts)}")
    print(f"Posted to Memos: {posted}")
    print(f"By domain:")
    for domain, count in sorted(domains.items()):
        print(f"  {domain}: {count}")


if __name__ == "__main__":
    main()
