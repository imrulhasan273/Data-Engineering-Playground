#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 02_file_permissions.sh — HDFS permissions, ACLs
# Run inside NameNode: docker exec -it hadoop-namenode bash 02_file_permissions.sh
# ─────────────────────────────────────────────────────────────────────────────

echo "════════════════════════════════════════════"
echo "  HDFS File Permissions & ACLs"
echo "════════════════════════════════════════════"

# Setup
echo "test data" > /tmp/perm_test.txt
hdfs dfs -mkdir -p /user/hadoop/perms
hdfs dfs -put -f /tmp/perm_test.txt /user/hadoop/perms/test.txt

# ── 1. View Permissions ──────────────────────────────────────────────────────
echo -e "\n[1] List with permissions (-ls shows perms)"
hdfs dfs -ls /user/hadoop/perms/
# Output format: permissions  replication  owner  group  size  date  path

# ── 2. chmod ─────────────────────────────────────────────────────────────────
echo -e "\n[2] chmod — octal mode"
hdfs dfs -chmod 755 /user/hadoop/perms/test.txt
hdfs dfs -ls /user/hadoop/perms/

echo -e "\n[3] chmod — symbolic mode"
hdfs dfs -chmod o-w /user/hadoop/perms/test.txt   # remove write from others
hdfs dfs -ls /user/hadoop/perms/

echo -e "\n[4] chmod recursive"
hdfs dfs -chmod -R 750 /user/hadoop/perms/
hdfs dfs -ls /user/hadoop/perms/

# ── 3. chown ─────────────────────────────────────────────────────────────────
echo -e "\n[5] chown — change owner"
hdfs dfs -chown hadoop /user/hadoop/perms/test.txt
hdfs dfs -ls /user/hadoop/perms/

echo -e "\n[6] chown — change owner:group"
hdfs dfs -chown hadoop:supergroup /user/hadoop/perms/test.txt
hdfs dfs -ls /user/hadoop/perms/

# ── 4. chgrp ─────────────────────────────────────────────────────────────────
echo -e "\n[7] chgrp — change group"
hdfs dfs -chgrp supergroup /user/hadoop/perms/test.txt
hdfs dfs -ls /user/hadoop/perms/

# ── 5. ACLs (Access Control Lists) ───────────────────────────────────────────
# ACLs must be enabled: dfs.namenode.acls.enabled=true (already on in our config)
echo -e "\n[8] Set ACL — grant read to specific user"
hdfs dfs -setfacl -m user:someuser:r-- /user/hadoop/perms/test.txt

echo -e "\n[9] Get ACL"
hdfs dfs -getfacl /user/hadoop/perms/test.txt

echo -e "\n[10] Set default ACL on directory (inherits to new files)"
hdfs dfs -setfacl -m default:user:someuser:r-x /user/hadoop/perms/

echo -e "\n[11] Get ACL on directory"
hdfs dfs -getfacl /user/hadoop/perms/

echo -e "\n[12] Remove a specific ACL entry"
hdfs dfs -setfacl -x user:someuser /user/hadoop/perms/test.txt
hdfs dfs -getfacl /user/hadoop/perms/test.txt

echo -e "\n[13] Remove ALL ACLs (back to basic permissions)"
hdfs dfs -setfacl -b /user/hadoop/perms/test.txt
hdfs dfs -getfacl /user/hadoop/perms/test.txt

# Cleanup
hdfs dfs -rm -r /user/hadoop/perms/

echo -e "\n════════════════════════════════════════════"
echo "  Permissions & ACLs — DONE"
echo "════════════════════════════════════════════"
