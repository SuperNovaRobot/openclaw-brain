#!/usr/bin/env python3
"""Self-Evaluation Logger for OpenClaw Brain.

Posts structured self-evaluation memos to Memos API and checks
thresholds against recent evaluations. Uses only Python stdlib.

Usage:
    ./self-eval-logger.py --task-type coding --description "Built feature X" \
        --score 8 --time 300 --tokens 5000 --tools "grep,read,edit" \
        --delegated none --bottleneck none --suggestion "Use cached results next time"
"""

import argparse
import json
import sys
import urllib.request
import urllib.error
import urllib.parse
from datetime import datetime, timezone

MEMOS_API = "http://nova-rig:5230"
MEMOS_TAG = "#self-eval"
EXPERIMENT_TAG = "#experiment"

VALID_TASK_TYPES = ["coding", "research", "delegation", "memory", "discovery", "planning", "debugging"]
VALID_BOTTLENECKS = [
    "tool_gap", "memory_retrieval", "prompt_quality", "delegation_failure",
    "context_overflow", "api_failure", "skill_gap", "none"
]


def parse_args():
    parser = argparse.ArgumentParser(
        description="Log a self-evaluation to Memos and check thresholds."
    )
    parser.add_argument("--task-type", required=True, choices=VALID_TASK_TYPES,
                        help="Type of task completed")
    parser.add_argument("--description", required=True,
                        help="Brief description of what was done")
    parser.add_argument("--score", required=True, type=int, choices=range(1, 11),
                        metavar="1-10", help="Quality score 1-10")
    parser.add_argument("--time", required=True, type=int,
                        help="Time taken in seconds")
    parser.add_argument("--tokens", type=int, default=0,
                        help="Tokens consumed (default: 0)")
    parser.add_argument("--tools", default="",
                        help="Comma-separated list of tools used")
    parser.add_argument("--delegated", default="none",
                        help="Sub-agent delegated to (default: none)")
    parser.add_argument("--bottleneck", required=True, choices=VALID_BOTTLENECKS,
                        help="Primary bottleneck encountered")
    parser.add_argument("--suggestion", required=True,
                        help="Actionable improvement suggestion")
    return parser.parse_args()


def build_memo_content(args):
    """Build structured memo content with tags and JSON payload."""
    tools_list = [t.strip() for t in args.tools.split(",") if t.strip()]
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    eval_data = {
        "task_type": args.task_type,
        "description": args.description,
        "quality_score": args.score,
        "time_seconds": args.time,
        "tokens_used": args.tokens,
        "tools_used": tools_list,
        "delegated_to": args.delegated,
        "bottleneck": args.bottleneck,
        "suggestion": args.suggestion,
        "timestamp": timestamp,
    }

    content = f"{MEMOS_TAG} #openclaw\n"
    content += f"## Self-Evaluation: {args.description}\n\n"
    content += f"**Score:** {args.score}/10 | **Type:** {args.task_type} | **Time:** {args.time}s\n"
    content += f"**Bottleneck:** {args.bottleneck} | **Delegated:** {args.delegated}\n"
    if tools_list:
        content += f"**Tools:** {', '.join(tools_list)}\n"
    if args.tokens:
        content += f"**Tokens:** {args.tokens}\n"
    content += f"\n**Suggestion:** {args.suggestion}\n\n"
    content += f""

    return content


def post_memo(content):
    """Post a memo to the Memos API."""
    url = f"{MEMOS_API}/api/v1/memos"
    payload = json.dumps({
        "content": content,
        "visibility": "PRIVATE"
    }).encode("utf-8")

    req = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read().decode("utf-8"))
            return result
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"ERROR: Memos API returned {e.code}: {body}", file=sys.stderr)
        return None
    except urllib.error.URLError as e:
        print(f"ERROR: Cannot reach Memos API at {MEMOS_API}: {e.reason}", file=sys.stderr)
        return None


def fetch_recent_evals(limit=10):
    """Fetch recent self-eval memos for threshold checking."""
    url = f"{MEMOS_API}/api/v1/memos?filter=tag%3D%3D%27self-eval%27&pageSize={limit}"

    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data.get("memos", [])
    except (urllib.error.HTTPError, urllib.error.URLError) as e:
        print(f"WARNING: Could not fetch recent evals: {e}", file=sys.stderr)
        return []


def extract_score_from_memo(memo):
    """Extract quality_score from a memo's JSON block."""
    content = memo.get("content", "")
    try:
        json_start = content.index("", json_start)
        data = json.loads(content[json_start:json_end])
        return data.get("quality_score"), data.get("bottleneck")
    except (ValueError, json.JSONDecodeError):
        return None, None


def check_thresholds(current_score, current_bottleneck, recent_memos):
    """Check thresholds and print alerts."""
    alerts = []

    # Score 1-2: failure analysis
    if current_score <= 2:
        alerts.append(
            f"ALERT [FAILURE]: Score {current_score}/10 — trigger failure analysis! "
            f"Root cause investigation required."
        )

    # Score 10: breakthrough
    if current_score == 10:
        alerts.append(
            f"ALERT [BREAKTHROUGH]: Score 10/10! Document what made this exceptional. "
            f"Log to Obsidian with [[wiki-links]]."
        )

    # Check sustained average < 7
    scores = []
    bottleneck_counts = {}
    for memo in recent_memos:
        score, bottleneck = extract_score_from_memo(memo)
        if score is not None:
            scores.append(score)
        if bottleneck and bottleneck != "none":
            bottleneck_counts[bottleneck] = bottleneck_counts.get(bottleneck, 0) + 1

    # Include current eval in calculations
    scores.append(current_score)
    if current_bottleneck and current_bottleneck != "none":
        bottleneck_counts[current_bottleneck] = bottleneck_counts.get(current_bottleneck, 0) + 1

    if len(scores) >= 5:
        avg = sum(scores[-10:]) / len(scores[-10:])
        if avg < 7.0:
            alerts.append(
                f"ALERT [LOW AVERAGE]: Average score {avg:.1f}/10 over last {len(scores[-10:])} evals. "
                f"Trigger autoresearch for improvement."
            )

    # Check 3+ same bottleneck
    for bn, count in bottleneck_counts.items():
        if count >= 3:
            alerts.append(
                f"ALERT [RECURRING BOTTLENECK]: '{bn}' appeared {count} times in recent evals. "
                f"Create experiment to address this with experiment-runner.sh."
            )

    return alerts


def main():
    args = parse_args()

    # Build and post memo
    content = build_memo_content(args)
    print(f"Posting self-eval: score={args.score}/10 type={args.task_type} bottleneck={args.bottleneck}")

    result = post_memo(content)
    if result:
        memo_name = result.get("name", "unknown")
        print(f"OK: Memo posted ({memo_name})")
    else:
        print("WARNING: Memo post failed, continuing with threshold check", file=sys.stderr)

    # Check thresholds against recent evals
    recent = fetch_recent_evals(limit=10)
    alerts = check_thresholds(args.score, args.bottleneck, recent)

    if alerts:
        print("\n" + "=" * 60)
        for alert in alerts:
            print(alert)
        print("=" * 60)
    else:
        print("No threshold alerts.")


if __name__ == "__main__":
    main()
