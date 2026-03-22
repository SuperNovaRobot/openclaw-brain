#!/usr/bin/env python3
"""Tool Evaluator for OpenClaw Discovery Scanner.

Takes a repo URL or JSON input from scan-github-ranking.py and scores
relevance on a 1-10 scale based on how useful the tool would be for the
OpenClaw agent. Uses only Python stdlib.

Usage:
    ./tool-evaluator.py --url https://github.com/org/repo
    ./tool-evaluator.py --json '{"full_name":"org/repo","stars":5000,...}'
    echo '[{...},{...}]' | ./tool-evaluator.py --stdin
    ./tool-evaluator.py --help
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

# Domains and keywords for scoring
CAPABILITY_DOMAINS = {
    "memory": ["memory", "rag", "vector", "embedding", "knowledge-graph",
               "retrieval", "semantic-search", "indexing", "cache"],
    "ai": ["llm", "ai", "ml", "transformer", "inference", "fine-tuning",
            "training", "neural", "deep-learning", "model", "gpt", "gemini"],
    "robotics": ["robotics", "humanoid", "motor", "sensor", "perception",
                 "navigation", "simulation", "jetson", "cuda", "ros"],
    "coding": ["agent", "coding", "ide", "linter", "formatter", "refactor",
               "ast", "compiler", "debugger", "devtools", "cli"],
    "mcp": ["mcp", "model-context-protocol", "tool-use", "function-calling"],
    "automation": ["automation", "workflow", "pipeline", "orchestration",
                   "scheduler", "cron", "ci-cd"],
}

# Existing capabilities from TOOLS.md (keywords)
EXISTING_CAPABILITIES = [
    "memos", "obsidian", "ragflow", "surfsense", "crawl4ai",
    "notebooklm", "tavily", "acpx", "clawteam", "gws", "gh",
    "dimos", "riva", "airi", "cli-anything", "github-ranking",
]


def parse_args():
    parser = argparse.ArgumentParser(
        description="Evaluate a repo's relevance to OpenClaw (score 1-10)"
    )
    parser.add_argument("--url", default="",
                        help="GitHub repo URL to evaluate")
    parser.add_argument("--json", dest="json_input", default="",
                        help="JSON string with repo data")
    parser.add_argument("--stdin", action="store_true",
                        help="Read JSON array from stdin")
    parser.add_argument("--threshold", type=int, default=0,
                        help="Only output repos scoring >= threshold")
    parser.add_argument("--verbose", action="store_true",
                        help="Show detailed scoring breakdown")
    return parser.parse_args()


def fetch_repo_info(url_or_name):
    """Fetch repo info from GitHub API given a URL or owner/repo string."""
    # Extract owner/repo from URL
    match = re.search(r'github\.com/([^/]+/[^/]+)', url_or_name)
    if match:
        owner_repo = match.group(1).rstrip("/")
    else:
        owner_repo = url_or_name.strip("/")

    api_url = f"{GITHUB_API}/repos/{owner_repo}"
    headers = {
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "OpenClaw-Tool-Evaluator/1.0",
    }
    token = os.environ.get("GITHUB_TOKEN", "")
    if token:
        headers["Authorization"] = f"token {token}"

    req = urllib.request.Request(api_url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return {
                "full_name": data.get("full_name", ""),
                "url": data.get("html_url", ""),
                "description": data.get("description", ""),
                "stars": data.get("stargazers_count", 0),
                "language": data.get("language", ""),
                "topics": data.get("topics", []),
                "pushed_at": data.get("pushed_at", ""),
                "created_at": data.get("created_at", ""),
                "has_wiki": data.get("has_wiki", False),
                "license": (data.get("license") or {}).get("spdx_id", ""),
            }
    except urllib.error.HTTPError as e:
        print(f"ERROR: GitHub API returned {e.code} for {owner_repo}", file=sys.stderr)
        return None
    except urllib.error.URLError as e:
        print(f"ERROR: Cannot reach GitHub API: {e.reason}", file=sys.stderr)
        return None


def load_tools_md():
    """Load TOOLS.md content for capability comparison."""
    if not os.path.isfile(TOOLS_MD):
        return ""
    with open(TOOLS_MD, "r") as f:
        return f.read().lower()


def score_repo(repo, tools_content=""):
    """Score a repo 1-10 with detailed reasoning.

    Scoring rubric:
      +3  Improves an existing capability (overlaps with TOOLS.md domains)
      +3  Related to our domains (AI, memory, robotics, coding)
      +1  Stars > 1,000
      +1  Stars > 10,000 (additional, so +2 total for >10k)
      +1  Recent activity (pushed in last 30 days)
      +1  Has MCP or CLI interface
    Max possible: 10
    """
    score = 0
    reasons = []
    name = repo.get("full_name", "").lower()
    desc = (repo.get("description") or "").lower()
    topics = [t.lower() for t in repo.get("topics", [])]
    language = (repo.get("language") or "").lower()
    stars = repo.get("stars", 0)
    pushed_at = repo.get("pushed_at", "")
    all_text = f"{name} {desc} {' '.join(topics)}"

    # --- Criterion 1: Improves existing capability (+3) ---
    improves_existing = False
    improved_tools = []
    for existing in EXISTING_CAPABILITIES:
        if existing in all_text:
            improves_existing = True
            improved_tools.append(existing)
    # Also check domain overlap with tools_content
    for domain, keywords in CAPABILITY_DOMAINS.items():
        for kw in keywords:
            if kw in all_text and kw in tools_content:
                improves_existing = True
                if domain not in improved_tools:
                    improved_tools.append(domain)
                break

    if improves_existing:
        score += 3
        reasons.append(f"+3 improves existing capability ({', '.join(improved_tools[:3])})")

    # --- Criterion 2: Related to our domains (+3) ---
    matched_domains = []
    for domain, keywords in CAPABILITY_DOMAINS.items():
        for kw in keywords:
            if kw in all_text:
                matched_domains.append(domain)
                break

    if matched_domains:
        domain_score = min(len(matched_domains), 3)
        score += domain_score
        reasons.append(f"+{domain_score} relevant domains ({', '.join(matched_domains[:4])})")

    # --- Criterion 3: Stars (+1 for >1k, +1 more for >10k) ---
    if stars > 10000:
        score += 2
        reasons.append(f"+2 high stars ({stars:,})")
    elif stars > 1000:
        score += 1
        reasons.append(f"+1 stars ({stars:,})")

    # --- Criterion 4: Recent activity (+1) ---
    if pushed_at:
        try:
            pushed_dt = datetime.strptime(pushed_at[:10], "%Y-%m-%d").replace(
                tzinfo=timezone.utc
            )
            if (datetime.now(timezone.utc) - pushed_dt).days <= 30:
                score += 1
                reasons.append("+1 recently active")
        except ValueError:
            pass

    # --- Criterion 5: Has MCP or CLI interface (+1) ---
    mcp_cli_indicators = ["mcp", "cli", "command-line", "terminal", "shell",
                          "sdk", "api", "plugin"]
    for indicator in mcp_cli_indicators:
        if indicator in all_text:
            score += 1
            reasons.append(f"+1 has {indicator} interface")
            break

    # Clamp to 1-10
    score = max(1, min(10, score))

    # Determine recommended action
    if score >= 7:
        action = "ADD_TO_TOOLS"
        action_detail = "High relevance. Add to TOOLS.md and create Obsidian note."
    elif score >= 4:
        action = "WATCH"
        action_detail = "Moderate relevance. Log as potential tool for future review."
    else:
        action = "SKIP"
        action_detail = "Low relevance. No action needed."

    return {
        "full_name": repo.get("full_name", ""),
        "url": repo.get("url", repo.get("html_url", "")),
        "description": repo.get("description", ""),
        "stars": stars,
        "language": repo.get("language", ""),
        "score": score,
        "reasons": reasons,
        "action": action,
        "action_detail": action_detail,
        "matched_domains": matched_domains,
        "evaluated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }


def main():
    args = parse_args()
    tools_content = load_tools_md()

    repos_to_eval = []

    # Source 1: URL
    if args.url:
        info = fetch_repo_info(args.url)
        if info:
            repos_to_eval.append(info)
        else:
            print("ERROR: Could not fetch repo info", file=sys.stderr)
            sys.exit(1)

    # Source 2: JSON string
    elif args.json_input:
        try:
            data = json.loads(args.json_input)
            if isinstance(data, list):
                repos_to_eval = data
            else:
                repos_to_eval = [data]
        except json.JSONDecodeError as e:
            print(f"ERROR: Invalid JSON: {e}", file=sys.stderr)
            sys.exit(1)

    # Source 3: stdin
    elif args.stdin:
        try:
            raw = sys.stdin.read()
            data = json.loads(raw)
            if isinstance(data, list):
                repos_to_eval = data
            else:
                repos_to_eval = [data]
        except json.JSONDecodeError as e:
            print(f"ERROR: Invalid JSON on stdin: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        print("ERROR: Provide --url, --json, or --stdin", file=sys.stderr)
        sys.exit(1)

    # Evaluate each repo
    results = []
    for repo in repos_to_eval:
        result = score_repo(repo, tools_content)
        if args.threshold and result["score"] < args.threshold:
            continue
        results.append(result)

    # Sort by score descending
    results.sort(key=lambda r: -r["score"])

    if args.verbose:
        for r in results:
            print(f"\n{'='*60}")
            print(f"  {r['full_name']}  ({r['stars']:,}★)")
            print(f"  {r['description']}")
            print(f"  Score: {r['score']}/10 — Action: {r['action']}")
            print(f"  {r['action_detail']}")
            print(f"  Breakdown:")
            for reason in r['reasons']:
                print(f"    {reason}")
            print(f"{'='*60}")

    # Always output JSON
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
