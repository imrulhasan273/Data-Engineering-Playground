#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 01_basic_operations.sh — HDFS fundamental commands
# Run inside NameNode: docker exec -it hadoop-namenode bash 01_basic_operations.sh
# ─────────────────────────────────────────────────────────────────────────────

echo "════════════════════════════════════════════"
echo "  HDFS Basic Operations"
echo "════════════════════════════════════════════"

# ── Setup: create sample files ───────────────────────────────────────────────
echo "Hello Hadoop" > /tmp/hello.txt
echo -e "line1\nline2\nline3" > /tmp/multiline.txt

# ── 1. Directory Operations ──────────────────────────────────────────────────
echo -e "\n[1] Create directories"
hdfs dfs -mkdir -p /user/hadoop/data
hdfs dfs -mkdir -p /user/hadoop/output
hdfs dfs -ls /user/hadoop/              # list contents

echo -e "\n[2] List root"
hdfs dfs -ls /                          # top-level

# ── 2. Upload (put) Files ────────────────────────────────────────────────────
echo -e "\n[3] Upload files to HDFS"
hdfs dfs -put /tmp/hello.txt /user/hadoop/data/hello.txt
hdfs dfs -put /tmp/multiline.txt /user/hadoop/data/multiline.txt

# Alternative: -copyFromLocal is identical to -put
hdfs dfs -copyFromLocal /tmp/hello.txt /user/hadoop/data/hello_copy.txt

echo -e "\n[4] List uploaded files"
hdfs dfs -ls /user/hadoop/data/

# ── 3. Read Files ────────────────────────────────────────────────────────────
echo -e "\n[5] Cat file contents"
hdfs dfs -cat /user/hadoop/data/hello.txt

echo -e "\n[6] Head (first 1KB)"
hdfs dfs -head /user/hadoop/data/multiline.txt

echo -e "\n[7] Tail (last 1KB)"
hdfs dfs -tail /user/hadoop/data/multiline.txt

# ── 4. Download (get) Files ──────────────────────────────────────────────────
echo -e "\n[8] Download from HDFS"
hdfs dfs -get /user/hadoop/data/hello.txt /tmp/hello_downloaded.txt
cat /tmp/hello_downloaded.txt           # verify

# Alternative: -copyToLocal
hdfs dfs -copyToLocal /user/hadoop/data/multiline.txt /tmp/multiline_downloaded.txt

# ── 5. Copy & Move within HDFS ───────────────────────────────────────────────
echo -e "\n[9] Copy within HDFS"
hdfs dfs -cp /user/hadoop/data/hello.txt /user/hadoop/data/hello_cp.txt
hdfs dfs -ls /user/hadoop/data/

echo -e "\n[10] Move (rename) within HDFS"
hdfs dfs -mv /user/hadoop/data/hello_copy.txt /user/hadoop/data/hello_moved.txt
hdfs dfs -ls /user/hadoop/data/

# ── 6. File Information ──────────────────────────────────────────────────────
echo -e "\n[11] File size (-du = disk usage)"
hdfs dfs -du -h /user/hadoop/data/     # human-readable sizes

echo -e "\n[12] Count files and dirs"
hdfs dfs -count /user/hadoop/          # dirs, files, bytes

echo -e "\n[13] File statistics (-stat)"
hdfs dfs -stat "%n %b %r %o" /user/hadoop/data/hello.txt
# %n=name, %b=bytes, %r=replication, %o=block size

# ── 7. Delete ────────────────────────────────────────────────────────────────
echo -e "\n[14] Delete a file"
hdfs dfs -rm /user/hadoop/data/hello_cp.txt

echo -e "\n[15] Delete a directory recursively"
hdfs dfs -rm -r /user/hadoop/output/

echo -e "\n[16] Skip trash (permanent delete)"
hdfs dfs -rm -skipTrash /user/hadoop/data/hello_moved.txt

echo -e "\n[17] Final directory listing"
hdfs dfs -ls /user/hadoop/data/

echo -e "\n════════════════════════════════════════════"
echo "  HDFS Basic Operations — DONE"
echo "════════════════════════════════════════════"
