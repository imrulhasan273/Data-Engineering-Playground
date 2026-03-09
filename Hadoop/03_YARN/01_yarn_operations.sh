#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 01_yarn_operations.sh — YARN resource management commands
# Run inside NameNode: docker exec -it hadoop-namenode bash 01_yarn_operations.sh
# ─────────────────────────────────────────────────────────────────────────────

echo "════════════════════════════════════════════"
echo "  YARN Operations"
echo "════════════════════════════════════════════"

# ── 1. Cluster Status ────────────────────────────────────────────────────────
echo -e "\n[1] YARN cluster status"
yarn cluster --status

echo -e "\n[2] ResourceManager web URL"
echo "  → http://localhost:8088"

# ── 2. Node Management ───────────────────────────────────────────────────────
echo -e "\n[3] List all NodeManagers"
yarn node -list -all

echo -e "\n[4] Node details (replace <node-id> from output above)"
# yarn node -status <node-id>
yarn node -list 2>/dev/null | awk 'NR==2{print $1}' | xargs -I{} yarn node -status {}

# ── 3. Queue Management ──────────────────────────────────────────────────────
echo -e "\n[5] List all queues"
yarn queue -status default

echo -e "\n[6] Queue details"
yarn schedulerconf 2>/dev/null || echo "(schedulerconf requires RM REST API)"

# ── 4. Submit a Test Job ──────────────────────────────────────────────────────
echo -e "\n[7] Submit a MapReduce Pi job"
HADOOP_JAR=$(find /opt -name "hadoop-mapreduce-examples*.jar" 2>/dev/null | head -1)
if [ -n "$HADOOP_JAR" ]; then
  hadoop jar "$HADOOP_JAR" pi 4 100 &
  JOB_PID=$!
  sleep 3

  echo -e "\n[8] List running applications"
  yarn application -list

  echo -e "\n[9] List all applications (including finished)"
  yarn application -list -appStates ALL | head -10

  wait $JOB_PID
else
  echo "(MapReduce examples jar not found)"
fi

# ── 5. Application Logs ──────────────────────────────────────────────────────
echo -e "\n[10] Get logs of the most recent application"
LATEST_APP=$(yarn application -list -appStates FINISHED 2>/dev/null | \
  grep -oP 'application_\d+_\d+' | tail -1)

if [ -n "$LATEST_APP" ]; then
  echo "  Application: $LATEST_APP"
  yarn logs -applicationId "$LATEST_APP" 2>/dev/null | head -50
else
  echo "  (No finished apps yet)"
fi

# ── 6. Capacity Scheduler Config ─────────────────────────────────────────────
echo -e "\n[11] Scheduler type"
yarn rmadmin -getServiceState rm 2>/dev/null || true

# ── 7. Resource Usage ────────────────────────────────────────────────────────
echo -e "\n[12] ResourceManager REST API — cluster metrics"
curl -sf "http://resourcemanager:8088/ws/v1/cluster/metrics" 2>/dev/null \
  | python3 -c "
import json, sys
m = json.load(sys.stdin)['clusterMetrics']
print(f\"  Apps Running    : {m['appsRunning']}\")
print(f\"  Apps Completed  : {m['appsCompleted']}\")
print(f\"  Total Memory MB : {m['totalMB']}\")
print(f\"  Allocated MB    : {m['allocatedMB']}\")
print(f\"  Available MB    : {m['availableMB']}\")
print(f\"  Total VCores    : {m['totalVirtualCores']}\")
" 2>/dev/null || echo "  (REST API not reachable — use http://localhost:8088)"

# ── 8. Kill an Application ───────────────────────────────────────────────────
echo -e "\n[13] Kill an application (example)"
echo "  Usage: yarn application -kill application_<timestamp>_<id>"
echo "  Example: yarn application -kill \$(yarn application -list 2>/dev/null | grep RUNNING | awk '{print \$1}' | head -1)"

# ── 9. YARN Timeline Server ──────────────────────────────────────────────────
echo -e "\n[14] YARN application history (Timeline Server)"
yarn application -list -appStates FINISHED 2>/dev/null | head -5

echo -e "\n════════════════════════════════════════════"
echo "  YARN Operations — DONE"
echo "  Web UI: http://localhost:8088"
echo "════════════════════════════════════════════"
