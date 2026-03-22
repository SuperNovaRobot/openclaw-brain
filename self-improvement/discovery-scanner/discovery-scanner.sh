#!/usr/bin/env bash
# discovery-scanner.sh — Weekly discovery scanner for OpenClaw Brain
#
# Orchestrates the discovery pipeline:
#   1. Scan GitHub for trending repos (scan-github-ranking.py)
#   2. Evaluate relevance of each new repo (tool-evaluator.py)
#   3. Score >= 7: log to Memos #discovery + create Obsidian note
#   4. Score 4-6: log to Memos #potential-tool
#   5. Print summary of discoveries
#
# Designed to be called weekly by HEARTBEAT cron or manually.
#
# Usage:
#   ./discovery-scanner.sh              # full scan
#   ./discovery-scanner.sh --dry-run    # scan and evaluate but skip Memos/Obsidian
#   ./discovery-scanner.sh --language python --limit 20

set -euo pipefail

REPO_DIR="/mnt/ssd/openclaw-brain"
SCRIPTS_DIR="${REPO_DIR}/workspace/scripts"
VAULT_DIR="${REPO_DIR}/obsidian-vault"
MEMOS_API="http://nova-rig:5230"
SCAN_SCRIPT="${SCRIPTS_DIR}/scan-github-ranking.py"
EVAL_SCRIPT="${SCRIPTS_DIR}/tool-evaluator.py"

DRY_RUN=false
LANGUAGE=""
LIMIT=50
MIN_STARS=1000

# Parse arguments — pass through to scan script but capture our flags
SCAN_ARGS=()
for arg in "$@"; do
    case "${arg}" in
        --dry-run)
            DRY_RUN=true
            ;;
        --language)
            shift_next=language
            SCAN_ARGS+=("${arg}")
            ;;
        --limit)
            shift_next=limit
            SCAN_ARGS+=("${arg}")
            ;;
        *)
            if [ "${shift_next:-}" = "language" ]; then
                LANGUAGE="${arg}"
                shift_next=""
            elif [ "${shift_next:-}" = "limit" ]; then
                LIMIT="${arg}"
                shift_next=""
            fi
            SCAN_ARGS+=("${arg}")
            ;;
    esac
done

log() { echo "[discovery] $(date +%H:%M:%S) $*"; }

post_memo() {
    local content="$1"
    if [ "${DRY_RUN}" = true ]; then
        log "DRY-RUN: Would post memo"
        return 0
    fi

    python3 - "${MEMOS_API}" "${content}" <<'PYBLOCK'
import urllib.request, json, sys

api_url = sys.argv[1]
content = sys.argv[2]
url = f"{api_url}/api/v1/memos"
payload = json.dumps({"content": content, "visibility": "PRIVATE"}).encode("utf-8")
req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"}, method="POST")
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        result = json.loads(resp.read().decode("utf-8"))
        print(f"OK: {result.get('name', 'posted')}")
except Exception as e:
    print(f"WARNING: Memo post failed: {e}", file=sys.stderr)
PYBLOCK
}

create_obsidian_note() {
    local name="$1"
    local url="$2"
    local description="$3"
    local score="$4"
    local domains="$5"
    local stars="$6"

    if [ "${DRY_RUN}" = true ]; then
        log "DRY-RUN: Would create Obsidian note for ${name}"
        return 0
    fi

    local safe_name
    safe_name=$(echo "${name}" | tr '/' '-')
    local note_path="${VAULT_DIR}/tools/${safe_name}.md"
    local today
    today=$(date +%Y-%m-%d)

    mkdir -p "${VAULT_DIR}/tools"

    cat > "${note_path}" <<NOTEEOF
---
discovered: ${today}
score: ${score}
stars: ${stars}
source: discovery-scanner
---

# ${name}

${description}

- **GitHub:** ${url}
- **Stars:** ${stars}
- **Score:** ${score}/10
- **Domains:** ${domains}

## Status

Discovered by [[discovery-scanner]] on ${today}. Pending evaluation for integration.

## Links

- [[TOOLS]] — master capability registry
- [[self-improvement]] — autoresearch loop
- [[daily/${today}]] — discovery log
NOTEEOF

    log "Created Obsidian note: tools/${safe_name}.md"
}

# Verify dependencies
if [ ! -x "${SCAN_SCRIPT}" ]; then
    echo "ERROR: scan-github-ranking.py not found or not executable at ${SCAN_SCRIPT}" >&2
    exit 1
fi
if [ ! -x "${EVAL_SCRIPT}" ]; then
    echo "ERROR: tool-evaluator.py not found or not executable at ${EVAL_SCRIPT}" >&2
    exit 1
fi

echo "============================================"
echo "  OpenClaw Discovery Scanner"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
echo ""

# Step 1: Scan GitHub
log "Scanning GitHub for trending repos..."
SCAN_OUTPUT=$(python3 "${SCAN_SCRIPT}" --json "${SCAN_ARGS[@]}" 2>/dev/null || true)

if [ -z "${SCAN_OUTPUT}" ]; then
    log "WARNING: Scan returned empty results. Check network or API rate limits."
    echo ""
    echo "=== Summary ==="
    echo "  Scan failed or returned no results."
    exit 0
fi

# Extract count
REPO_COUNT=$(echo "${SCAN_OUTPUT}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
repos = data.get('new_repos', [])
print(len(repos))
" 2>/dev/null || echo "0")

log "Found ${REPO_COUNT} new repos to evaluate"

if [ "${REPO_COUNT}" = "0" ]; then
    echo ""
    echo "=== Summary ==="
    echo "  No new repos discovered. All trending repos already known."
    exit 0
fi

# Step 2: Evaluate each repo
log "Evaluating repos for relevance..."

EVAL_INPUT=$(echo "${SCAN_OUTPUT}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(json.dumps(data.get('new_repos', [])))
" 2>/dev/null)

EVAL_OUTPUT=$(echo "${EVAL_INPUT}" | python3 "${EVAL_SCRIPT}" --stdin 2>/dev/null || true)

if [ -z "${EVAL_OUTPUT}" ]; then
    log "WARNING: Evaluation failed."
    echo ""
    echo "=== Summary ==="
    echo "  Evaluation step failed."
    exit 0
fi

# Step 3: Process results by score tier
HIGH_COUNT=0
MID_COUNT=0
LOW_COUNT=0

# Parse and act on each result
python3 - "${EVAL_OUTPUT}" "${DRY_RUN}" <<'PYBLOCK' | while IFS='|' read -r tier full_name url description score domains stars; do
import json, sys

results = json.loads(sys.argv[1])
dry_run = sys.argv[2]

for r in results:
    score = r.get("score", 0)
    name = r.get("full_name", "")
    url = r.get("url", "")
    desc = (r.get("description") or "")[:120]
    domains = ", ".join(r.get("matched_domains", []))
    stars = r.get("stars", 0)

    if score >= 7:
        tier = "HIGH"
    elif score >= 4:
        tier = "MID"
    else:
        tier = "LOW"

    # Output pipe-delimited for bash processing
    print(f"{tier}|{name}|{url}|{desc}|{score}|{domains}|{stars}")
PYBLOCK

    case "${tier}" in
        HIGH)
            HIGH_COUNT=$((HIGH_COUNT + 1))
            log "HIGH (${score}/10): ${full_name} — ${description}"

            # Post to Memos with #discovery tag
            memo_content="#discovery #openclaw
## Tool Discovery: ${full_name}

**Score:** ${score}/10 | **Stars:** ${stars}
**Domains:** ${domains}
**URL:** ${url}

${description}

**Action:** Evaluate for integration into TOOLS.md. Created [[${full_name}]] Obsidian note."

            post_memo "${memo_content}"

            # Create Obsidian note
            create_obsidian_note "${full_name}" "${url}" "${description}" "${score}" "${domains}" "${stars}"
            ;;
        MID)
            MID_COUNT=$((MID_COUNT + 1))
            log "MID  (${score}/10): ${full_name}"

            # Post to Memos with #potential-tool tag
            memo_content="#potential-tool #openclaw
## Potential Tool: ${full_name}

**Score:** ${score}/10 | **Stars:** ${stars}
**Domains:** ${domains}
**URL:** ${url}

${description}"

            post_memo "${memo_content}"
            ;;
        LOW)
            LOW_COUNT=$((LOW_COUNT + 1))
            ;;
    esac
done

# Final summary
echo ""
echo "============================================"
echo "  Discovery Scanner Summary"
echo "============================================"
echo "  Repos scanned:     ${REPO_COUNT}"
echo "  High relevance:    ${HIGH_COUNT}  (score >= 7, logged to #discovery)"
echo "  Medium relevance:  ${MID_COUNT}  (score 4-6, logged to #potential-tool)"
echo "  Low relevance:     ${LOW_COUNT}  (score < 4, skipped)"
echo ""
if [ "${DRY_RUN}" = true ]; then
    echo "  MODE: dry-run (no Memos or Obsidian writes)"
fi
echo "============================================"
