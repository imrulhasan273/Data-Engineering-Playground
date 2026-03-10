-- ─────────────────────────────────────────────────────────────────────────────
-- 08_udf.hql — Hive Python UDFs via TRANSFORM + GenericUDF (Java-free approach)
--
-- Run:
--   docker exec -it hadoop-hive beeline -u "jdbc:hive2://localhost:10000" -f 08_udf.hql
--
-- Python UDF files must be uploaded to HDFS or shipped with ADD FILE
-- ─────────────────────────────────────────────────────────────────────────────

USE playground;

-- ────────────────────────────────────────────────────────────────────────────
-- APPROACH 1: TRANSFORM ... USING  (simplest — stdin/stdout like MapReduce)
-- ────────────────────────────────────────────────────────────────────────────

-- Ship the Python UDF script to all nodes
ADD FILE /tmp/hive_scripts/udf_salary_band.py;

-- Use the UDF via TRANSFORM
SELECT TRANSFORM(name, salary, department)
       USING 'python3 udf_salary_band.py'
       AS (name STRING, salary DOUBLE, band STRING, tax_rate DOUBLE)
FROM   employees;

-- TRANSFORM with filtering
SELECT name, salary, band
FROM (
  SELECT TRANSFORM(name, salary, department)
         USING 'python3 udf_salary_band.py'
         AS (name STRING, salary DOUBLE, band STRING, tax_rate DOUBLE)
  FROM employees
) t
WHERE band = 'Senior';

-- ────────────────────────────────────────────────────────────────────────────
-- APPROACH 2: Multi-column TRANSFORM (map + reduce pattern)
-- ────────────────────────────────────────────────────────────────────────────

ADD FILE /tmp/hive_scripts/udf_clean_name.py;

SELECT TRANSFORM(emp_id, name, country)
       USING 'python3 udf_clean_name.py'
       AS (emp_id INT, clean_name STRING, name_length INT, country_code STRING)
FROM   employees;

-- ────────────────────────────────────────────────────────────────────────────
-- APPROACH 3: Aggregate UDF via TRANSFORM + CLUSTER BY
-- GROUP BY + TRANSFORM to emulate custom aggregation
-- ────────────────────────────────────────────────────────────────────────────

ADD FILE /tmp/hive_scripts/udf_dept_summary.py;

SELECT TRANSFORM(department, salary)
       USING 'python3 udf_dept_summary.py'
       AS (department STRING, headcount INT, avg_salary DOUBLE, salary_range DOUBLE)
FROM (
  SELECT department, salary
  FROM   employees
  CLUSTER BY department   -- sends same dept to same reducer = sorted input for UDF
) grouped;

-- ────────────────────────────────────────────────────────────────────────────
-- APPROACH 4: String-only UDFs (no schema needed)
-- ────────────────────────────────────────────────────────────────────────────

ADD FILE /tmp/hive_scripts/udf_mask_email.py;

-- Mask PII: alice@example.com → a***@example.com
SELECT TRANSFORM(emp_id, name)
       USING 'python3 udf_mask_email.py'
       AS (emp_id STRING, masked_name STRING)
FROM employees;

-- ────────────────────────────────────────────────────────────────────────────
-- NOTE: For permanent/reusable UDFs use Java UDF jars:
-- CREATE FUNCTION my_udf AS 'com.example.MyUDF' USING JAR 'hdfs:///jars/udf.jar';
-- SELECT my_udf(name) FROM employees;
-- ────────────────────────────────────────────────────────────────────────────
