#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 03_replication_snapshots.sh — Replication factor + HDFS snapshots
# Run inside NameNode: docker exec -it hadoop-namenode bash 03_replication_snapshots.sh
# ─────────────────────────────────────────────────────────────────────────────

echo "════════════════════════════════════════════"
echo "  HDFS Replication & Snapshots"
echo "════════════════════════════════════════════"

# Setup
echo "important data" > /tmp/data.txt
hdfs dfs -mkdir -p /user/hadoop/replication
hdfs dfs -put -f /tmp/data.txt /user/hadoop/replication/data.txt

# ── SECTION A: REPLICATION ───────────────────────────────────────────────────
echo -e "\n=== A. Replication Factor ==="

echo -e "\n[1] Check current replication factor"
hdfs dfs -stat "%r" /user/hadoop/replication/data.txt   # %r = replication

echo -e "\n[2] Set replication factor = 1 (for small test clusters)"
hdfs dfs -setrep -w 1 /user/hadoop/replication/data.txt
# -w = wait for replication to complete

echo -e "\n[3] Verify new replication"
hdfs dfs -stat "%n: replication=%r, block_size=%o" /user/hadoop/replication/data.txt

echo -e "\n[4] Set replication factor = 2 recursively on a directory"
hdfs dfs -setrep -w -R 2 /user/hadoop/replication/

echo -e "\n[5] Check block locations (which DataNodes hold this file)"
hdfs fsck /user/hadoop/replication/data.txt -files -blocks -locations

# ── SECTION B: SNAPSHOTS ─────────────────────────────────────────────────────
echo -e "\n=== B. HDFS Snapshots ==="
# Snapshots let you preserve a point-in-time copy of a directory
# Use case: before a batch job, before deletes, for disaster recovery

hdfs dfs -mkdir -p /user/hadoop/snapshotable

# Enable snapshots on the directory (admin action)
echo -e "\n[6] Enable snapshots on directory"
hdfs dfsadmin -allowSnapshot /user/hadoop/snapshotable

# Add some data
echo "version 1 data" > /tmp/v1.txt
hdfs dfs -put /tmp/v1.txt /user/hadoop/snapshotable/file.txt

echo -e "\n[7] Create snapshot (named 'snap1')"
hdfs dfs -createSnapshot /user/hadoop/snapshotable snap1

echo -e "\n[8] List snapshots"
hdfs dfs -ls /user/hadoop/snapshotable/.snapshot/

# Modify the file (simulating changes)
echo "version 2 data" > /tmp/v2.txt
hdfs dfs -put -f /tmp/v2.txt /user/hadoop/snapshotable/file.txt
hdfs dfs -put /tmp/v1.txt /user/hadoop/snapshotable/extra_file.txt

echo -e "\n[9] Create another snapshot (named 'snap2')"
hdfs dfs -createSnapshot /user/hadoop/snapshotable snap2

echo -e "\n[10] List snapshots again"
hdfs dfs -ls /user/hadoop/snapshotable/.snapshot/

echo -e "\n[11] Read file from snapshot (old version)"
hdfs dfs -cat /user/hadoop/snapshotable/.snapshot/snap1/file.txt

echo -e "\n[12] Diff between two snapshots"
hdfs snapshotDiff /user/hadoop/snapshotable snap1 snap2
# Output: M=modified, + added, - deleted, R=renamed

echo -e "\n[13] Restore file from snapshot (copy back)"
hdfs dfs -cp /user/hadoop/snapshotable/.snapshot/snap1/file.txt \
             /user/hadoop/snapshotable/file_restored.txt
hdfs dfs -cat /user/hadoop/snapshotable/file_restored.txt

echo -e "\n[14] Rename a snapshot"
hdfs dfs -renameSnapshot /user/hadoop/snapshotable snap1 snapshot_v1

echo -e "\n[15] Delete a snapshot"
hdfs dfs -deleteSnapshot /user/hadoop/snapshotable snapshot_v1
hdfs dfs -ls /user/hadoop/snapshotable/.snapshot/

echo -e "\n[16] Disable snapshots (remove snapshot-ability)"
hdfs dfs -deleteSnapshot /user/hadoop/snapshotable snap2
hdfs dfsadmin -disallowSnapshot /user/hadoop/snapshotable

# Cleanup
hdfs dfs -rm -r /user/hadoop/snapshotable /user/hadoop/replication

echo -e "\n════════════════════════════════════════════"
echo "  Replication & Snapshots — DONE"
echo "════════════════════════════════════════════"
