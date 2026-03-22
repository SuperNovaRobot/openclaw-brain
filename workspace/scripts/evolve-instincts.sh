#!/usr/bin/env bash
# evolve-instincts.sh — Fetch, cluster, and evolve instincts into skills
#
# Usage:
#   ./evolve-instincts.sh              Check instinct clusters and recommend evolution
#   ./evolve-instincts.sh --status     Print cluster counts only
#
# Fetches all #instinct memos from Memos API, groups by domain,
# and recommends evolution when a domain has 5+ instincts.

set -euo pipefail

MEMOS_API="http://nova-rig:5230"
REPO_DIR="/mnt/ssd/openclaw-brain"
EVOLVED_DIR="${REPO_DIR}/workspace/skills/evolved"
EVOLUTION_THRESHOLD=5

# Ensure evolved directory exists
mkdir -p "${EVOLVED_DIR}"

usage() {
    echo "Usage:"
    echo "  $0              Check instinct clusters and recommend evolution"
    echo "  $0 --status     Print cluster counts only"
    exit 0
}

fetch_instincts() {
    # Fetch all #instinct memos and extract domain + content
    python3 - "${MEMOS_API}" <<'PYBLOCK'
import urllib.request, json, sys

api_url = sys.argv[1]
url = f"{api_url}/api/v1/memos?filter=tag%3D%3D%27instinct%27&pageSize=50"
req = urllib.request.Request(url, method="GET")
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read().decode("utf-8"))
except Exception as e:
    print(json.dumps({"error": str(e), "memos": []}))
    sys.exit(0)

memos = data.get("memos", [])
results = []
for memo in memos:
    content = memo.get("content", "")
    domain = "general"
    trigger = ""
    action = ""
    confidence = 0.0
    for line in content.split("\n"):
        if line.startswith("**Domain:**"):
            domain = line.replace("**Domain:**", "").strip()
        elif line.startswith("**Trigger:**"):
            trigger = line.replace("**Trigger:**", "").strip()
        elif line.startswith("**Action:**"):
            action = line.replace("**Action:**", "").strip()
        elif line.startswith("**Confidence:**"):
            try:
                confidence = float(line.replace("**Confidence:**", "").strip())
            except ValueError:
                pass
    results.append({
        "domain": domain,
        "trigger": trigger,
        "action": action,
        "confidence": confidence,
        "name": memo.get("name", ""),
    })
print(json.dumps({"memos": results}))
PYBLOCK
}

cluster_and_report() {
    local instinct_json="$1"
    local status_only="$2"

    python3 - "${instinct_json}" "${EVOLUTION_THRESHOLD}" "${status_only}" <<'PYBLOCK'
import json, sys

raw = sys.argv[1]
threshold = int(sys.argv[2])
status_only = sys.argv[3] == "true"

data = json.loads(raw)
if "error" in data:
    print(f"WARNING: Could not fetch instincts: {data['error']}")
    sys.exit(0)

memos = data.get("memos", [])
if not memos:
    print("No instinct memos found.")
    sys.exit(0)

# Group by domain
clusters = {}
for m in memos:
    domain = m.get("domain", "general")
    if domain not in clusters:
        clusters[domain] = []
    clusters[domain].append(m)

total = len(memos)
print(f"=== Instinct Clusters ({total} total) ===")
print()

ready_domains = []
for domain in sorted(clusters.keys()):
    items = clusters[domain]
    high_conf = [i for i in items if i.get("confidence", 0) >= 0.7]
    count = len(items)
    hc_count = len(high_conf)
    print(f"  {domain}: {count} instincts ({hc_count} high-confidence)")

    if count >= threshold and hc_count >= threshold:
        ready_domains.append((domain, items, high_conf))

print()

if status_only:
    if ready_domains:
        rd = len(ready_domains)
        print(f"{rd} domain(s) ready for evolution.")
    else:
        print("No domains ready for evolution yet.")
    sys.exit(0)

if not ready_domains:
    print(f"No domain has {threshold}+ high-confidence instincts yet.")
    print("Keep extracting instincts from sessions.")
    sys.exit(0)

for domain, items, high_conf in ready_domains:
    hc_count = len(high_conf)
    print(f">>> RECOMMEND EVOLUTION: {domain} ({hc_count} high-confidence instincts)")
    print(f"    Instincts to synthesize:")
    for inst in high_conf:
        t = inst.get("trigger", "?")
        a = inst.get("action", "?")
        print(f"      - {t} -> {a}")
    print()
PYBLOCK
}

# Main
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    usage
fi

STATUS_ONLY="false"
if [ "${1:-}" = "--status" ]; then
    STATUS_ONLY="true"
fi

echo "Fetching instinct memos from Memos API..."
INSTINCT_DATA=$(fetch_instincts)

if echo "${INSTINCT_DATA}" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if 'error' not in d else 1)" 2>/dev/null; then
    cluster_and_report "${INSTINCT_DATA}" "${STATUS_ONLY}"
else
    echo "WARNING: Could not reach Memos API at ${MEMOS_API}"
    echo "Checking local state only..."
    echo ""
    echo "Evolved skills directory: ${EVOLVED_DIR}"
    EVOLVED_COUNT=$(find "${EVOLVED_DIR}" -name "*.SKILL.md" 2>/dev/null | wc -l)
    echo "Evolved skills found: ${EVOLVED_COUNT}"
fi

echo ""
echo "=== Status ==="
echo "Evolved skills dir: ${EVOLVED_DIR}"
EVOLVED_COUNT=$(find "${EVOLVED_DIR}" -name "*.SKILL.md" 2>/dev/null | wc -l)
echo "Evolved skills: ${EVOLVED_COUNT}"
echo "Evolution threshold: ${EVOLUTION_THRESHOLD}+ high-confidence instincts per domain"
