-- ─────────────────────────────────────────────────────────────────────────────
-- 02_ddl.hql — Hive DDL: Databases, Tables, Views, Schemas
-- Run: beeline -u "jdbc:hive2://localhost:10000" -f 02_ddl.hql
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. Database Operations ────────────────────────────────────────────────────
SHOW DATABASES;

CREATE DATABASE IF NOT EXISTS playground
  COMMENT 'Hadoop playground exercises'
  LOCATION '/hive/databases/playground';

SHOW DATABASES;
DESCRIBE DATABASE playground;

USE playground;

-- ── 2. Internal (Managed) Table ───────────────────────────────────────────────
-- Hive OWNS the data; dropping the table DELETES data from HDFS
CREATE TABLE IF NOT EXISTS employees (
  emp_id     INT,
  name       STRING,
  department STRING,
  salary     DOUBLE,
  hire_date  DATE,
  country    STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
STORED AS TEXTFILE
TBLPROPERTIES ('skip.header.line.count'='0');

DESCRIBE employees;
DESCRIBE FORMATTED employees;  -- full details including HDFS location

-- ── 3. External Table ─────────────────────────────────────────────────────────
-- Hive does NOT own the data; dropping table keeps HDFS data intact
CREATE EXTERNAL TABLE IF NOT EXISTS employees_ext (
  emp_id     INT,
  name       STRING,
  department STRING,
  salary     DOUBLE,
  hire_date  STRING,
  country    STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/hive/raw/employees';   -- points to existing HDFS data

DESCRIBE FORMATTED employees_ext;

-- ── 4. ORC Table (columnar, best performance) ─────────────────────────────────
CREATE TABLE IF NOT EXISTS employees_orc (
  emp_id     INT,
  name       STRING,
  department STRING,
  salary     DOUBLE,
  hire_date  DATE,
  country    STRING
)
STORED AS ORC
TBLPROPERTIES (
  'orc.compress'='SNAPPY',
  'orc.stripe.size'='67108864'
);

-- ── 5. Parquet Table ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS employees_parquet
STORED AS PARQUET AS
SELECT * FROM employees_ext;

-- ── 6. ALTER TABLE ────────────────────────────────────────────────────────────
-- Add a column
ALTER TABLE employees ADD COLUMNS (bonus DOUBLE);

-- Rename a column
ALTER TABLE employees CHANGE bonus commission DOUBLE;

-- Add a table property
ALTER TABLE employees SET TBLPROPERTIES ('author'='hadoop-playground');

-- ── 7. Views ──────────────────────────────────────────────────────────────────
CREATE VIEW IF NOT EXISTS engineering_staff AS
SELECT emp_id, name, salary, country
FROM   employees_ext
WHERE  department = 'Engineering';

SHOW VIEWS;
SELECT * FROM engineering_staff;

-- ── 8. Show All Tables ────────────────────────────────────────────────────────
SHOW TABLES;
SHOW TABLES LIKE 'emp*';

-- ── 9. Drop (Cleanup) ─────────────────────────────────────────────────────────
-- DROP TABLE employees;            -- removes managed table + data
-- DROP TABLE employees_ext;        -- removes external table, KEEPS HDFS data
-- DROP VIEW engineering_staff;
-- DROP DATABASE playground CASCADE; -- drops DB and all tables
