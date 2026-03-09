#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 04_advanced_features.sh — Trash, Quota, Safe Mode, fsck, balancer
# Run inside NameNode: docker exec -it hadoop-namenode bash 04_advanced_features.sh
# ─────────────────────────────────────────────────────────────────────────────

echo "════════════════════════════════════════════"
echo "  HDFS Advanced Features"
echo "════════════════════════════════════════════"

# ── SECTION A: HDFS FSCK (File System Check) ─────────────────────────────────
echo -e "\n=== A. HDFS File System Check (fsck) ==="

echo -e "\n[1] Check overall HDFS health"
hdfs fsck / -summary

echo -e "\n[2] Check a specific path in detail"
hdfs dfs -mkdir -p /user/hadoop/fsck_test
echo "fsck test" > /tmp/fsck.txt
hdfs dfs -put /tmp/fsck.txt /user/hadoop/fsck_test/
hdfs fsck /user/hadoop/fsck_test -files -blocks -locations

# ── SECTION B: QUOTA ────────────────────────────────────────────────────────
echo -e "\n=== B. HDFS Quotas ==="

hdfs dfs -mkdir -p /user/hadoop/quota_test

echo -e "\n[3] Set namespace quota (max number of files/dirs)"
hdfs dfsadmin -setQuota 10 /user/hadoop/quota_test
# Only 10 total names (files+dirs) allowed

echo -e "\n[4] Check quota"
hdfs dfs -count -q -h /user/hadoop/quota_test
# Columns: QUOTA, REMAINING_QUOTA, SPACE_QUOTA, REMAINING_SPACE_QUOTA, ...

echo -e "\n[5] Set space quota (max bytes)"
hdfs dfsadmin -setSpaceQuota 1g /user/hadoop/quota_test
# Max 1 GB of data

echo -e "\n[6] Check space quota"
hdfs dfs -count -q -h /user/hadoop/quota_test

echo -e "\n[7] Remove quota"
hdfs dfsadmin -clrQuota /user/hadoop/quota_test
hdfs dfsadmin -clrSpaceQuota /user/hadoop/quota_test

# ── SECTION C: TRASH ────────────────────────────────────────────────────────
echo -e "\n=== C. HDFS Trash ==="
# When trash is enabled, rm sends files to ~/.Trash instead of deleting
# Configured via fs.trash.interval (minutes)

echo -e "\n[8] Check if trash is configured"
hdfs dfs -ls /user/ 2>/dev/null || true
# After a delete with trash: /user/root/.Trash/Current/<deleted_file>

echo "trash test" > /tmp/trash_file.txt
hdfs dfs -put -f /tmp/trash_file.txt /user/hadoop/quota_test/trash_file.txt

echo -e "\n[9] Delete to trash (default rm behavior if trash.interval > 0)"
hdfs dfs -rm /user/hadoop/quota_test/trash_file.txt
# Check trash:
hdfs dfs -ls /user/root/.Trash/ 2>/dev/null || echo "(Trash may be empty or disabled in this config)"

echo -e "\n[10] Expunge trash (permanently delete)"
hdfs dfs -expunge

# ── SECTION D: SAFE MODE ────────────────────────────────────────────────────
echo -e "\n=== D. Safe Mode ==="
# Safe mode: NameNode is read-only, no block changes allowed
# Entered automatically on startup until min replicas are reported

echo -e "\n[11] Check safe mode status"
hdfs dfsadmin -safemode get

echo -e "\n[12] Enter safe mode manually"
hdfs dfsadmin -safemode enter

echo -e "\n[13] Try to write in safe mode (will fail)"
echo "safe mode test" > /tmp/safe_test.txt
hdfs dfs -put /tmp/safe_test.txt /tmp/safe_test.txt 2>&1 || echo "(Expected: Cannot create file in safe mode)"

echo -e "\n[14] Leave safe mode"
hdfs dfsadmin -safemode leave
hdfs dfsadmin -safemode get

# ── SECTION E: CLUSTER REPORT & ADMIN ────────────────────────────────────────
echo -e "\n=== E. Admin & Cluster Info ==="

echo -e "\n[15] DataNode report"
hdfs dfsadmin -report

echo -e "\n[16] NameNode metrics via JMX"
curl -sf "http://localhost:9870/jmx?qry=Hadoop:service=NameNode,name=NameNodeInfo" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)['beans'][0]
print(f\"  Total Capacity : {int(d.get('Total', 0)) // (1024**3)} GB\")
print(f\"  Used           : {int(d.get('Used', 0)) // (1024**3)} GB\")
print(f\"  Live DataNodes : {d.get('NumLiveDataNodes', 'N/A')}\")
print(f\"  Dead DataNodes : {d.get('NumDeadDataNodes', 'N/A')}\")
" 2>/dev/null || echo "(JMX endpoint not reachable from container)"

# Cleanup
hdfs dfs -rm -r /user/hadoop/quota_test /user/hadoop/fsck_test

echo -e "\n════════════════════════════════════════════"
echo "  Advanced HDFS Features — DONE"
echo "════════════════════════════════════════════"
