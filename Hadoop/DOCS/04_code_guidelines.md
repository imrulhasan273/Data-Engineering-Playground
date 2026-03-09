# Code Guidelines & Best Practices

Standards and patterns to follow when writing code for this Hadoop playground.

---

## Table of Contents

1. [Python MapReduce (Hadoop Streaming)](#1-python-mapreduce)
2. [HiveQL](#2-hiveql)
3. [PySpark](#3-pyspark)
4. [Pig Latin](#4-pig-latin)
5. [Shell Scripts](#5-shell-scripts)
6. [HBase Python (HappyBase)](#6-hbase-python)
7. [Data Design Decisions](#7-data-design-decisions)

---

## 1. Python MapReduce

### Mapper Template
```python
#!/usr/bin/env python3
"""
mapper.py — <Brief description>

Input  (stdin):  <describe input format>
Output (stdout): <key>\t<value>

Local test:
    cat input.txt | python3 mapper.py | sort | python3 reducer.py
"""

import sys
import os

# Read env vars (set by Hadoop Streaming or -cmdenv)
input_file = os.environ.get('map_input_file', 'unknown')

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue                    # always skip empty lines

    # --- Your transform logic here ---
    key   = ...
    value = ...

    print(f"{key}\t{value}")        # tab-separated key\tvalue
```

### Reducer Template
```python
#!/usr/bin/env python3
"""
reducer.py — <Brief description>

Input  (stdin): <key>\t<value>  (sorted by key — guaranteed by Hadoop)
Output (stdout): <key>\t<aggregated_value>
"""

import sys

current_key   = None
current_group = []          # collect values for current key

def emit(key, group):
    """Process one key group and emit results."""
    result = sum(int(v) for v in group)   # example: sum
    print(f"{key}\t{result}")

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    key, value = line.split('\t', 1)      # maxsplit=1 protects values with tabs

    if key == current_key:
        current_group.append(value)
    else:
        if current_key is not None:
            emit(current_key, current_group)
        current_key   = key
        current_group = [value]

# Don't forget the last group
if current_key is not None:
    emit(current_key, current_group)
```

### Rules

**Always do this:**
- Add a `#!/usr/bin/env python3` shebang — Hadoop Streaming needs it
- Strip lines: `line = line.strip()` — trailing newlines cause key mismatches
- Skip empty lines: `if not line: continue`
- Use `maxsplit=1` when splitting: `line.split('\t', 1)` — values may contain tabs
- Test locally before submitting: `cat input | python3 mapper.py | sort | python3 reducer.py`
- Handle `ValueError`/`TypeError` with `try/except` when parsing numbers

**Never do this:**
- Print anything other than `key\tvalue` from mapper/reducer (breaks the pipeline)
- Print debug output to stdout — use `sys.stderr.write("DEBUG: ...\n")` instead
- Open files directly in mapper/reducer — ship them with `-files` and open by basename only
- Use `import pandas` or heavy libraries without shipping them via `--py-files`

**Common mistake:**
```python
# WRONG — debug print corrupts output
print(f"Processing: {key}")
context.write(key, value)

# CORRECT — send debug to stderr
import sys
sys.stderr.write(f"Processing: {key}\n")
print(f"{key}\t{value}")
```

### Passing Configuration to Scripts
```bash
# Pass via -cmdenv
hadoop jar $STREAMING_JAR \
  -cmdenv "THRESHOLD=1000" \
  -cmdenv "DATE=2024-01" \
  -mapper "python3 mapper.py" ...
```
```python
# Read in script
import os
threshold = int(os.environ.get('THRESHOLD', '100'))
```

### Shipping Additional Files
```bash
# Ship a single module
hadoop jar $STREAMING_JAR \
  -files "mapper.py,reducer.py,utils.py,lookup.json" \
  -mapper "python3 mapper.py" ...
```
```python
# In mapper.py — open by basename (not full path)
import json
with open('lookup.json') as f:   # NOT '/full/path/lookup.json'
    lookup = json.load(f)
```

---

## 2. HiveQL

### File Naming Convention
```
01_ddl.hql          -- DDL only (CREATE, ALTER, DROP)
02_dml.hql          -- DML only (INSERT, SELECT, UPDATE)
03_partitioning.hql -- Feature-specific
```

### Query Structure
```sql
-- 1. Always set the database first
USE my_database;

-- 2. Group settings at the top
SET hive.execution.engine=tez;
SET hive.exec.dynamic.partition.mode=nonstrict;

-- 3. One statement per logical block, blank lines between
CREATE TABLE IF NOT EXISTS employees (
    emp_id     INT,
    name       STRING,
    salary     DOUBLE
)
STORED AS ORC;

-- 4. INSERT → SELECT on separate lines
INSERT INTO TABLE employees
SELECT id, name, salary
FROM   raw_employees
WHERE  status = 'active';
```

### Table Creation Rules
```sql
-- External for production data (safe to DROP)
CREATE EXTERNAL TABLE raw_data (...)
LOCATION '/data/raw/';

-- ORC for analytics tables
CREATE TABLE analytics.employees (...)
STORED AS ORC
TBLPROPERTIES ('orc.compress'='SNAPPY');

-- Always use IF NOT EXISTS in scripts (idempotent)
CREATE TABLE IF NOT EXISTS mytable (...);

-- Always specify column terminator for text files
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
STORED AS TEXTFILE;
```

### Naming Conventions
| Object | Convention | Example |
|--------|-----------|---------|
| Database | `snake_case` | `analytics_db` |
| Table | `snake_case` | `employee_salaries` |
| Column | `snake_case` | `hire_date` |
| Partition col | `snake_case` | `year`, `month`, `country` |
| CTE | `UPPER_SNAKE` | `WITH DEPT_STATS AS (...)` |

### Performance Rules
```sql
-- 1. Always filter on partition columns
WHERE year = 2024              -- good: partition pruning
WHERE YEAR(event_date) = 2024  -- BAD: function prevents pruning

-- 2. Put small tables on the right side of JOIN
-- (or use /*+ MAPJOIN(small_table) */ hint)
SELECT *
FROM   large_fact f
JOIN   small_dim d ON f.id = d.id;   -- small_dim on right

-- 3. Use EXPLAIN before running expensive queries
EXPLAIN SELECT ...;

-- 4. Avoid SELECT * — name columns explicitly
SELECT emp_id, name, salary   -- good
FROM employees;
SELECT *                      -- BAD in production
FROM employees;

-- 5. Use WITH (CTE) for readability over nested subqueries
WITH dept_avg AS (
    SELECT department, AVG(salary) AS avg_sal
    FROM   employees GROUP BY department
)
SELECT e.name, e.salary, d.avg_sal
FROM   employees e
JOIN   dept_avg d ON e.department = d.department;
```

---

## 3. PySpark

### Script Template
```python
#!/usr/bin/env python3
"""
script.py — <Brief description>

Usage:
    spark-submit --master yarn --deploy-mode client script.py [input] [output]
"""

import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, avg, desc

def main():
    spark = SparkSession.builder \
        .appName("DescriptiveJobName") \
        .config("spark.sql.shuffle.partitions", "20") \
        .getOrCreate()

    spark.sparkContext.setLogLevel("WARN")   # reduce log noise

    input_path  = sys.argv[1] if len(sys.argv) > 1 else "hdfs:///default/input"
    output_path = sys.argv[2] if len(sys.argv) > 2 else "hdfs:///default/output"

    # --- Read ---
    df = spark.read.parquet(input_path)

    # --- Transform ---
    result = df \
        .filter(col("status") == "active") \
        .groupBy("department") \
        .agg(count("*").alias("headcount"), avg("salary").alias("avg_salary")) \
        .orderBy(desc("avg_salary"))

    # --- Write ---
    result.write.mode("overwrite").parquet(output_path)

    spark.stop()

if __name__ == "__main__":
    main()
```

### Rules

**Prefer DataFrame over RDD:**
```python
# GOOD — Catalyst optimizer can optimize this
df.filter(col("salary") > 50000) \
  .groupBy("dept") \
  .agg(avg("salary"))

# AVOID (unless you need custom logic unavailable in DataFrame API)
rdd.filter(lambda x: x["salary"] > 50000) \
   .map(lambda x: (x["dept"], x["salary"])) \
   .reduceByKey(lambda a, b: a + b)
```

**Control shuffle partitions:**
```python
# Default is 200 — too high for small data, too low for very large data
# Rule: aim for ~128MB per partition
spark.conf.set("spark.sql.shuffle.partitions", "20")
```

**Cache only what you reuse:**
```python
# Useful: df read from HDFS used in multiple branches
df.cache()
branch1 = df.filter(...)
branch2 = df.groupBy(...)

# Wasteful: caching a df only used once
df.cache()
df.write.parquet(...)     # only used here — don't cache
```

**Column references:**
```python
from pyspark.sql.functions import col

# GOOD — works even if df is renamed/aliased
df.filter(col("salary") > 50000)

# RISKY — breaks if df is joined and column becomes ambiguous
df.filter(df.salary > 50000)
df.filter("salary > 50000")    # string form also fine for simple filters
```

**Write patterns:**
```python
# Always specify mode (avoid accidental overwrites or failures)
df.write.mode("overwrite").parquet(path)    # replace
df.write.mode("append").parquet(path)       # add
df.write.mode("ignore").parquet(path)       # skip if exists
df.write.mode("error").parquet(path)        # fail if exists (default)

# Partition on write for large datasets
df.write \
  .mode("overwrite") \
  .partitionBy("year", "month") \
  .parquet("hdfs:///output/path")
```

---

## 4. Pig Latin

### Script Structure
```pig
-- 1. Header comment with description and run command
-- Description: Word count on HDFS text files
-- Run: pig -x mapreduce 02_word_count.pig

-- 2. LOAD with explicit schema
data = LOAD '/input/path' USING PigStorage(',')
       AS (id:int, name:chararray, salary:double);

-- 3. DESCRIBE to verify schema (good for development)
-- DESCRIBE data;

-- 4. Chain transforms with meaningful relation names
cleaned      = FILTER data BY salary > 0 AND name IS NOT NULL;
transformed  = FOREACH cleaned GENERATE name, salary / 12.0 AS monthly;
grouped      = GROUP transformed BY name;
aggregated   = FOREACH grouped GENERATE group AS name, AVG(transformed.monthly);
sorted       = ORDER aggregated BY monthly DESC;
top10        = LIMIT sorted 10;

-- 5. STORE result (triggers execution)
STORE top10 INTO '/output/path' USING PigStorage('\t');
```

### Rules
- Use `DESCRIBE` during development; remove before production
- Prefer `STORE` over `DUMP` in production scripts (DUMP prints to console; slow for large data)
- Use `EXPLAIN` to inspect the execution plan without running
- Name relations descriptively (`engineers` not `r2`)
- Set `default_parallel` for large jobs: `SET default_parallel 10;`

---

## 5. Shell Scripts

### Script Template
```bash
#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# script_name.sh — One-line description
# Container: docker exec -it hadoop-namenode bash script_name.sh
# ─────────────────────────────────────────────────────────────────────────────

set -e    # exit on any error
set -u    # error on undefined variable (optional but safe)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Constants at the top
INPUT_HDFS="/path/to/input"
OUTPUT_HDFS="/path/to/output"

# ── Section headers make scripts readable ────────────────────────────────────
echo "════════════════════════════════════"
echo "  Script Title"
echo "════════════════════════════════════"

echo -e "\n[1] Step description"
hdfs dfs -mkdir -p "$INPUT_HDFS"

echo -e "\n[2] Another step"
hdfs dfs -put -f /tmp/data.txt "$INPUT_HDFS/"

echo -e "\n════════════════════════════════════"
echo "  DONE"
echo "════════════════════════════════════"
```

### Rules
- Always start with `set -e` — stops on first error, prevents partial runs
- Use `"${VARIABLE}"` (quoted) for all variable expansions — protects against spaces
- Use `-f` with `put` and `-r -f` with `rm` in setup scripts (idempotent)
- Clean up output directories before running: `hdfs dfs -rm -r -f "$OUTPUT_HDFS"`
- Use `$()` not backticks for command substitution: `VAR=$(command)` not ``VAR=`command` ``
- Always use absolute paths for HDFS operations
- Print section numbers for easy debugging: `echo -e "\n[3] Upload data"`

---

## 6. HBase Python (HappyBase)

### Connection Pattern
```python
import happybase

# Always use context manager or explicit close
conn = happybase.Connection(host='localhost', port=9090)
conn.open()

try:
    table = conn.table('mytable')
    # ... work with table ...
finally:
    conn.close()
```

### Row Key Rules
```python
# GOOD: byte strings for row keys
table.put(b'user:001', {b'cf:name': b'Alice'})
table.row(b'user:001')

# ALSO ACCEPTABLE: str (HappyBase auto-encodes)
table.put('user:001', {'cf:name': 'Alice'})

# Design row keys for your query patterns:
# Point lookup:    'user:001'
# Prefix scan:     'user:' prefix → scan(row_prefix=b'user:')
# Range scan:      'order:2024-01:001' → scan(row_start=..., row_stop=...)
```

### Batch Writes
```python
# ALWAYS use batch for inserting multiple rows
with table.batch(batch_size=1000) as batch:
    for row_key, data in rows_to_insert:
        batch.put(row_key, data)
# Batch auto-flushes every 1000 rows and on exit
```

### Column Name Convention
```python
# HBase column = b'family:qualifier'
# Use descriptive qualifiers, avoid abbreviations

# GOOD
{b'personal:first_name': b'Alice',
 b'personal:last_name':  b'Smith',
 b'work:department':     b'Engineering',
 b'work:salary':         b'95000'}

# BAD (too abbreviated)
{b'p:fn': b'Alice', b'p:ln': b'Smith'}
```

---

## 7. Data Design Decisions

### When to Use Each Technology

| Use Case | Best Tool | Reason |
|----------|-----------|--------|
| Full table scan / SQL analytics | **Hive** | Partition pruning, SQL interface |
| Random read by key (< 10ms) | **HBase** | Indexed row key |
| Batch ETL pipeline | **MapReduce** or **Spark** | Parallel processing |
| Complex multi-step ETL | **Pig** or **Spark** | DAG execution |
| RDBMS → Hadoop bulk load | **Sqoop** | Parallel JDBC import |
| Streaming ingest | **Flume** / **Kafka** | Real-time collection |
| ML / iterative algorithms | **Spark** | In-memory, iterative |
| Archival cold data | **HDFS + EC** | Erasure coding for storage savings |

### HDFS File Format Decision Tree
```
Is the data accessed by multiple engines (Spark + Presto + Hive)?
  YES → Parquet
  NO  → Is it a Hive-only analytics table?
         YES → ORC
         NO  → Is it raw ingested data that may change format?
                YES → TextFile or Avro (schema evolution)
                NO  → ORC
```

### Partition Column Selection
```
Good partition columns:
  ✓ date (year, month, day) — cardinality: 365 values/year
  ✓ country, region         — cardinality: 10-200 values
  ✓ status (active/inactive)— cardinality: 2-10 values

Bad partition columns:
  ✗ user_id    — millions of values → millions of tiny files
  ✗ timestamp  — infinite cardinality
  ✗ amount     — continuous numeric, never used as filter

Rule: each partition should ideally contain at least 1 HDFS block (128MB+) of data.
```

### Number of Reducers
```bash
# MapReduce
# Rule: 0.95 or 1.75 × (number of nodes × containers per node)
# For our 2-node cluster: aim for 2-4 reducers

# Spark
# spark.sql.shuffle.partitions default = 200 (too high for small data)
# Aim for 128MB - 256MB per partition
# Formula: total_data_size_mb / 128 = target_partitions
```
