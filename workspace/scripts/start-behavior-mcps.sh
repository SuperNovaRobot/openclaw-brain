#!/bin/bash
BRAIN=/mnt/ssd/openclaw-brain
mkdir -p /mnt/ssd/logs

for port in 9500 9501 9502; do
  pid=$(lsof -ti :$port 2>/dev/null)
  [ -n "$pid" ] && kill $pid 2>/dev/null
done

nohup python3 $BRAIN/workspace/behavior-mcps/task-router/server.py --port 9500 > /mnt/ssd/logs/mcp-task-router.log 2>&1 &
echo "task-router PID: $! (port 9500)"

nohup python3 $BRAIN/workspace/behavior-mcps/memory-decision/server.py --port 9501 > /mnt/ssd/logs/mcp-memory-decision.log 2>&1 &
echo "memory-decision PID: $! (port 9501)"

nohup python3 $BRAIN/workspace/behavior-mcps/self-eval/server.py --port 9502 > /mnt/ssd/logs/mcp-self-eval.log 2>&1 &
echo "self-eval PID: $! (port 9502)"

sleep 2
for port in 9500 9501 9502; do
  curl -sf http://localhost:$port/health >/dev/null 2>&1 && echo "[OK] Port $port" || echo "[FAIL] Port $port"
done
