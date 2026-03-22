#!/usr/bin/env python3
"""Metric Analyzer for OpenClaw Brain self-evaluations.

Aggregates #self-eval memos and reports trends, bottlenecks, and scores.
Uses only Python stdlib.

Usage:
    ./metric-analyzer.py              # Last 7 days
    ./metric-analyzer.py --days 30    # Last 30 days
    ./metric-analyzer.py --bottlenecks # Show bottleneck frequency
    ./metric-analyzer.py --trend       # Show score trend over time
"""

import argparse
import json
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone, timedelta

MEMOS_API = "http://nova-rig:5230"


def parse_args():
    parser = argparse.ArgumentParser(
        description="Analyze self-evaluation metrics from Memos."
    )
    parser.add_argument("--days", type=int, default=7,
                        help="Number of days to analyze (default: 7)")
    parser.add_argument("--bottlenecks", action="store_true",
                        help="Show frequency of each bottleneck type")
    parser.add_argument("--trend", action="store_true",
                        help="Show score trend over time")
    return parser.parse_args()


def fetch_eval_memos(page_size=100):
    """Fetch all self-eval memos from Memos API."""
    url = f"{MEMOS_API}/api/v1/memos?filter=tag%3D%3D%27self-eval%27&pageSize={page_size}"
    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data.get("memos", [])
    except urllib.error.HTTPError as e:
        print(f"ERROR: Memos API returned {e.code}", file=sys.stderr)
        return []
    except urllib.error.URLError as e:
        print(f"ERROR: Cannot reach Memos API at {MEMOS_API}: {e.reason}", file=sys.stderr)
        return []


def parse_eval_data(memo):
    """Extract structured eval data from a memo's JSON block."""
    content = memo.get("content", "")
    try:
        json_start = content.index("", json_start)
        data = json.loads(content[json_start:json_end])
        return data
    except (ValueError, json.JSONDecodeError):
        return None


def filter_by_days(evals, days):
    """Filter evaluations to only include those within the last N days."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    filtered = []
    for ev in evals:
        ts = ev.get("timestamp", "")
        try:
            dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
            if dt >= cutoff:
                filtered.append(ev)
        except (ValueError, AttributeError):
            # Include evals without parseable timestamps
            filtered.append(ev)
    return filtered


def print_summary(evals, days):
    """Print summary statistics."""
    if not evals:
        print(f"No self-evaluations found in the last {days} days.")
        return

    scores = [e["quality_score"] for e in evals if "quality_score" in e]
    times = [e["time_seconds"] for e in evals if "time_seconds" in e]
    tokens = [e["tokens_used"] for e in evals if e.get("tokens_used")]
    bottlenecks = [e["bottleneck"] for e in evals if e.get("bottleneck") and e["bottleneck"] != "none"]

    # Task type distribution
    type_counts = {}
    for e in evals:
        tt = e.get("task_type", "unknown")
        type_counts[tt] = type_counts.get(tt, 0) + 1

    print(f"=== Self-Evaluation Summary (last {days} days) ===")
    print(f"Total evaluations: {len(evals)}")
    print()

    if scores:
        avg_score = sum(scores) / len(scores)
        min_score = min(scores)
        max_score = max(scores)
        print(f"Average score:  {avg_score:.1f}/10")
        print(f"Min score:      {min_score}/10")
        print(f"Max score:      {max_score}/10")
        if avg_score < 7:
            print(f"  WARNING: Average below 7.0 — autoresearch recommended")
    print()

    if times:
        avg_time = sum(times) / len(times)
        print(f"Average time:   {avg_time:.0f}s ({avg_time/60:.1f}m)")

    if tokens:
        avg_tokens = sum(tokens) / len(tokens)
        print(f"Average tokens: {avg_tokens:.0f}")
    print()

    # Most common bottleneck
    if bottlenecks:
        bn_counts = {}
        for bn in bottlenecks:
            bn_counts[bn] = bn_counts.get(bn, 0) + 1
        most_common = max(bn_counts, key=bn_counts.get)
        print(f"Most common bottleneck: {most_common} ({bn_counts[most_common]} occurrences)")
        recurring = {k: v for k, v in bn_counts.items() if v >= 3}
        if recurring:
            print(f"  ALERT: Recurring bottlenecks (3+): {recurring}")
    else:
        print("No bottlenecks recorded.")
    print()

    # Task type breakdown
    print("Task types:")
    for tt, count in sorted(type_counts.items(), key=lambda x: -x[1]):
        print(f"  {tt}: {count}")


def print_bottlenecks(evals):
    """Print bottleneck frequency analysis."""
    bottleneck_counts = {}
    bottleneck_scores = {}

    for ev in evals:
        bn = ev.get("bottleneck", "unknown")
        score = ev.get("quality_score")
        bottleneck_counts[bn] = bottleneck_counts.get(bn, 0) + 1
        if score is not None:
            if bn not in bottleneck_scores:
                bottleneck_scores[bn] = []
            bottleneck_scores[bn].append(score)

    print("=== Bottleneck Analysis ===")
    print(f"{'Bottleneck':<25} {'Count':>6} {'Avg Score':>10}")
    print("-" * 43)

    for bn, count in sorted(bottleneck_counts.items(), key=lambda x: -x[1]):
        scores = bottleneck_scores.get(bn, [])
        avg = sum(scores) / len(scores) if scores else 0
        marker = " <<<" if count >= 3 and bn != "none" else ""
        print(f"{bn:<25} {count:>6} {avg:>9.1f}{marker}")


def print_trend(evals):
    """Print score trend over time."""
    # Group by date
    by_date = {}
    for ev in evals:
        ts = ev.get("timestamp", "")
        try:
            dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
            date_key = dt.strftime("%Y-%m-%d")
        except (ValueError, AttributeError):
            date_key = "unknown"
        if date_key not in by_date:
            by_date[date_key] = []
        score = ev.get("quality_score")
        if score is not None:
            by_date[date_key].append(score)

    print("=== Score Trend ===")
    print(f"{'Date':<12} {'Count':>6} {'Avg':>6} {'Min':>5} {'Max':>5}  {'Visual'}")
    print("-" * 55)

    prev_avg = None
    for date in sorted(by_date.keys()):
        scores = by_date[date]
        if not scores:
            continue
        avg = sum(scores) / len(scores)
        mn = min(scores)
        mx = max(scores)
        bar = "#" * int(avg)
        trend_indicator = ""
        if prev_avg is not None:
            if avg > prev_avg:
                trend_indicator = " ^"
            elif avg < prev_avg:
                trend_indicator = " v"
            else:
                trend_indicator = " ="
        print(f"{date:<12} {len(scores):>6} {avg:>5.1f} {mn:>5} {mx:>5}  {bar}{trend_indicator}")
        prev_avg = avg

    # Overall trend
    all_scores = []
    for date in sorted(by_date.keys()):
        all_scores.extend(by_date[date])

    if len(all_scores) >= 4:
        first_half = all_scores[:len(all_scores)//2]
        second_half = all_scores[len(all_scores)//2:]
        first_avg = sum(first_half) / len(first_half)
        second_avg = sum(second_half) / len(second_half)
        delta = second_avg - first_avg
        if delta > 0.5:
            print(f"\nOverall trend: IMPROVING (+{delta:.1f})")
        elif delta < -0.5:
            print(f"\nOverall trend: DECLINING ({delta:.1f})")
        else:
            print(f"\nOverall trend: STABLE ({delta:+.1f})")


def main():
    args = parse_args()

    # Fetch memos
    raw_memos = fetch_eval_memos()
    if not raw_memos:
        print(f"No #self-eval memos found at {MEMOS_API}.")
        print("This is normal if no evaluations have been logged yet.")
        return

    # Parse eval data
    evals = []
    for memo in raw_memos:
        data = parse_eval_data(memo)
        if data:
            evals.append(data)

    # Filter by time range
    evals = filter_by_days(evals, args.days)

    # Print requested analysis
    print_summary(evals, args.days)

    if args.bottlenecks:
        print()
        print_bottlenecks(evals)

    if args.trend:
        print()
        print_trend(evals)


if __name__ == "__main__":
    main()
