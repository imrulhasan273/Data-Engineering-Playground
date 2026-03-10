#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 04_bulk_load_importtsv.sh — HBase ImportTsv + completebulkload
#
# The only scalable way to load 100M+ rows into HBase:
#   1. Generate HFiles directly (bypasses Write-Ahead Log, MemStore)
#   2. Move HFiles into HBase using completebulkload (atomic)
#
# Run inside HBase container: docker exec -it hadoop-hbase bash 04_bulk_load_importtsv.sh
# ─────────────────────────────────────────────────────────────────────────────

TABLE="employees_import"
INPUT_HDFS="/hbase/bulk/input"
HFILES_HDFS="/hbase/bulk/hfiles"
HBASE_HOME=${HBASE_HOME:-/opt/hbase}

echo "════════════════════════════════════════════"
echo "  HBase Bulk Load — ImportTsv + completebulkload"
echo "════════════════════════════════════════════"

# ── Step 1: Prepare TSV data ──────────────────────────────────────────────────
echo -e "\n[1] Creating TSV input data"
# Format: row_key\tcf:col1\tcf:col2  (tab-separated)
cat > /tmp/employees_bulk.tsv << 'EOF'
emp:000001	Alice	Engineering	95000	US
emp:000002	Bob	Marketing	72000	US
emp:000003	Carol	Engineering	88000	UK
emp:000004	Dave	HR	65000	US
emp:000005	Eve	Engineering	105000	DE
emp:000006	Frank	Marketing	78000	UK
emp:000007	Grace	HR	68000	US
emp:000008	Heidi	Engineering	92000	DE
emp:000009	Ivan	Marketing	75000	US
emp:000010	Judy	Engineering	98000	UK
EOF

# Generate larger dataset for a real-scale demonstration
python3 - << 'PYEOF'
import random
with open('/tmp/employees_large.tsv', 'w') as f:
    depts    = ['Engineering', 'Marketing', 'HR', 'Finance']
    countries = ['US', 'UK', 'DE']
    for i in range(1, 100_001):
        row_key = f"emp:{i:06d}"
        name    = f"Employee_{i}"
        dept    = random.choice(depts)
        salary  = random.randint(60_000, 120_000)
        country = random.choice(countries)
        f.write(f"{row_key}\t{name}\t{dept}\t{salary}\t{country}\n")
print("Generated 100,000 rows")
PYEOF

hdfs dfs -rm -r -f "$INPUT_HDFS" "$HFILES_HDFS"
hdfs dfs -mkdir -p "$INPUT_HDFS"
hdfs dfs -put /tmp/employees_large.tsv "$INPUT_HDFS/"
echo "Data uploaded: $(hdfs dfs -du -h $INPUT_HDFS)"

# ── Step 2: Create the target HBase table ─────────────────────────────────────
echo -e "\n[2] Create HBase table"
echo "
disable '$TABLE' 2>/dev/null
drop '$TABLE' 2>/dev/null
create '$TABLE', {NAME => 'personal', COMPRESSION => 'SNAPPY'}, {NAME => 'work', COMPRESSION => 'SNAPPY'}
exit
" | hbase shell -n 2>/dev/null || true

# ── Step 3: Run ImportTsv to generate HFiles ──────────────────────────────────
echo -e "\n[3] ImportTsv — generating HFiles directly (no WAL, no MemStore)"
# Column mapping: HBASE_ROW_KEY is special — maps to the row key
hbase org.apache.hadoop.hbase.mapreduce.ImportTsv \
  -Dimporttsv.separator='\t' \
  -Dimporttsv.columns="HBASE_ROW_KEY,personal:name,work:department,work:salary,personal:country" \
  -Dimporttsv.bulk.output="$HFILES_HDFS" \
  "$TABLE" \
  "$INPUT_HDFS"

echo "HFiles generated at: $HFILES_HDFS"
hdfs dfs -ls "$HFILES_HDFS"

# ── Step 4: completebulkload — atomically move HFiles into HBase ──────────────
echo -e "\n[4] completebulkload — move HFiles into live HBase"
hbase org.apache.hadoop.hbase.tool.BulkLoadHFilesTool \
  "$HFILES_HDFS" \
  "$TABLE"

# ── Step 5: Verify ────────────────────────────────────────────────────────────
echo -e "\n[5] Verify — count rows and spot-check"
echo "
count '$TABLE', INTERVAL => 10000
get '$TABLE', 'emp:000001'
get '$TABLE', 'emp:050000'
exit
" | hbase shell -n

echo -e "\n════════════════════════════════════════════"
echo "  Bulk Load — DONE"
echo ""
echo "  ImportTsv generates HFiles (bypasses WAL)"
echo "  completebulkload moves them in atomically"
echo "  Scales to billions of rows without OOM"
echo "════════════════════════════════════════════"
