#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 01_zk_operations.sh — ZooKeeper CLI (zkCli) operations
# Run inside HBase container (ZK embedded): docker exec -it hadoop-hbase bash /tmp/01_zk_operations.sh
# Or: docker exec -it hadoop-hbase zkCli.sh -server localhost:2181
# ─────────────────────────────────────────────────────────────────────────────

ZK_HOST="${ZK_HOST:-localhost}"
ZK_PORT="${ZK_PORT:-2181}"
ZK_CONNECT="${ZK_HOST}:${ZK_PORT}"

echo "════════════════════════════════════════════"
echo "  Apache ZooKeeper CLI Operations"
echo "  Connecting to: ${ZK_CONNECT}"
echo "════════════════════════════════════════════"

# Helper: run ZK commands non-interactively
zk() {
    if command -v zkCli.sh &>/dev/null; then
        echo "$1" | zkCli.sh -server "${ZK_CONNECT}" 2>/dev/null | grep -v "^WATCHER\|^WatchedEvent\|^JMX\|^Using\|^Connecting\|^Welcome\|^[0-9]"
    else
        echo "  [zkCli.sh not found — showing commands for manual execution]"
        echo "  ZK CMD: $1"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 1: Basic znode operations
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[1] List root znodes"
zk "ls /"

echo -e "\n[2] Create persistent znode"
zk "create /demo 'demo-data'"
zk "create /demo/config 'config-value-1'"
zk "create /demo/workers ''"

echo -e "\n[3] Get znode data"
zk "get /demo"
zk "get /demo/config"

echo -e "\n[4] Set (update) znode data"
zk "set /demo/config 'updated-config-v2'"
zk "get /demo/config"

echo -e "\n[5] List children of a znode"
zk "ls /demo"

echo -e "\n[6] Get znode stat (metadata)"
zk "stat /demo/config"
# Stat fields:
#   cZxid   — transaction ID when created
#   ctime   — creation timestamp
#   mZxid   — transaction ID of last modification
#   mtime   — last modified timestamp
#   pZxid   — last child modification ID
#   cversion — child version
#   dataVersion — data modification count
#   aclVersion — ACL modification count
#   numChildren — number of children

echo -e "\n[7] Delete znode"
zk "delete /demo/config"        # delete single znode
zk "ls /demo"                    # verify

echo -e "\n[8] Delete znode recursively (all children)"
zk "deleteall /demo"             # removes /demo and all children
zk "ls /"                        # verify removed

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 2: Znode types
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[9] Znode types"
echo ""
echo "  1. PERSISTENT       — exists until explicitly deleted"
echo "     create /mynode 'data'"
echo ""
echo "  2. PERSISTENT_SEQUENTIAL — ZK appends monotonic sequence number"
echo "     create -s /locks/lock- 'client-1'"
echo "     → creates /locks/lock-0000000001"
echo "     create -s /locks/lock- 'client-2'"
echo "     → creates /locks/lock-0000000002"
echo ""
echo "  3. EPHEMERAL        — deleted when client session ends (disconnects)"
echo "     create -e /workers/worker-1 'alive'"
echo "     → auto-deleted when client disconnects"
echo ""
echo "  4. EPHEMERAL_SEQUENTIAL — ephemeral + sequence number"
echo "     create -e -s /election/candidate- 'node1'"
echo "     → /election/candidate-0000000001 (auto-deleted on disconnect)"

# Demonstrate each type
echo -e "\n  Demonstrating znode types:"
zk "create /demo ''"
zk "create -s /demo/seq- 'first'"
zk "create -s /demo/seq- 'second'"
zk "create -s /demo/seq- 'third'"
zk "ls /demo"
zk "create -e /demo/ephemeral 'will-disappear-on-disconnect'"
zk "ls /demo"
zk "deleteall /demo"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 3: Watches
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[10] Watches (event notifications)"
echo ""
echo "  Watches are one-time triggers fired when a znode changes."
echo ""
echo "  Set a watch on data change:"
echo "    get -w /mynode              — fires on data change"
echo ""
echo "  Set a watch on children change:"
echo "    ls -w /mynode               — fires when children added/removed"
echo ""
echo "  Set a watch on existence (even if node doesn't exist):"
echo "    exists -w /mynode           — fires on create or delete"
echo ""
echo "  Watch events:"
echo "    NodeCreated      — znode was created"
echo "    NodeDeleted      — znode was deleted"
echo "    NodeDataChanged  — znode data was set/updated"
echo "    NodeChildrenChanged — a child was added or removed"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 4: Distributed patterns (conceptual demonstrations)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[11] Distributed Locking pattern"
echo ""
cat << 'LOCK_PATTERN'
  Algorithm (ZooKeeper Distributed Lock):
  1. Create /locks if not exists
  2. Client creates EPHEMERAL_SEQUENTIAL: /locks/lock-<seq>
  3. Get all children of /locks, sorted by sequence number
  4. If this client has the LOWEST sequence number → it holds the lock
  5. Else → watch the node with the NEXT LOWER sequence (not lowest!)
  6. When watch fires (node deleted) → re-check if now lowest → acquire
  7. When done → delete own ephemeral node → releases lock

  This prevents "herd effect" (all clients waking when lock released).

  CLI simulation:
    create -e -s /locks/lock- 'client-A'  → /locks/lock-0000000001
    create -e -s /locks/lock- 'client-B'  → /locks/lock-0000000002
    ls /locks                              → [lock-0000000001, lock-0000000002]
    # client-A holds the lock (lowest seq), client-B watches lock-0000000001
    delete /locks/lock-0000000001          → client-B's watch fires → it now holds lock
LOCK_PATTERN

echo -e "\n[12] Leader Election pattern"
echo ""
cat << 'LEADER_PATTERN'
  Algorithm (same as locking):
  1. All candidates create EPHEMERAL_SEQUENTIAL: /election/candidate-<seq>
  2. Candidate with lowest sequence = current leader
  3. Each non-leader watches the node just before it in sequence
  4. When leader disappears (session expires) → next in line detects → becomes leader
  5. Ephemeral nodes ensure dead nodes are automatically removed

  Used by: HBase HMaster election, YARN ResourceManager HA, Kafka broker election
LEADER_PATTERN

echo -e "\n[13] Service Discovery / Configuration Management"
echo ""
cat << 'DISCOVERY'
  Pattern: Publish connection info in ZooKeeper

  Service registration (when service starts):
    create -e /services/api-server/192.168.1.10:8080 '{"version":"1.2","healthy":true}'

  Service lookup (by client):
    ls /services/api-server
    get /services/api-server/192.168.1.10:8080

  Watch for new/removed instances:
    ls -w /services/api-server  → fires when instances added/removed

  Configuration distribution:
    set /config/db-host "db-server-01.internal"
    set /config/db-port "5432"
    # All services watch these znodes and reload on change
DISCOVERY

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 5: ZooKeeper in the Hadoop ecosystem
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[14] ZooKeeper in Hadoop Ecosystem"
echo ""
echo "  Component          | How ZooKeeper is Used"
echo "  -------------------|----------------------------------------------------"
echo "  HDFS HA            | Active/Standby NameNode election + fencing"
echo "  YARN HA            | Active/Standby ResourceManager election"
echo "  HBase              | HMaster election, RegionServer registration, META table location"
echo "  Kafka (legacy)     | Broker registration, topic metadata, controller election"
echo "  Hive               | HiveServer2 instance registry (for HA)"
echo "  Apache Storm       | Nimbus leader election, supervisor registration"
echo ""
echo "  ZK paths created by HBase:"
zk "ls /hbase" 2>/dev/null || echo "  /hbase, /hbase/master, /hbase/rs (region servers), /hbase/table"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 6: ZooKeeper cluster health
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[15] ZooKeeper health and diagnostics"
echo ""
echo "  # Four-letter word commands (send via nc or telnet):"
echo "  echo 'ruok' | nc ${ZK_HOST} ${ZK_PORT}    → 'imok' if healthy"
echo "  echo 'stat' | nc ${ZK_HOST} ${ZK_PORT}    → connections, latency, mode"
echo "  echo 'srvr' | nc ${ZK_HOST} ${ZK_PORT}    → server info"
echo "  echo 'mntr' | nc ${ZK_HOST} ${ZK_PORT}    → detailed metrics"
echo "  echo 'dump' | nc ${ZK_HOST} ${ZK_PORT}    → outstanding sessions/ephemeral nodes"
echo "  echo 'conf' | nc ${ZK_HOST} ${ZK_PORT}    → configuration"
echo ""

# Test health if nc is available
if command -v nc &>/dev/null; then
    echo "  Health check: $(echo 'ruok' | nc -w 1 ${ZK_HOST} ${ZK_PORT} 2>/dev/null || echo 'not reachable')"
    echo ""
    echo "  Server stats:"
    echo 'stat' | nc -w 2 ${ZK_HOST} ${ZK_PORT} 2>/dev/null || echo "  [ZooKeeper not reachable at ${ZK_CONNECT}]"
fi

echo -e "\n════════════════════════════════════════════"
echo "  ZooKeeper CLI Operations — DONE"
echo "════════════════════════════════════════════"
