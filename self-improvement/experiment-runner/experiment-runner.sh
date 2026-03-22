#!/usr/bin/env bash
# experiment-runner.sh — Autoresearch experiment runner for OpenClaw Brain
#
# Usage:
#   ./experiment-runner.sh <name> <target-file> <description>
#   ./experiment-runner.sh --measure <name>
#
# Creates improvement branches, records baselines, and measures outcomes.

set -euo pipefail

MEMOS_API="http://nova-rig:5230"
REPO_DIR="/mnt/ssd/openclaw-brain"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage:"
    echo "  $0 <name> <target-file> <description>    Start an experiment"
    echo "  $0 --measure <name>                       Measure and decide on experiment"
    echo ""
    echo "Arguments:"
    echo "  name          Experiment name (alphanumeric + hyphens)"
    echo "  target-file   File to improve (relative to repo root)"
    echo "  description   What the experiment aims to improve"
    echo ""
    echo "Flags:"
    echo "  --measure     Compare post-experiment scores to baseline"
    exit 1
}

get_baseline_score() {
    # Fetch last 5 self-eval memos and compute average score
    local response
    local api_url="${MEMOS_API}"
    response=$(python3 - "$api_url" <<'PYBLOCK'
import urllib.request, json, sys
api_url = sys.argv[1]
url = f'{api_url}/api/v1/memos?filter=tag%3D%3D%27self-eval%27&pageSize=5'
try:
    with urllib.request.urlopen(url, timeout=10) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        memos = data.get('memos', [])
        scores = []
        for m in memos:
            content = m.get('content', '')
            try:
                marker = '```json\n'
                js = content.index(marker) + len(marker)
                je = content.index('\n```', js)
                d = json.loads(content[js:je])
                s = d.get('quality_score')
                if s is not None:
                    scores.append(s)
            except (ValueError, json.JSONDecodeError):
                pass
        if scores:
            print(f'{sum(scores)/len(scores):.2f}')
        else:
            print('0.00')
except Exception as e:
    print('0.00', file=sys.stderr)
    print('0.00')
PYBLOCK
    )
    echo "$response"
}

log_experiment() {
    local content="$1"
    local api_url="${MEMOS_API}"
    python3 - "$api_url" "$content" <<'PYBLOCK'
import urllib.request, json, sys
api_url = sys.argv[1]
content = sys.argv[2]
payload = json.dumps({
    'content': content,
    'visibility': 'PRIVATE'
}).encode('utf-8')
req = urllib.request.Request(
    f'{api_url}/api/v1/memos',
    data=payload,
    headers={'Content-Type': 'application/json'},
    method='POST'
)
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        print('Experiment logged to Memos')
except Exception as e:
    print(f'WARNING: Could not log to Memos: {e}')
PYBLOCK
}

start_experiment() {
    local name="$1"
    local target="$2"
    local description="$3"
    local date_prefix
    date_prefix=$(date +%Y-%m-%d)
    local branch="improvement/${date_prefix}-${name}"

    cd "$REPO_DIR"

    # Get baseline
    echo "Calculating baseline score from last 5 evals..."
    local baseline
    baseline=$(get_baseline_score)
    echo "Baseline average score: ${baseline}"

    # Create branch
    echo "Creating branch: ${branch}"
    git checkout -b "$branch"

    # Store experiment metadata
    local meta_file="/tmp/openclaw-experiment-${name}.json"
    local started
    started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    python3 - "$name" "$branch" "$target" "$description" "$baseline" "$started" "$meta_file" <<'PYBLOCK'
import json, sys
name, branch, target, description, baseline, started, meta_file = sys.argv[1:8]
meta = {
    'name': name,
    'branch': branch,
    'target_file': target,
    'description': description,
    'baseline_score': float(baseline),
    'started': started
}
with open(meta_file, 'w') as f:
    json.dump(meta, f, indent=2)
print(json.dumps(meta, indent=2))
PYBLOCK

    echo ""
    echo "=== Experiment '${name}' Started ==="
    echo "Branch:  ${branch}"
    echo "Target:  ${target}"
    echo "Baseline: ${baseline}"
    echo ""
    echo "Now edit '${target}' with your improvement."
    echo "When done, run: $0 --measure ${name}"

    # Log start to Memos
    log_experiment "#experiment #started #openclaw
## Experiment: ${name}

**Target:** ${target}
**Description:** ${description}
**Baseline Score:** ${baseline}
**Branch:** ${branch}"
}

measure_experiment() {
    local name="$1"
    local meta_file="/tmp/openclaw-experiment-${name}.json"

    if [ ! -f "$meta_file" ]; then
        echo "ERROR: No experiment metadata found for '${name}'."
        echo "Start an experiment first with: $0 <name> <target-file> <description>"
        exit 1
    fi

    cd "$REPO_DIR"

    # Read metadata
    local baseline branch target description
    baseline=$(python3 -c "import json; d=json.load(open('${meta_file}')); print(d['baseline_score'])")
    branch=$(python3 -c "import json; d=json.load(open('${meta_file}')); print(d['branch'])")
    target=$(python3 -c "import json; d=json.load(open('${meta_file}')); print(d['target_file'])")
    description=$(python3 -c "import json; d=json.load(open('${meta_file}')); print(d['description'])")

    # Get current score
    echo "Calculating post-experiment score..."
    local current
    current=$(get_baseline_score)
    echo "Post-experiment average score: ${current}"
    echo "Baseline average score: ${baseline}"

    # Compare
    local improved
    improved=$(python3 -c "print('yes' if float('${current}') > float('${baseline}') else 'no')")

    if [ "$improved" = "yes" ]; then
        echo ""
        echo "=== IMPROVEMENT DETECTED ==="
        echo "Score improved from ${baseline} to ${current}"
        echo "Merging ${branch} into main branch..."

        local main_branch
        main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
        git checkout "$main_branch"
        git merge "$branch" --no-edit
        echo "Merged successfully."

        log_experiment "#experiment #success #openclaw
## Experiment Result: ${name} — SUCCESS

**Target:** ${target}
**Description:** ${description}
**Baseline:** ${baseline} -> **New:** ${current}
**Branch:** ${branch} (merged)"

    else
        echo ""
        echo "=== NO IMPROVEMENT ==="
        echo "Score did not improve (${baseline} -> ${current})"
        echo "Reverting to main branch..."

        local main_branch
        main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
        git checkout "$main_branch"
        git branch -D "$branch" 2>/dev/null || true
        echo "Branch deleted."

        log_experiment "#experiment #reverted #openclaw
## Experiment Result: ${name} — REVERTED

**Target:** ${target}
**Description:** ${description}
**Baseline:** ${baseline} -> **Post:** ${current} (no improvement)
**Branch:** ${branch} (deleted)"
    fi

    # Clean up metadata
    rm -f "$meta_file"
}

# Main
if [ $# -lt 1 ]; then
    usage
fi

if [ "$1" = "--measure" ]; then
    if [ $# -lt 2 ]; then
        echo "ERROR: --measure requires experiment name"
        usage
    fi
    measure_experiment "$2"
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    usage
else
    if [ $# -lt 3 ]; then
        echo "ERROR: Starting an experiment requires <name> <target-file> <description>"
        usage
    fi
    start_experiment "$1" "$2" "$3"
fi
