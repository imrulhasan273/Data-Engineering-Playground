#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 06_file_formats.sh — File Formats & Compression in Hadoop
# Run inside NameNode: docker exec -it hadoop-namenode bash /tmp/06_file_formats.sh
#
# Formats covered:
#   Text/CSV, SequenceFile, Avro, Parquet, ORC
# Compression codecs:
#   Gzip, Snappy, LZO, Zstandard (zstd), BZip2
# ─────────────────────────────────────────────────────────────────────────────

echo "════════════════════════════════════════════"
echo "  Hadoop File Formats & Compression"
echo "════════════════════════════════════════════"

HDFS_DIR="/file-formats-demo"
LOCAL_TMP="/tmp/file-formats"
mkdir -p "${LOCAL_TMP}"

# ── Setup: create sample data ─────────────────────────────────────────────────
echo -e "\n[Setup] Creating sample CSV data"
cat > "${LOCAL_TMP}/employees.csv" << 'EOF'
id,name,dept,salary,hire_date
1,Alice,Engineering,95000,2020-01-15
2,Bob,Marketing,72000,2019-03-22
3,Carol,Engineering,105000,2021-06-10
4,Dave,HR,65000,2018-11-30
5,Eve,Engineering,115000,2022-02-01
6,Frank,Marketing,68000,2020-08-14
7,Grace,Finance,88000,2019-07-19
8,Hank,HR,62000,2021-09-05
9,Iris,Engineering,98000,2023-01-20
10,Jack,Finance,91000,2017-04-11
EOF

# ── Upload to HDFS ────────────────────────────────────────────────────────────
hdfs dfs -mkdir -p "${HDFS_DIR}"
hdfs dfs -put -f "${LOCAL_TMP}/employees.csv" "${HDFS_DIR}/employees.csv"

echo -e "\n[1] Text/CSV format"
echo "  • Simple, human-readable, no built-in schema"
echo "  • NOT splittable when compressed with Gzip/Snappy (use BZip2 or LZO for splittable)"
hdfs dfs -ls "${HDFS_DIR}/employees.csv"
hdfs dfs -cat "${HDFS_DIR}/employees.csv" | head -3

# ─────────────────────────────────────────────────────────────────────────────
# COMPRESSION CODECS OVERVIEW
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n═══ Compression Codecs ═══"
echo ""
echo "  Codec      | Extension | Splittable | Speed  | Ratio"
echo "  -----------|-----------|------------|--------|-------"
echo "  None       | (none)    | Yes        | N/A    | None"
echo "  Gzip       | .gz       | NO         | Medium | High"
echo "  BZip2      | .bz2      | YES        | Slow   | Very High"
echo "  Snappy     | .snappy   | NO*        | Fast   | Medium"
echo "  LZO        | .lzo      | YES*       | Fast   | Medium"
echo "  Zstandard  | .zst      | NO*        | Fast   | High"
echo ""
echo "  * Snappy/LZO/Zstd ARE splittable inside container formats (ORC, Parquet, SequenceFile)"
echo "  KEY RULE: Never compress raw text files with non-splittable codecs for MapReduce input"

# ─────────────────────────────────────────────────────────────────────────────
# SEQUENCEFILE
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[2] SequenceFile"
echo "  • Binary key-value pairs — splittable (even when compressed)"
echo "  • Compression types: NONE, RECORD (per record), BLOCK (best compression)"
echo "  • Best for: intermediate MapReduce data, small file aggregation"
echo ""
echo "  Demonstration (using Hadoop's built-in TeraGen → SequenceFile):"

# Use hadoop distcp text→sequence conversion approach via Hive or MR
# Show the concept via mapred commands
hadoop fs -text "${HDFS_DIR}/employees.csv" 2>/dev/null | head -3

echo ""
echo "  Create a SequenceFile via MapReduce (conceptual):"
echo "  hadoop jar hadoop-streaming.jar \\"
echo "    -D mapreduce.output.fileoutputformat.compress=true \\"
echo "    -D mapreduce.output.fileoutputformat.compress.codec=org.apache.hadoop.io.compress.SnappyCodec \\"
echo "    -D mapreduce.output.compress.type=BLOCK \\"
echo "    -inputformat org.apache.hadoop.mapreduce.lib.input.TextInputFormat \\"
echo "    -outputformat org.apache.hadoop.mapreduce.lib.output.SequenceFileOutputFormat \\"
echo "    -input ${HDFS_DIR}/employees.csv -output ${HDFS_DIR}/employees_seq"

# ─────────────────────────────────────────────────────────────────────────────
# AVRO
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[3] Apache Avro"
echo "  • Row-based binary format with embedded schema (JSON schema definition)"
echo "  • Schema evolution: add/remove/rename fields with defaults"
echo "  • Splittable with sync markers"
echo "  • Best for: streaming pipelines (Kafka), write-heavy workloads, schema evolution"
echo ""

# Create Avro schema
cat > "${LOCAL_TMP}/employee.avsc" << 'EOF'
{
  "type": "record",
  "name": "Employee",
  "namespace": "com.example",
  "fields": [
    {"name": "id",        "type": "int"},
    {"name": "name",      "type": "string"},
    {"name": "dept",      "type": "string"},
    {"name": "salary",    "type": "double"},
    {"name": "hire_date", "type": "string"},
    {"name": "bonus",     "type": ["null", "double"], "default": null}
  ]
}
EOF

echo "  Schema (employee.avsc):"
cat "${LOCAL_TMP}/employee.avsc"

# If avro-tools is available
if command -v avro-tools &>/dev/null; then
    echo ""
    echo "  Converting CSV → Avro (requires avro-tools):"
    echo "  avro-tools fromjson --schema-file employee.avsc data.json > employees.avro"
    echo ""
    echo "  Reading an Avro file:"
    echo "  avro-tools tojson employees.avro | head -5"
    echo ""
    echo "  Inspect schema of existing Avro file:"
    echo "  avro-tools getschema employees.avro"
else
    echo ""
    echo "  [NOTE] avro-tools not installed in this container."
    echo "  Install: download avro-tools-1.11.x.jar from Apache"
    echo "  Usage:   java -jar avro-tools-1.11.x.jar tojson employees.avro"
fi

echo ""
echo "  Avro in Hive:"
echo "  CREATE TABLE employees_avro"
echo "  STORED AS AVRO"
echo "  TBLPROPERTIES ('avro.schema.literal'='<schema json>');"

echo ""
echo "  Schema Evolution rules:"
echo "  ✔ Add field with default  → backward compatible"
echo "  ✔ Remove field with default → forward compatible"
echo "  ✘ Rename field (without alias) → BREAKING"
echo "  ✘ Change field type → BREAKING"

# ─────────────────────────────────────────────────────────────────────────────
# PARQUET
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[4] Apache Parquet"
echo "  • Columnar format — reads only needed columns (predicate pushdown)"
echo "  • Excellent compression (columns of same type compress very well)"
echo "  • Splittable (row groups as split units)"
echo "  • Best for: analytics, Spark/Hive/Presto queries, read-heavy workloads"
echo ""
echo "  Internal structure:"
echo "  File → Row Groups → Column Chunks → Pages"
echo "  Default row group size: 128 MB (matches HDFS block size)"
echo ""

# Create Parquet via Hive (running a beeline command)
echo "  Create Parquet table in Hive:"
cat << 'HIVE_EOF'
  -- Create Parquet table with Snappy compression
  CREATE TABLE employees_parquet (
    id        INT,
    name      STRING,
    dept      STRING,
    salary    DOUBLE,
    hire_date STRING
  )
  STORED AS PARQUET
  TBLPROPERTIES ("parquet.compress"="SNAPPY");

  -- Load from CSV source
  INSERT INTO employees_parquet
  SELECT * FROM employees_csv;

  -- Verify: only reads 'name' and 'salary' columns from disk
  SELECT name, salary FROM employees_parquet WHERE dept = 'Engineering';
HIVE_EOF

echo ""
echo "  Parquet inspection via hadoop jar:"
echo "  hadoop jar parquet-tools-<ver>.jar schema hdfs:///path/to/file.parquet"
echo "  hadoop jar parquet-tools-<ver>.jar head  hdfs:///path/to/file.parquet"
echo "  hadoop jar parquet-tools-<ver>.jar meta  hdfs:///path/to/file.parquet"

# ─────────────────────────────────────────────────────────────────────────────
# ORC
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[5] Apache ORC (Optimized Row Columnar)"
echo "  • Columnar format built for Hive — supports ACID transactions"
echo "  • Built-in lightweight indexes (min/max per stripe, bloom filters)"
echo "  • Better compression than Parquet for many Hive workloads"
echo "  • Best for: Hive ACID tables, update/delete operations, Hive ecosystem"
echo ""
echo "  Internal structure:"
echo "  File → Stripes (default 256 MB) → Row Data + Index Data + Footer"
echo ""

echo "  Create ORC table in Hive:"
cat << 'HIVE_ORC'
  -- ORC with ZLIB compression (default)
  CREATE TABLE employees_orc (
    id        INT,
    name      STRING,
    dept      STRING,
    salary    DOUBLE,
    hire_date STRING
  )
  STORED AS ORC
  TBLPROPERTIES (
    "orc.compress"         = "SNAPPY",
    "orc.bloom.filter.columns" = "dept,name",
    "orc.stripe.size"     = "268435456"
  );

  -- ORC with ACID (requires transactional table)
  CREATE TABLE employees_orc_acid (
    id        INT,
    name      STRING,
    salary    DOUBLE
  )
  CLUSTERED BY (id) INTO 4 BUCKETS
  STORED AS ORC
  TBLPROPERTIES ("transactional"="true");

  -- Now supports UPDATE and DELETE
  UPDATE employees_orc_acid SET salary = salary * 1.10 WHERE dept = 'Engineering';
  DELETE FROM employees_orc_acid WHERE id = 5;
HIVE_ORC

echo ""
echo "  ORC inspection:"
echo "  hive --orcfiledump hdfs:///path/to/file.orc"

# ─────────────────────────────────────────────────────────────────────────────
# FORMAT COMPARISON
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[6] Format Comparison Summary"
echo ""
echo "  Format      | Layout    | Splittable | Schema  | Best For"
echo "  ------------|-----------|------------|---------|-----------------------------"
echo "  Text/CSV    | Row       | Yes (raw)  | None    | Simple input, debugging"
echo "  SequenceFile| Row       | Yes        | Binary  | Intermediate MR data"
echo "  Avro        | Row       | Yes        | Embedded| Streaming, schema evolution"
echo "  Parquet     | Columnar  | Yes        | Embedded| Analytics, Spark, Presto"
echo "  ORC         | Columnar  | Yes        | Embedded| Hive, ACID, transactional"
echo ""
echo "  Compression within columnar formats (Parquet/ORC):"
echo "  • Snappy  — fast read/write, moderate compression → best for production"
echo "  • ZLIB    — high compression, slower → best for archival"
echo "  • LZ4     — fastest, low compression → best for hot data"
echo "  • Zstd    — best balance of speed + ratio (Parquet 2.0+)"

# ─────────────────────────────────────────────────────────────────────────────
# SPLITTABLE vs NON-SPLITTABLE — IMPACT ON MAPREDUCE
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[7] Splittable vs Non-Splittable Compression"
echo ""
echo "  NON-SPLITTABLE (e.g., Gzip compressed text):"
echo "  • Entire file → single InputSplit → single Mapper"
echo "  • 1 GB Gzip file = 1 mapper (no parallelism!)"
echo "  • Kills MapReduce performance on large files"
echo ""
echo "  SPLITTABLE:"
echo "  • BZip2 on text: has block markers → splittable"
echo "  • ORC/Parquet: columnar stripes/row groups act as splits"
echo "  • SequenceFile: sync markers make it splittable regardless of codec"
echo ""
echo "  RULE: For MapReduce input → use ORC/Parquet/SequenceFile"
echo "        OR use BZip2 for compressed text"
echo "        NEVER use Gzip on large text input files"

# ─────────────────────────────────────────────────────────────────────────────
# COMPRESSION IN MAPREDUCE JOBS
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[8] Enabling Compression in MapReduce"
echo ""
echo "  # Map output compression (intermediate data — always Snappy or LZ4)"
echo "  hadoop jar job.jar \\"
echo "    -D mapreduce.map.output.compress=true \\"
echo "    -D mapreduce.map.output.compress.codec=org.apache.hadoop.io.compress.SnappyCodec \\"
echo "    ..."
echo ""
echo "  # Final output compression"
echo "  hadoop jar job.jar \\"
echo "    -D mapreduce.output.fileoutputformat.compress=true \\"
echo "    -D mapreduce.output.fileoutputformat.compress.codec=org.apache.hadoop.io.compress.GzipCodec \\"
echo "    -D mapreduce.output.fileoutputformat.compress.type=BLOCK \\"
echo "    ..."
echo ""
echo "  # Check compression codecs available"
hadoop checknative -a 2>/dev/null || echo "  (hadoop checknative shows available native codecs)"

# Cleanup
hdfs dfs -rm -r -skipTrash "${HDFS_DIR}" 2>/dev/null
echo -e "\n════════════════════════════════════════════"
echo "  File Formats & Compression — DONE"
echo "════════════════════════════════════════════"
