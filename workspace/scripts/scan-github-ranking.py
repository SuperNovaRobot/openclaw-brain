#!/usr/bin/env python3
"""Scan GitHub for trending/top repos and compare against known tools.

Fetches recently-pushed, high-star repositories from the GitHub Search API
(using only stdlib urllib) and diffs them against workspace/TOOLS.md so the
agent can discover new tools it doesn't know about yet.

Usage:
    ./scan-github-ranking.py                   # default: top 50, all languages
    ./scan-github-ranking.py --language python  # filter by language
    ./scan-github-ranking.py --limit 20         # limit results
    ./scan-github-ranking.py --min-stars 5000   # minimum star count
    ./scan-github-ranking.py --days 14          # pushed within last N days
"""

import argparse
import json
import os
import re
import sys
import urllib.request
import urllib.error
from datetime import datetime, timedelta, timezone


REPO_DIR = os.environ.get("OPENCLAW_REPO", "/mnt/ssd/openclaw-brain")
TOOLS_MD = os.path.join(REPO_DIR, "workspace", "TOOLS.md")
GITHUB_API = "https://api.github.com"

# Domains the agent cares about
RELEVANT_TOPICS = [
    "ai", "llm", "agent", "robotics", "memory", "rag", "mcp",
    "autonomous", "embedding", "vector", "knowledge-graph",
    "self-improvement", "coding-agent", "cli", "devtools",
    "humanoid", "jetson", "cuda", "inference", "fine-tuning",
]


def parse_args():
    parser = argparse.ArgumentParser(
        description="Scan GitHub for trending repos not yet in TOOLS.md"
    )
    parser.add_argument("--language", default="",
                        help="Filter by programming language (e.g. python, rust)")
    parser.add_argument("--limit", type=int, default=50,
                        help="Max repos to fetch (default: 50, max: 100)")
    parser.add_argument("--min-stars", type=int, default=1000,
                        help="Minimum star count (default: 1000)")
    parser.add_argument("--days", type=int, default=7,
                        help="Only repos pushed within last N days (default: 7)")
    parser.add_argument("--json", action="store_true",
                        help="Output raw JSON (default: human-readable)")
    return parser.parse_args()


def load_known_tools(tools_path):
    """Extract repo names/URLs already mentioned in TOOLS.md."""
    known = set()
    if not os.path.isfile(tools_path):
        print(f"WARNING: TOOLS.md not found at {tools_path}", file=sys.stderr)
        return known

    with open(tools_path, "r") as f:
        content = f.read().lower()

    # Extract org/repo patterns and standalone tool names
    # Matches things like: EvanLi/Github-Ranking, infiniflow/ragflow
    repo_pattern = re.compile(r'([a-z0-9_.-]+/[a-z0-9_.-]+)')
    for match in repo_pattern.finditer(content):
        known.add(match.group(1))

    # Also extract ### headers as tool names
    header_pattern = re.compile(r'^###\s+(\S+)', re.MULTILINE)
    for match in header_pattern.finditer(content):
        known.add(match.group(1).lower())

    return known


def fetch_trending(language, limit, min_stars, days):
    """Fetch trending repos from GitHub Search API."""
    cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).strftime("%Y-%m-%d")
    per_page = min(limit, 100)

    query_parts = [f"stars:>{min_stars}", f"pushed:>{cutoff}"]
    if language:
        query_parts.append(f"language:{language}")

    query = "+".join(query_parts)
    url = f"{GITHUB_API}/search/repositories?q={query}&sort=stars&order=desc&per_page={per_page}"

    headers = {
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "OpenClaw-Discovery-Scanner/1.0",
    }

    # Use token if available
    token = os.environ.get("GITHUB_TOKEN", "")
    if token:
        headers["Authorization"] = f"token {token}"

    req = urllib.request.Request(url, headers=headers)

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data.get("items", [])
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"ERROR: GitHub API returned {e.code}: {body}", file=sys.stderr)
        return []
    except urllib.error.URLError as e:
        print(f"ERROR: Cannot reach GitHub API: {e.reason}", file=sys.stderr)
        return []


def is_relevant(repo):
    """Quick relevance check based on topic and description keywords."""
    description = (repo.get("description") or "").lower()
    topics = [t.lower() for t in repo.get("topics", [])]
    name = repo.get("full_name", "").lower()

    all_text = f"{name} {description} {' '.join(topics)}"

    for topic in RELEVANT_TOPICS:
        if topic in all_text:
            return True
    return False


def main():
    args = parse_args()
    known = load_known_tools(TOOLS_MD)

    # Fetch from GitHub
    repos = fetch_trending(args.language, args.limit, args.min_stars, args.days)

    if not repos:
        if args.json:
            print(json.dumps({"new_repos": [], "total_fetched": 0, "known_filtered": 0}))
        else:
            print("No repos fetched. Check network or API rate limits.")
        sys.exit(0)

    # Filter out known tools
    new_repos = []
    filtered_count = 0
    for repo in repos:
        full_name = repo.get("full_name", "").lower()
        name = repo.get("name", "").lower()

        # Skip if already in TOOLS.md
        if full_name in known or name in known:
            filtered_count += 1
            continue

        # Check partial matches (e.g. "ragflow" matches "infiniflow/ragflow")
        skip = False
        for k in known:
            if name in k or k in full_name:
                skip = True
                break
        if skip:
            filtered_count += 1
            continue

        entry = {
            "full_name": repo.get("full_name", ""),
            "url": repo.get("html_url", ""),
            "description": repo.get("description", ""),
            "stars": repo.get("stargazers_count", 0),
            "language": repo.get("language", ""),
            "topics": repo.get("topics", []),
            "pushed_at": repo.get("pushed_at", ""),
            "created_at": repo.get("created_at", ""),
            "relevant": is_relevant(repo),
        }
        new_repos.append(entry)

    # Sort: relevant first, then by stars
    new_repos.sort(key=lambda r: (not r["relevant"], -r["stars"]))

    if args.json:
        output = {
            "new_repos": new_repos,
            "total_fetched": len(repos),
            "known_filtered": filtered_count,
            "scan_time": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        }
        print(json.dumps(output, indent=2))
    else:
        print(f"GitHub Scan Results")
        print(f"  Fetched: {len(repos)} | Known (filtered): {filtered_count} | New: {len(new_repos)}")
        print()
        for r in new_repos:
            tag = "[RELEVANT]" if r["relevant"] else "[        ]"
            stars = f"{r['stars']:>6}"
            lang = r.get("language") or "?"
            print(f"  {tag} {stars}★  {r['full_name']}  ({lang})")
            if r["description"]:
                desc = r["description"][:80]
                print(f"           {desc}")
            print()

    # Write JSON to stdout for piping (if not already in json mode)
    if not args.json:
        # Also write a machine-readable summary to stderr for piping
        summary = json.dumps({
            "new_repos": new_repos,
            "total_fetched": len(repos),
            "known_filtered": filtered_count,
        })
        print(f"\n__JSON__:{summary}", file=sys.stderr)


if __name__ == "__main__":
    main()
