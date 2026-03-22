#!/bin/bash
FREQ="${1:-hourly}"
BRAIN="/mnt/ssd/openclaw-brain"
LOG="/mnt/ssd/logs/heartbeat.log"
MEMOS="http://nova-rig:5230"

log() { echo "$(date +%Y-%m-%dT%H:%M:%S) [$FREQ] $1" >> "$LOG"; }

case "$FREQ" in
  hourly)
    log "Hourly check started"
    log "Hourly done"
    ;;
  4hourly)
    log "4-hourly: running metric analyzer"
    python3 "$BRAIN/workspace/scripts/metric-analyzer.py" --days 1 >> "$LOG" 2>&1 || true
    log "4-hourly done"
    ;;
  daily)
    log "Daily: syncing obsidian to ragflow"
    bash "$BRAIN/setup/scripts/sync-obsidian-to-ragflow.sh" >> "$LOG" 2>&1 || true
    USAGE=$(df /mnt/ssd --output=pcent 2>/dev/null | tail -1 | tr -d ' %')
    [ "$USAGE" -gt 80 ] && log "WARN: Disk at ${USAGE}%"
    log "Daily done"
    ;;
  weekly)
    log "Weekly: running discovery scanner"
    bash "$BRAIN/workspace/scripts/discovery-scanner.sh" --dry-run >> "$LOG" 2>&1 || true
    log "Weekly done"
    ;;
  monthly)
    log "Monthly maintenance"
    log "Monthly done"
    ;;
esac
