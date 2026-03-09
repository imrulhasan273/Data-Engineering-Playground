#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 01_erasure_coding.sh — HDFS Erasure Coding (Hadoop 3.x)
#
# Erasure Coding (EC) stores data more efficiently than 3x replication:
#   3x replication: 3x storage overhead, 2/3 nodes can fail
#   RS-6-3-1024k:   1.5x overhead, 3 nodes can fail
#
# Run inside NameNode: docker exec -it hadoop-namenode bash 01_erasure_coding.sh
# NOTE: Requires at least 9 DataNodes for RS(6,3). Use RS(3,2) for small clusters.
# ─────────────────────────────────────────────────────────────────────────────

echo "════════════════════════════════════════════"
echo "  HDFS Erasure Coding (Hadoop 3.x)"
echo "════════════════════════════════════════════"

# ── 1. List available EC policies ────────────────────────────────────────────
echo -e "\n[1] Available Erasure Coding policies"
hdfs ec -listPolicies
# Policies:
#   RS-6-3-1024k  : 6 data + 3 parity, 1 MB cell — needs 9+ nodes
#   RS-3-2-1024k  : 3 data + 2 parity, 1 MB cell — needs 5+ nodes
#   RS-10-4-1024k : 10 data + 4 parity           — needs 14+ nodes
#   RS-LEGACY-6-3 : legacy RS implementation
#   XOR-2-1-1024k : 2 data + 1 parity (like RAID5) — needs 3+ nodes

# ── 2. Enable EC policy on a directory ───────────────────────────────────────
echo -e "\n[2] Create EC directories"
hdfs dfs -mkdir -p /ec/data
hdfs dfs -mkdir -p /ec/xor_data

echo -e "\n[3] Enable RS-3-2 policy (works with 2 DataNodes for testing)"
# In production with 2 DataNodes, we use XOR-2-1 for demonstration
hdfs ec -enablePolicy -policy XOR-2-1-1024k
hdfs ec -setPolicy -path /ec/data -policy XOR-2-1-1024k

echo -e "\n[4] Verify EC policy is set"
hdfs ec -getPolicy -path /ec/data

# ── 3. Write a file to EC directory ─────────────────────────────────────────
echo -e "\n[5] Write a large file to EC directory"
# Create a 5MB test file
dd if=/dev/urandom of=/tmp/ec_test_5mb.bin bs=1M count=5 2>/dev/null
hdfs dfs -put /tmp/ec_test_5mb.bin /ec/data/test_5mb.bin

# Compare with replicated file
hdfs dfs -mkdir -p /ec/replicated
hdfs dfs -setrep 3 /ec/replicated     # use 3x replication
hdfs dfs -put /tmp/ec_test_5mb.bin /ec/replicated/test_5mb.bin

# ── 4. Check storage statistics ──────────────────────────────────────────────
echo -e "\n[6] Storage comparison"
echo "  EC directory (XOR-2-1):"
hdfs dfs -du -h /ec/data/
echo ""
echo "  Replicated directory (3x):"
hdfs dfs -du -h /ec/replicated/

echo -e "\n[7] EC file block info"
hdfs fsck /ec/data/test_5mb.bin -files -blocks -locations

# ── 5. Read back (transparent to applications) ────────────────────────────────
echo -e "\n[8] Read EC file (transparent — same as regular file)"
hdfs dfs -cat /ec/data/test_5mb.bin > /tmp/ec_recovered.bin
diff /tmp/ec_test_5mb.bin /tmp/ec_recovered.bin \
  && echo "  Data integrity: PASS" \
  || echo "  Data integrity: FAIL"

# ── 6. Remove EC policy ───────────────────────────────────────────────────────
echo -e "\n[9] Remove EC policy (revert to replication)"
hdfs ec -unsetPolicy -path /ec/data

echo -e "\n[10] After removing policy:"
hdfs ec -getPolicy -path /ec/data

# Cleanup
hdfs dfs -rm -r /ec/

echo -e "\n════════════════════════════════════════════"
echo "  Erasure Coding — DONE"
echo ""
echo "  Summary:"
echo "  • RS-6-3: 50% storage overhead vs 200% for 3x replication"
echo "  • Good for cold/archival data (slightly higher read latency)"
echo "  • Not ideal for small files (<< block size)"
echo "════════════════════════════════════════════"
