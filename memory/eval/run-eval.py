#!/usr/bin/env python3
"""
OpenClaw Memory Eval Harness
=============================
Runs curated test cases against the 5-layer memory stack, computes
retrieval metrics (Precision@5, MRR, NDCG@5), checks layer/hook/world-model
health, and stores a composite compliance score in Postgres.

stdlib ONLY: json, urllib.request, math, subprocess, os, sys, datetime, uuid
Designed to run on nova's system python3.

Usage:
  python3 run-eval.py                    # reads test-cases.jsonl from same dir
  python3 run-eval.py /path/to/cases.jsonl
"""

import json
import math
import os
import subprocess
import sys
import uuid
from datetime import datetime, timezone
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError
from urllib.parse import quote

# ===========================================================================
# Configuration
# ===========================================================================
MEMOS_API = os.environ.get("MEMOS_API_URL", "http://100.76.233.80:5230")
MEMOS_USER = os.environ.get("MEMOS_USER", "openclaw")
MEMOS_PASS = os.environ.get("MEMOS_PASSWORD", "changeme")

RAGFLOW_API = os.environ.get("RAGFLOW_API", "http://100.76.233.80:9380/api/v1")
RAGFLOW_KEY = os.environ.get("RAGFLOW_KEY", "ragflow-c5062fdd133375fcef53c7b91eca624c")
# Search across both agent-memory and lcm-summaries datasets
RAGFLOW_DATASET_IDS = [
    "99f73ffc260011f1b983a57a35761573",   # agent-memory
    "4a543fc0263e11f1b983a57a35761573",   # lcm-summaries
]

POSTGRES_CONTAINER = "nova-postgres"
POSTGRES_USER = "openclaw"
POSTGRES_DB = "openclaw"

LCM_DB_PATH = os.path.expanduser("~/.openclaw/lcm.db")
OBSIDIAN_VAULT = "/mnt/ssd/obsidian-vault"

TOP_K = 5  # for Precision@K, NDCG@K


# ===========================================================================
# HTTP helpers (stdlib only)
# ===========================================================================
def http_json(url, method="GET", data=None, headers=None, timeout=10):
    """Make an HTTP request and return parsed JSON, or None on failure."""
    hdrs = headers or {}
    body = None
    if data is not None:
        body = json.dumps(data).encode("utf-8")
        hdrs.setdefault("Content-Type", "application/json")
    req = Request(url, data=body, headers=hdrs, method=method)
    try:
        with urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except (URLError, HTTPError, OSError, json.JSONDecodeError, ValueError) as e:
        return None


def run_cmd(args, timeout=15):
    """Run a subprocess and return (returncode, stdout_str)."""
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout.strip()
    except Exception:
        return 1, ""


# ===========================================================================
# Memos API
# ===========================================================================
_memos_token_cache = None

def get_memos_token():
    """Authenticate to Memos and return a JWT access token."""
    global _memos_token_cache
    if _memos_token_cache:
        return _memos_token_cache
    payload = {"passwordCredentials": {"username": MEMOS_USER, "password": MEMOS_PASS}}
    resp = http_json(
        f"{MEMOS_API}/memos.api.v1.AuthService/SignIn",
        method="POST",
        data=payload,
        timeout=8,
    )
    if resp and resp.get("accessToken"):
        _memos_token_cache = resp["accessToken"]
        return _memos_token_cache
    return None


def query_memos(query_text, page_size=10):
    """
    Search Memos for content containing query_text.
    Returns list of content strings (up to page_size).
    """
    token = get_memos_token()
    if not token:
        return []

    # Memos v1 API filter format
    encoded_query = quote(query_text)
    url = (
        f"{MEMOS_API}/api/v1/memos"
        f"?pageSize={page_size}"
        f"&filter=content.contains('{encoded_query}')"
    )
    headers = {"Authorization": f"Bearer {token}"}
    resp = http_json(url, headers=headers, timeout=10)
    if not resp:
        return []

    memos_list = resp.get("memos", [])
    return [m.get("content", "") for m in memos_list if m.get("content")]


# ===========================================================================
# RagFlow API
# ===========================================================================
def query_ragflow(query_text, top_k=TOP_K):
    """
    Query RagFlow retrieval endpoint across configured datasets.
    Returns list of content strings.
    """
    headers = {
        "Authorization": f"Bearer {RAGFLOW_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "question": query_text,
        "dataset_ids": RAGFLOW_DATASET_IDS,
        "top_k": top_k,
    }
    resp = http_json(
        f"{RAGFLOW_API}/retrieval",
        method="POST",
        data=payload,
        headers=headers,
        timeout=30,
    )
    if not resp or resp.get("code", -1) != 0:
        return []

    chunks = resp.get("data", {}).get("chunks", [])
    return [c.get("content", "") for c in chunks if c.get("content")]


# ===========================================================================
# Scoring helpers
# ===========================================================================
def result_is_relevant(result_text, expected_keywords):
    """Check if result_text contains at least one expected keyword (case-insensitive)."""
    lower = result_text.lower()
    return any(kw.lower() in lower for kw in expected_keywords)


def compute_precision_at_k(results, expected, k=TOP_K):
    """Fraction of top-k results that contain at least one expected keyword."""
    top = results[:k]
    if not top:
        return 0.0
    relevant = sum(1 for r in top if result_is_relevant(r, expected))
    return relevant / len(top)


def compute_mrr(results, expected):
    """1/rank of the first relevant result."""
    for i, r in enumerate(results):
        if result_is_relevant(r, expected):
            return 1.0 / (i + 1)
    return 0.0


def compute_ndcg_at_k(results, expected, k=TOP_K):
    """NDCG@k with binary relevance (1 if relevant, 0 otherwise)."""
    top = results[:k]
    if not top:
        return 0.0

    # DCG
    dcg = 0.0
    for i, r in enumerate(top):
        rel = 1.0 if result_is_relevant(r, expected) else 0.0
        dcg += rel / math.log2(i + 2)  # i+2 because log2(1)=0

    # Ideal DCG: all relevant results at top
    n_relevant = sum(1 for r in top if result_is_relevant(r, expected))
    idcg = 0.0
    for i in range(n_relevant):
        idcg += 1.0 / math.log2(i + 2)

    if idcg == 0.0:
        return 0.0
    return dcg / idcg


# ===========================================================================
# Layer health checks
# ===========================================================================
def check_memos_health():
    """Check Memos API responds."""
    token = get_memos_token()
    if not token:
        return False
    headers = {"Authorization": f"Bearer {token}"}
    resp = http_json(f"{MEMOS_API}/api/v1/memos?pageSize=1", headers=headers, timeout=8)
    return resp is not None


def check_ragflow_health():
    """Check RagFlow API responds."""
    headers = {"Authorization": f"Bearer {RAGFLOW_KEY}"}
    resp = http_json(f"{RAGFLOW_API}/datasets", headers=headers, timeout=10)
    return resp is not None and resp.get("code", -1) == 0


def check_lcm_health():
    """Check LCM SQLite database is accessible."""
    rc, _ = run_cmd([
        "python3", "-c",
        f"import sqlite3; sqlite3.connect('{LCM_DB_PATH}').execute('SELECT 1')"
    ])
    return rc == 0


def check_obsidian_health():
    """Check Obsidian vault directory exists."""
    return os.path.isdir(OBSIDIAN_VAULT)


def check_notebooklm_health():
    """Check nlm CLI is installed."""
    rc, _ = run_cmd(["which", "nlm"])
    return rc == 0


def get_layer_health():
    """Return dict of layer name -> bool."""
    return {
        "memos": check_memos_health(),
        "ragflow": check_ragflow_health(),
        "lcm": check_lcm_health(),
        "obsidian": check_obsidian_health(),
        "notebooklm": check_notebooklm_health(),
    }


# ===========================================================================
# Hook health check
# ===========================================================================
def check_hook_health():
    """Check gateway is running."""
    rc, out = run_cmd(["systemctl", "--user", "is-active", "openclaw-gateway"])
    return {
        "gateway": out.strip() == "active",
        "status": out.strip() if out.strip() else "unknown",
    }


# ===========================================================================
# World model population
# ===========================================================================
def pg_count(table):
    """Count rows in a Postgres table via docker exec."""
    rc, out = run_cmd([
        "docker", "exec", POSTGRES_CONTAINER,
        "psql", "-U", POSTGRES_USER, "-d", POSTGRES_DB,
        "-t", "-c", f"SELECT count(*) FROM {table}",
    ])
    if rc == 0:
        try:
            return int(out.strip())
        except ValueError:
            return 0
    return 0


def get_world_model():
    """Count entities, beliefs, facts in Postgres."""
    return {
        "entities": pg_count("memory_entities"),
        "beliefs": pg_count("memory_beliefs"),
        "facts": pg_count("memory_facts"),
    }


# ===========================================================================
# Compliance score
# ===========================================================================
def compute_compliance(avg_precision, avg_mrr, avg_ndcg, layer_health, hook_health, world_model):
    """
    Composite compliance score (0.0 - 1.0):
      40% recall metrics (average of Precision@5, MRR, NDCG@5)
      20% layer health (fraction of 5 layers responding)
      20% hook health (gateway running)
      20% world model population (any entities, beliefs, facts > 0)
    """
    # 40% recall
    recall_score = (avg_precision + avg_mrr + avg_ndcg) / 3.0

    # 20% layer health
    healthy_layers = sum(1 for v in layer_health.values() if v)
    layer_score = healthy_layers / max(len(layer_health), 1)

    # 20% hook health
    hook_score = 1.0 if hook_health.get("gateway", False) else 0.0

    # 20% world model (3 tables, each contributes 1/3 if count > 0)
    wm_checks = 0
    for key in ("entities", "beliefs", "facts"):
        if world_model.get(key, 0) > 0:
            wm_checks += 1
    wm_score = wm_checks / 3.0

    compliance = (
        0.40 * recall_score
        + 0.20 * layer_score
        + 0.20 * hook_score
        + 0.20 * wm_score
    )
    return compliance


# ===========================================================================
# Store results in Postgres
# ===========================================================================
def store_results(run_id, precision_k, mrr, ndcg_5, compliance,
                  layer_health, hook_health, world_model, notes=""):
    """Insert eval results into memory_eval_results table."""
    cron_health_json = json.dumps(hook_health).replace("'", "''")
    layer_health_json = json.dumps(layer_health).replace("'", "''")
    world_model_json = json.dumps(world_model).replace("'", "''")
    notes_escaped = (notes or "").replace("'", "''")

    sql = (
        f"INSERT INTO memory_eval_results "
        f"(run_id, precision_k, mrr, ndcg_5, compliance, layer_health, cron_health, world_model, notes) "
        f"VALUES ("
        f"'{run_id}', {precision_k}, {mrr}, {ndcg_5}, {compliance}, "
        f"'{layer_health_json}'::jsonb, '{cron_health_json}'::jsonb, "
        f"'{world_model_json}'::jsonb, '{notes_escaped}'"
        f")"
    )

    rc, out = run_cmd([
        "docker", "exec", POSTGRES_CONTAINER,
        "psql", "-U", POSTGRES_USER, "-d", POSTGRES_DB,
        "-c", sql,
    ])
    return rc == 0


# ===========================================================================
# Main
# ===========================================================================
def main():
    # Determine test cases file
    if len(sys.argv) > 1:
        cases_path = sys.argv[1]
    else:
        cases_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test-cases.jsonl")

    if not os.path.exists(cases_path):
        print(f"ERROR: Test cases file not found: {cases_path}", file=sys.stderr)
        sys.exit(1)

    # Load test cases
    test_cases = []
    with open(cases_path) as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                test_cases.append(json.loads(line))
            except json.JSONDecodeError as e:
                print(f"WARNING: Skipping invalid JSON at line {line_num}: {e}", file=sys.stderr)

    if not test_cases:
        print("ERROR: No test cases loaded", file=sys.stderr)
        sys.exit(1)

    print("=== Memory Eval Harness ===")
    print(f"Test cases: {len(test_cases)}")
    print()

    # Run retrieval tests
    all_precision = []
    all_mrr = []
    all_ndcg = []

    for i, tc in enumerate(test_cases, 1):
        query = tc["query"]
        expected = tc["expected"]
        layer = tc.get("layer", "any")

        results = []

        # Query appropriate layer(s)
        if layer == "memos":
            results = query_memos(query, page_size=TOP_K)
        elif layer == "any":
            # Query both Memos and RagFlow, merge results
            memos_results = query_memos(query, page_size=TOP_K)
            ragflow_results = query_ragflow(query, top_k=TOP_K)
            results = memos_results + ragflow_results
        else:
            results = query_memos(query, page_size=TOP_K)

        # Score
        p = compute_precision_at_k(results, expected, TOP_K)
        m = compute_mrr(results, expected)
        n = compute_ndcg_at_k(results, expected, TOP_K)

        all_precision.append(p)
        all_mrr.append(m)
        all_ndcg.append(n)

        # Status indicator
        hit = "HIT" if m > 0 else "MISS"
        print(f"  [{i:2d}/{len(test_cases)}] {hit:4s}  P@5={p:.2f}  MRR={m:.2f}  NDCG={n:.2f}  | {query}")

    print()

    # Aggregate retrieval metrics
    avg_precision = sum(all_precision) / len(all_precision) if all_precision else 0.0
    avg_mrr = sum(all_mrr) / len(all_mrr) if all_mrr else 0.0
    avg_ndcg = sum(all_ndcg) / len(all_ndcg) if all_ndcg else 0.0

    # Layer health
    print("Checking layer health...")
    layer_health = get_layer_health()
    healthy_count = sum(1 for v in layer_health.values() if v)
    for name, ok in layer_health.items():
        status = "OK" if ok else "FAIL"
        print(f"  {name:12s}: {status}")
    print()

    # Hook health
    print("Checking hook health...")
    hook_health = check_hook_health()
    hook_status = "OK" if hook_health.get("gateway") else f"FAIL ({hook_health.get('status', 'unknown')})"
    print(f"  gateway: {hook_status}")
    print()

    # World model
    print("Checking world model...")
    world_model = get_world_model()
    print(f"  entities={world_model['entities']}, beliefs={world_model['beliefs']}, facts={world_model['facts']}")
    print()

    # Compliance
    compliance = compute_compliance(avg_precision, avg_mrr, avg_ndcg, layer_health, hook_health, world_model)

    # Generate run ID
    run_id = str(uuid.uuid4())

    # Store results
    notes = f"Baseline eval run at {datetime.now(timezone.utc).isoformat()}"
    stored = store_results(run_id, avg_precision, avg_mrr, avg_ndcg, compliance,
                           layer_health, hook_health, world_model, notes)

    # Print summary
    print("=" * 40)
    print(f"Precision@5:  {avg_precision:.2f}")
    print(f"MRR:          {avg_mrr:.2f}")
    print(f"NDCG@5:       {avg_ndcg:.2f}")
    print(f"Layer health:  {healthy_count}/5")
    print(f"Hook health:  {hook_status}")
    print(f"World model:  entities={world_model['entities']}, beliefs={world_model['beliefs']}, facts={world_model['facts']}")
    print(f"Compliance:   {compliance:.2f}")
    if stored:
        print(f"Stored as run_id: {run_id}")
    else:
        print(f"WARNING: Failed to store results in Postgres (run_id: {run_id})")

    return 0


if __name__ == "__main__":
    sys.exit(main())
