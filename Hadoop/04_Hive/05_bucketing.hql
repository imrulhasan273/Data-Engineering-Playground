-- ─────────────────────────────────────────────────────────────────────────────
-- 05_bucketing.hql — Bucketing & Sampling
-- Bucketing splits data into a fixed number of files using a hash function
-- Benefits: efficient joins (bucket map join), uniform sampling
-- ─────────────────────────────────────────────────────────────────────────────

USE playground;

SET hive.enforce.bucketing=true;
SET hive.exec.dynamic.partition.mode=nonstrict;

-- ── 1. Create a Bucketed Table ────────────────────────────────────────────────
-- Data is hashed by emp_id into 4 buckets
-- Each bucket = one file in HDFS
CREATE TABLE IF NOT EXISTS employees_bucketed (
  emp_id     INT,
  name       STRING,
  department STRING,
  salary     DOUBLE,
  country    STRING
)
CLUSTERED BY (emp_id) INTO 4 BUCKETS
STORED AS ORC;

-- Populate
INSERT OVERWRITE TABLE employees_bucketed
SELECT emp_id, name, department, salary, country
FROM   employees;

-- HDFS structure: 000000_0, 000001_0, 000002_0, 000003_0

-- ── 2. Bucketed + Partitioned Table ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS employees_part_bucketed (
  emp_id  INT,
  name    STRING,
  salary  DOUBLE
)
PARTITIONED BY (country STRING)
CLUSTERED BY (emp_id) INTO 4 BUCKETS
STORED AS ORC;

INSERT OVERWRITE TABLE employees_part_bucketed PARTITION (country)
SELECT emp_id, name, salary, country FROM employees;

SHOW PARTITIONS employees_part_bucketed;

-- ── 3. Sampling from Bucketed Table ──────────────────────────────────────────
-- TABLESAMPLE(BUCKET x OUT OF y ON col) — reads only 1/y of the buckets
-- Much faster than random sampling on large tables

-- Read bucket 1 out of 4 (25% of data) — exact, deterministic
SELECT * FROM employees_bucketed
TABLESAMPLE(BUCKET 1 OUT OF 4 ON emp_id);

-- Read 2 out of 4 buckets (50%)
SELECT * FROM employees_bucketed
TABLESAMPLE(BUCKET 1 OUT OF 2 ON emp_id);

-- Row count sampling (approximate)
SELECT * FROM employees TABLESAMPLE(10 ROWS);
SELECT * FROM employees TABLESAMPLE(50 PERCENT);
SELECT * FROM employees TABLESAMPLE(1024 BYTES);

-- ── 4. Bucket Map Join (efficient join without full shuffle) ──────────────────
-- Both tables must be bucketed on the same key with compatible bucket counts

CREATE TABLE IF NOT EXISTS departments_bucketed (
  dept_name  STRING,
  division   STRING,
  location   STRING
)
CLUSTERED BY (dept_name) INTO 4 BUCKETS
STORED AS ORC;

INSERT INTO departments_bucketed VALUES
  ('Engineering', 'Technology',  'San Francisco'),
  ('Marketing',   'Business',    'New York'),
  ('HR',          'Operations',  'Chicago'),
  ('Finance',     'Business',    'New York');

-- Enable bucket map join
SET hive.optimize.bucketmapjoin=true;
SET hive.optimize.bucketmapjoin.sortedmerge=true;

-- This join will use bucket map join (no full shuffle)
SELECT e.name, e.salary, d.location
FROM   employees_bucketed e
JOIN   departments_bucketed d
  ON   e.department = d.dept_name
WHERE  d.division = 'Technology';
