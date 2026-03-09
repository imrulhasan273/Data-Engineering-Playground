#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 03_phoenix_integration.sh — Phoenix SQL Layer, Hive-HBase, Spark-HBase
# Run inside HBase container: docker exec -it hadoop-hbase bash /tmp/03_phoenix_integration.sh
#
# Topics:
#   1. Apache Phoenix — SQL on HBase (JDBC interface)
#   2. Row key design (salting, hashing, reverse timestamps)
#   3. HBase Filters
#   4. Hive-HBase integration (query HBase tables via HiveQL)
#   5. Spark-HBase integration (read/write HBase from PySpark)
# ─────────────────────────────────────────────────────────────────────────────

echo "════════════════════════════════════════════"
echo "  HBase: Phoenix, Hive & Spark Integration"
echo "════════════════════════════════════════════"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 1: Apache Phoenix — SQL Layer on HBase
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[1] Apache Phoenix Overview"
echo "  • Translates standard SQL into native HBase API calls"
echo "  • JDBC/ODBC connectivity — use any SQL tool with HBase"
echo "  • Supports: DDL, DML, secondary indexes, joins, aggregations"
echo "  • NOT available in the default dajobe/hbase image"
echo "    → Needs apache/phoenix Docker image or manual installation"
echo ""

# Check if Phoenix is available
if command -v sqlline.py &>/dev/null || [ -f /opt/phoenix/bin/sqlline.py ]; then
    PHOENIX_AVAILABLE=true
    SQLLINE="sqlline.py"
else
    PHOENIX_AVAILABLE=false
    echo "  [NOTE] Phoenix not installed in this container."
    echo "  Install Phoenix alongside HBase:"
    echo "    1. Download: https://phoenix.apache.org/download.html"
    echo "    2. Copy phoenix-server-*.jar to HBase lib/"
    echo "    3. Restart HBase"
    echo "    4. Use: sqlline.py <zookeeper-host>:2181"
fi

# Phoenix SQL examples (show as documentation)
echo ""
echo "  ── Phoenix SQL Examples ──────────────────────────────────────"
echo ""
echo "  Connect to Phoenix:"
echo "  sqlline.py localhost:2181"
echo ""

cat << 'PHOENIX_SQL'
-- ─── Phoenix DDL ────────────────────────────────────────────────
-- Create a table (maps to HBase table automatically)
CREATE TABLE IF NOT EXISTS employees (
    emp_id      VARCHAR        NOT NULL,   -- row key (part 1)
    dept        VARCHAR        NOT NULL,   -- row key (part 2) — composite key
    name        VARCHAR,
    salary      DOUBLE,
    hire_date   DATE,
    CONSTRAINT pk PRIMARY KEY (emp_id, dept)
)
COLUMN_ENCODED_BYTES=0,
VERSIONS=1,
COMPRESSION='SNAPPY';

-- Salted table (auto-distributes rows across RegionServers — prevents hotspot)
CREATE TABLE IF NOT EXISTS events_salted (
    event_id    VARCHAR NOT NULL PRIMARY KEY,
    event_type  VARCHAR,
    payload     VARCHAR
) SALT_BUCKETS=4;   -- 4 buckets = 4 regions, key prefixed with 0x00–0x03

-- ─── Phoenix DML ────────────────────────────────────────────────
UPSERT INTO employees VALUES ('E001', 'Engineering', 'Alice', 95000, TO_DATE('2020-01-15'));
UPSERT INTO employees VALUES ('E002', 'Marketing',   'Bob',   72000, TO_DATE('2019-03-22'));
UPSERT INTO employees VALUES ('E003', 'Engineering', 'Carol', 105000, TO_DATE('2021-06-10'));

-- Query (Phoenix translates to HBase scan with filters)
SELECT * FROM employees WHERE dept = 'Engineering';

SELECT dept, AVG(salary) AS avg_salary
FROM employees
GROUP BY dept
ORDER BY avg_salary DESC;

-- ─── Secondary Indexes ──────────────────────────────────────────
-- Global Secondary Index (separate HBase table, full index)
CREATE INDEX idx_salary ON employees (salary DESC) INCLUDE (name, dept);

-- Local Secondary Index (co-located with data region — faster but limited)
CREATE LOCAL INDEX idx_hire ON employees (hire_date);

-- Query that uses the index automatically
SELECT name, salary FROM employees WHERE salary > 90000;

-- ─── Joins in Phoenix ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS departments (
    dept_id   VARCHAR NOT NULL PRIMARY KEY,
    dept_name VARCHAR,
    manager   VARCHAR
);

UPSERT INTO departments VALUES ('Engineering', 'Engineering Dept', 'Grace');
UPSERT INTO departments VALUES ('Marketing',   'Marketing Dept',   'Hank');

-- Hash join (small table broadcast)
SELECT e.name, e.salary, d.manager
FROM employees e
JOIN departments d ON e.dept = d.dept_id
WHERE e.salary > 80000;

-- ─── Bulk Loading ────────────────────────────────────────────────
-- psql utility for fast bulk load (bypasses WAL for performance)
-- psql localhost:2181 employees employees_data.csv

-- ─── Phoenix Functions ──────────────────────────────────────────
SELECT
    emp_id,
    UPPER(name)                          AS name_upper,
    ROUND(salary / 12, 2)               AS monthly_salary,
    TO_CHAR(hire_date, 'yyyy-MM-dd')    AS formatted_date,
    YEAR(hire_date)                      AS hire_year,
    MONTHS_BETWEEN(CURRENT_DATE, hire_date) AS months_employed
FROM employees;

PHOENIX_SQL

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 2: Row Key Design (critical for HBase performance)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "  ── Row Key Design Patterns ───────────────────────────────────"
echo ""
echo "  Problem: Sequential keys (e.g., timestamps, auto-increment) cause HOTSPOTTING"
echo "  All writes go to the SAME region → single RegionServer bottleneck"
echo ""
echo "  Pattern 1: SALTING — prefix with hash bucket"
echo "    Bad:  20240101_event1, 20240101_event2, 20240101_event3"
echo "    Good: 3_20240101_event1, 1_20240101_event2, 2_20240101_event3"
echo "    # bucket = hash(key) % num_buckets"
echo ""
echo "  Pattern 2: HASHING — MD5/SHA of key (uniform distribution)"
echo "    Bad:  user_001, user_002, user_003"
echo "    Good: a1b2c3d4_user_001, 9f8e7d6c_user_002"
echo "    # Use when you only do point lookups (no range scans)"
echo ""
echo "  Pattern 3: REVERSE TIMESTAMP — scan most-recent first naturally"
echo "    Bad:  20240101120000_event  (ascending, hot region at end)"
echo "    Good: 79759878879_event     (Long.MAX_VALUE - timestamp)"
echo "    # Use when you need: 'give me last N events'"
echo ""
echo "  Pattern 4: COMPOSITE KEY — include query dimensions"
echo "    user_id + date + event_type"
echo "    Enables: scan all events for user X on date Y"
echo ""
echo "  HBase shell: pre-split regions at creation time"
cat << 'SPLIT_EOF'
  # Pre-split into 4 regions (hex prefixes for salting)
  hbase shell << 'HBASE'
    create 'events_presplit',
      {NAME => 'cf', COMPRESSION => 'SNAPPY', VERSIONS => 1},
      {SPLITS => ['1', '2', '3']}
  HBASE
SPLIT_EOF

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 3: HBase Filters (advanced scan filtering)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "  ── HBase Filters ─────────────────────────────────────────────"

# These run inside the hbase shell — launch if available
if docker ps --format '{{.Names}}' | grep -q "hadoop-hbase" 2>/dev/null; then
    docker exec hadoop-hbase hbase shell << 'HBASE_FILTERS'

# Ensure demo table exists
create 'employees', {NAME => 'cf', VERSIONS => 1} rescue nil

# Insert demo data
put 'employees', 'E001', 'cf:name',   'Alice'
put 'employees', 'E001', 'cf:dept',   'Engineering'
put 'employees', 'E001', 'cf:salary', '95000'
put 'employees', 'E002', 'cf:name',   'Bob'
put 'employees', 'E002', 'cf:dept',   'Marketing'
put 'employees', 'E002', 'cf:salary', '72000'
put 'employees', 'E003', 'cf:name',   'Carol'
put 'employees', 'E003', 'cf:dept',   'Engineering'
put 'employees', 'E003', 'cf:salary', '105000'
put 'employees', 'E004', 'cf:name',   'Dave'
put 'employees', 'E004', 'cf:dept',   'HR'
put 'employees', 'E004', 'cf:salary', '65000'

# ── SingleColumnValueFilter — filter by column value ──────────────────────
puts "\n=== SingleColumnValueFilter: dept = Engineering ==="
scan 'employees', {
  FILTER => "SingleColumnValueFilter('cf', 'dept', =, 'binary:Engineering')"
}

# ── PrefixFilter — row keys starting with prefix ──────────────────────────
puts "\n=== PrefixFilter: rows starting with E00 ==="
scan 'employees', {FILTER => "PrefixFilter('E00')"}

# ── RowFilter with regex ───────────────────────────────────────────────────
puts "\n=== RowFilter: regex E00[12] ==="
scan 'employees', {
  FILTER => "RowFilter(=, 'regexstring:E00[12]')"
}

# ── QualifierFilter — only return specific columns ────────────────────────
puts "\n=== QualifierFilter: only 'salary' column ==="
scan 'employees', {
  FILTER => "QualifierFilter(=, 'binary:salary')"
}

# ── PageFilter — limit number of rows returned ────────────────────────────
puts "\n=== PageFilter: first 2 rows ==="
scan 'employees', {FILTER => "PageFilter(2)"}

# ── FamilyFilter ──────────────────────────────────────────────────────────
puts "\n=== FamilyFilter: only 'cf' family ==="
scan 'employees', {FILTER => "FamilyFilter(=, 'binary:cf')"}

# ── ValueFilter — filter by cell value ───────────────────────────────────
puts "\n=== ValueFilter: value contains 'Engineering' ==="
scan 'employees', {
  FILTER => "ValueFilter(=, 'substring:Engineering')"
}

# ── FilterList (AND/OR combination) ──────────────────────────────────────
puts "\n=== FilterList AND: dept=Engineering AND name contains 'Carol' ==="
scan 'employees', {
  FILTER => "FilterList(AND,
    SingleColumnValueFilter('cf', 'dept', =, 'binary:Engineering'),
    SingleColumnValueFilter('cf', 'name', =, 'binary:Carol')
  )"
}

# ── ColumnPaginationFilter ────────────────────────────────────────────────
puts "\n=== ColumnPaginationFilter: limit 1 column, offset 1 ==="
scan 'employees', {FILTER => "ColumnPaginationFilter(1, 1)"}

HBASE_FILTERS
else
    echo "  [NOTE] HBase container not running. Run filter examples with:"
    echo "  docker exec -it hadoop-hbase hbase shell"
fi

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 4: Hive-HBase Integration
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "  ── Hive-HBase Integration ────────────────────────────────────"
echo "  Map a Hive EXTERNAL table on top of an existing HBase table."
echo "  Queries go through Hive but read data directly from HBase."
echo ""

cat << 'HIVE_HBASE'
-- Run in Hive (beeline or hive CLI)
-- Requires: hive-hbase-handler jar in Hive's classpath

-- Map external Hive table to HBase table 'employees'
CREATE EXTERNAL TABLE IF NOT EXISTS hive_employees (
    row_key   STRING,
    name      STRING,
    dept      STRING,
    salary    STRING
)
STORED BY 'org.apache.hadoop.hive.hbase.HBaseStorageHandler'
WITH SERDEPROPERTIES (
    "hbase.columns.mapping" = ":key, cf:name, cf:dept, cf:salary"
)
TBLPROPERTIES (
    "hbase.table.name" = "employees",
    "hbase.zookeeper.quorum" = "hbase"
);

-- Query HBase data via HiveQL
SELECT * FROM hive_employees WHERE dept = 'Engineering';

-- Aggregate via Hive (HBase does the scan, Hive does the reduce)
SELECT dept, COUNT(*) AS headcount, AVG(CAST(salary AS DOUBLE)) AS avg_sal
FROM hive_employees
GROUP BY dept;

-- Write FROM Hive INTO HBase (insert via Hive → stored in HBase)
INSERT INTO TABLE hive_employees
SELECT 'E010', 'NewEmployee', 'Finance', '88000';

-- Create HBase table directly from Hive (if not pre-existing)
CREATE TABLE hive_new_hbase_table (
    row_key STRING,
    col1    STRING,
    col2    INT
)
STORED BY 'org.apache.hadoop.hive.hbase.HBaseStorageHandler'
WITH SERDEPROPERTIES (
    "hbase.columns.mapping" = ":key, cf:col1, cf:col2"
)
TBLPROPERTIES ("hbase.table.name" = "new_table");

HIVE_HBASE

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 5: Spark-HBase Integration
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "  ── Spark-HBase Integration ───────────────────────────────────"
echo ""
echo "  Two main connectors:"
echo "  1. SHC (Spark-HBase Connector) — hortonworks/shc (most common)"
echo "  2. hbase-spark connector — Apache HBase official"
echo ""

cat << 'PYSPARK_HBASE'
# ─── pyspark_hbase_example.py ────────────────────────────────────────────────
# Submit: spark-submit --packages com.hortonworks:shc-core:1.1.0-2.1-s_2.11 \
#                      --conf spark.hbase.host=hbase \
#                      pyspark_hbase_example.py

from pyspark.sql import SparkSession
from pyspark.sql.types import *

spark = SparkSession.builder \
    .appName("HBaseSparkIntegration") \
    .config("spark.hbase.host", "hbase") \
    .getOrCreate()

# ── Define HBase catalog (schema mapping) ────────────────────────────────────
catalog = ''.join("""{
    "table": {"namespace": "default", "name": "employees"},
    "rowkey": "row_key",
    "columns": {
        "row_key": {"cf": "rowkey", "col": "row_key",  "type": "string"},
        "name":    {"cf": "cf",     "col": "name",     "type": "string"},
        "dept":    {"cf": "cf",     "col": "dept",     "type": "string"},
        "salary":  {"cf": "cf",     "col": "salary",   "type": "string"}
    }
}""".split())

# ── Read from HBase ───────────────────────────────────────────────────────────
df = spark.read \
    .options(catalog=catalog) \
    .format("org.apache.spark.sql.execution.datasources.hbase") \
    .load()

df.show()
df.printSchema()

# Filter and aggregate
from pyspark.sql.functions import col, avg, count

df_eng = df.filter(col("dept") == "Engineering")
df_eng.show()

df.groupBy("dept") \
   .agg(count("*").alias("headcount"), avg(col("salary").cast("double")).alias("avg_salary")) \
   .orderBy("headcount", ascending=False) \
   .show()

# ── Write to HBase ────────────────────────────────────────────────────────────
from pyspark.sql import Row

new_data = spark.createDataFrame([
    Row(row_key="E020", name="Zara", dept="Engineering", salary="120000"),
    Row(row_key="E021", name="Yuki", dept="Marketing",   salary="78000"),
])

new_data.write \
    .options(catalog=catalog, newTable="5") \
    .format("org.apache.spark.sql.execution.datasources.hbase") \
    .save()

print("Written to HBase successfully")

# ── Using native HBase API from Spark (Java interop) ─────────────────────────
# For more control, use HBase's Java API via pyspark subprocess or
# use the hbase-spark connector (Apache HBase >= 2.0):
#
# spark-submit --jars hbase-spark-<ver>.jar ...
#
# from pyspark.sql import SparkSession
# spark = SparkSession.builder \
#     .config("hbase.zookeeper.quorum", "hbase:2181") \
#     .getOrCreate()
#
# df = spark.read \
#     .format("hbase") \
#     .option("hbase.columns.mapping", "name cf:name, dept cf:dept") \
#     .option("hbase.table", "employees") \
#     .load()

spark.stop()
PYSPARK_HBASE

# Save the PySpark example as a separate file too
cat << 'PYEOF' > /tmp/pyspark_hbase_example.py 2>/dev/null || true
# This file is saved as: 05_HBase/pyspark_hbase_example.py
# See the content in 03_phoenix_integration.sh SECTION 5
PYEOF

echo -e "\n════════════════════════════════════════════"
echo "  Phoenix + HBase Integrations — DONE"
echo "════════════════════════════════════════════"
