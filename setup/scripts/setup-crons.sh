#!/bin/bash
# Register HEARTBEAT cron jobs in OpenClaw
# Requires: gateway running, openclaw CLI available
# Usage: bash setup/scripts/setup-crons.sh

set -euo pipefail

echo "Registering HEARTBEAT cron jobs..."

openclaw cron add --name hourly-check --cron "0 * * * *" --session isolated --no-deliver --best-effort-deliver --message "Run hourly HEARTBEAT: check TODO memos, process pending messages"

openclaw cron add --name self-eval-4h --cron "0 */4 * * *" --session isolated --no-deliver --best-effort-deliver --message "Run 4-hourly self-evaluation: analyze last 5 tasks, check score trends"

openclaw cron add --name daily-consolidate --cron "0 2 * * *" --session isolated --no-deliver --best-effort-deliver --message "Daily: consolidate memos to Obsidian daily note, sync vault to RagFlow, check disk usage"

openclaw cron add --name weekly-scan --cron "0 3 * * 0" --session isolated --no-deliver --best-effort-deliver --message "Weekly: run discovery scanner for GitHub trending, check instinct evolution, review revenue and hardware needs"

openclaw cron add --name monthly-maintenance --cron "0 4 1 * *" --session isolated --no-deliver --best-effort-deliver --message "Monthly: prune old memos, run backup verification, update TOOLS.md accuracy"

echo "All 5 HEARTBEAT cron jobs registered."
openclaw cron list
