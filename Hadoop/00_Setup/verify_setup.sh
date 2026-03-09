#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# verify_setup.sh — Verify the Hadoop cluster is running correctly
# Run from: Hadoop/00_Setup/
# Usage:    bash verify_setup.sh
# ─────────────────────────────────────────────────────────────────────────────

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

echo ""
echo "═══════════════════════════════════════════════════"
echo "       Hadoop Cluster Verification                 "
echo "═══════════════════════════════════════════════════"
echo ""

# ── 1. Check Docker containers ───────────────────────────────────────────────
info "Checking Docker containers..."
CONTAINERS=("hadoop-namenode" "hadoop-datanode1" "hadoop-datanode2" "hadoop-resourcemgr" "hadoop-nodemanager")
for c in "${CONTAINERS[@]}"; do
  if docker ps --format '{{.Names}}' | grep -q "^$c$"; then
    pass "Container '$c' is running"
  else
    fail "Container '$c' is NOT running — try: docker compose up -d"
  fi
done

echo ""

# ── 2. Check Web UIs ─────────────────────────────────────────────────────────
info "Checking Web UIs..."
check_url() {
  local name=$1; local url=$2
  if curl -sf "$url" > /dev/null 2>&1; then
    pass "$name is reachable at $url"
  else
    fail "$name NOT reachable at $url"
  fi
}
check_url "HDFS NameNode"        "http://localhost:9870"
check_url "YARN ResourceManager" "http://localhost:8088/ws/v1/cluster/info"

echo ""

# ── 3. HDFS smoke test ───────────────────────────────────────────────────────
info "Running HDFS smoke tests..."
docker exec hadoop-namenode bash -c "
  echo 'Hello Hadoop World' > /tmp/test.txt
  hdfs dfs -mkdir -p /smoke-test
  hdfs dfs -put -f /tmp/test.txt /smoke-test/test.txt
  hdfs dfs -ls /smoke-test/
  OUTPUT=\$(hdfs dfs -cat /smoke-test/test.txt)
  if [ \"\$OUTPUT\" = 'Hello Hadoop World' ]; then
    echo 'HDFS_OK'
  else
    echo 'HDFS_FAIL'
  fi
  hdfs dfs -rm -r /smoke-test
" 2>/dev/null | grep -q "HDFS_OK" && pass "HDFS read/write works" || fail "HDFS read/write FAILED"

echo ""

# ── 4. YARN smoke test ───────────────────────────────────────────────────────
info "Running YARN smoke test (Pi calculation)..."
docker exec hadoop-namenode bash -c "
  hadoop jar /opt/hadoop-3.2.1/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.2.1.jar \
    pi 2 10 > /tmp/yarn_test.log 2>&1
  if grep -q 'Estimated value of Pi' /tmp/yarn_test.log; then
    echo 'YARN_OK'
  else
    echo 'YARN_FAIL'
  fi
" 2>/dev/null | grep -q "YARN_OK" && pass "YARN MapReduce job runs successfully" || fail "YARN MapReduce FAILED (cluster may still be starting)"

echo ""

# ── 5. HDFS DataNode count ───────────────────────────────────────────────────
info "Checking DataNode count..."
LIVE_NODES=$(curl -sf "http://localhost:9870/jmx?qry=Hadoop:service=NameNode,name=FSNamesystemState" 2>/dev/null | python3 -c "import json,sys; data=json.load(sys.stdin); [print(b['value']) for b in data['beans'][0].get('beans',[]) if False] or print(json.load(open('/dev/stdin')) if False else 0)" 2>/dev/null || echo "unknown")
LIVE_NODES=$(curl -sf "http://localhost:9870/jmx?qry=Hadoop:service=NameNode,name=NameNodeInfo" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['beans'][0].get('NumLiveDataNodes','?'))" 2>/dev/null || echo "unknown")
info "Live DataNodes: $LIVE_NODES (expected: 2)"

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Verification complete. Open the web UIs to explore:"
echo "  • HDFS:  http://localhost:9870"
echo "  • YARN:  http://localhost:8088"
echo "═══════════════════════════════════════════════════"
echo ""
