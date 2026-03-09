#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 02_hdfs_encryption.sh — HDFS Transparent Data Encryption (TDE)
#
# Architecture:
#   Key Management Server (KMS) → Encryption Zone Key (EZK)
#   NameNode → Encryption Zone (EZ) mapped to EZK
#   DataNode → stores encrypted blocks
#   Client — encrypts/decrypts transparently using DEK
#
# Run inside NameNode: docker exec -it hadoop-namenode bash 02_hdfs_encryption.sh
# ─────────────────────────────────────────────────────────────────────────────

echo "════════════════════════════════════════════"
echo "  HDFS Transparent Data Encryption"
echo "════════════════════════════════════════════"

# ── Step 1: Check KMS is configured ──────────────────────────────────────────
echo -e "\n[1] Check KMS configuration"
# KMS URL is set in core-site.xml: hadoop.security.key.provider.path
# In our Docker setup, KMS is embedded in the NameNode

hdfs dfsadmin -D hadoop.security.key.provider.path=kms://http@localhost:9600/kms \
  -report 2>/dev/null | head -5 || echo "(KMS may need separate config — see core-site.xml)"

# For this exercise, we use the built-in KMS provider
KMS_PROVIDER="kms://http@localhost:9600/kms"

# ── Step 2: Create an encryption key ─────────────────────────────────────────
echo -e "\n[2] Create encryption key in KMS"
hadoop key create myEncryptionKey \
  --provider "$KMS_PROVIDER" \
  --cipher AES/CTR/NoPadding \
  --bitlength 128 \
  --description "Key for sensitive data encryption zone" \
  2>/dev/null || echo "  (Key may already exist)"

echo -e "\n[3] List keys"
hadoop key list --provider "$KMS_PROVIDER" 2>/dev/null

# ── Step 3: Create an Encryption Zone ────────────────────────────────────────
echo -e "\n[4] Create encryption zone directory"
hdfs dfs -mkdir -p /encrypted/sensitive

echo -e "\n[5] Link directory to encryption key"
hdfs crypto -createZone -keyName myEncryptionKey -path /encrypted/sensitive
# All files written to /encrypted/sensitive/ are now encrypted at rest

echo -e "\n[6] List encryption zones"
hdfs crypto -listZones

# ── Step 4: Write and read encrypted files ───────────────────────────────────
echo -e "\n[7] Write file to encryption zone (transparent)"
echo "This is sensitive PII data: SSN=123-45-6789" > /tmp/sensitive.txt
hdfs dfs -put /tmp/sensitive.txt /encrypted/sensitive/data.txt

echo -e "\n[8] Read file (decrypted transparently by client)"
hdfs dfs -cat /encrypted/sensitive/data.txt

echo -e "\n[9] HDFS file status (shows encrypted)"
hdfs dfs -stat "%n %b %r" /encrypted/sensitive/data.txt

echo -e "\n[10] fsck shows encrypted blocks"
hdfs fsck /encrypted/sensitive/data.txt -files -blocks 2>/dev/null | head -10

# ── Step 5: Key rotation ──────────────────────────────────────────────────────
echo -e "\n[11] Roll (rotate) the encryption key"
# Key rotation creates a new version; new files use new key version
# Existing files still accessible (NameNode tracks which version was used)
hadoop key roll myEncryptionKey --provider "$KMS_PROVIDER" 2>/dev/null || echo "  (Roll requires KMS admin access)"

echo -e "\n[12] Key versions after roll"
hadoop key list --provider "$KMS_PROVIDER" --metadata 2>/dev/null | grep myEncryptionKey

# ── Step 6: Move file OUT of encryption zone (decrypts) ───────────────────────
echo -e "\n[13] Copy file OUT of EZ (will be stored in plaintext)"
hdfs dfs -mkdir -p /plaintext
hdfs dfs -cp /encrypted/sensitive/data.txt /plaintext/data_decrypted.txt
echo "  File is now in plaintext at /plaintext/data_decrypted.txt"

# Cleanup
hdfs dfs -rm -r /encrypted /plaintext

echo -e "\n════════════════════════════════════════════"
echo "  HDFS Encryption — DONE"
echo ""
echo "  Key points:"
echo "  • Encryption/decryption is transparent to applications"
echo "  • KMS manages encryption keys (can integrate with Vault, HSM)"
echo "  • cp OUT of an EZ decrypts automatically"
echo "  • distcp preserves encryption when copying between EZs"
echo "════════════════════════════════════════════"
