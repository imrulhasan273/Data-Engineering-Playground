-- ─────────────────────────────────────────────────────────────────────────────
-- 03_dml.hql — Hive DML: LOAD, INSERT, SELECT, UPDATE, DELETE, CTAS
-- Run after 02_ddl.hql
-- ─────────────────────────────────────────────────────────────────────────────

USE playground;

-- ── 1. LOAD DATA from HDFS ───────────────────────────────────────────────────
-- Moves file from HDFS path into Hive table directory
LOAD DATA INPATH '/hive/raw/employees/employees.csv'
OVERWRITE INTO TABLE employees;

-- LOAD from local filesystem (only works on HiveServer2 node)
-- LOAD DATA LOCAL INPATH '/tmp/employees.csv' INTO TABLE employees;

SELECT COUNT(*) AS total FROM employees;

-- ── 2. INSERT ... VALUES (for small data only) ────────────────────────────────
-- Hive requires ACID (ORC + transactional) for UPDATE/DELETE
-- For now use INSERT to add rows
INSERT INTO TABLE employees VALUES
  (11, 'Karl',  'Finance',  81000, '2023-01-01', 'US'),
  (12, 'Laura', 'Finance',  87000, '2022-06-15', 'UK');

SELECT * FROM employees WHERE department = 'Finance';

-- ── 3. INSERT OVERWRITE ───────────────────────────────────────────────────────
INSERT OVERWRITE TABLE employees_orc
SELECT * FROM employees;

SELECT COUNT(*) AS orc_count FROM employees_orc;

-- ── 4. CTAS — Create Table As Select ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS high_earners
STORED AS ORC AS
SELECT emp_id, name, department, salary
FROM   employees
WHERE  salary > 85000
ORDER BY salary DESC;

SELECT * FROM high_earners;

-- ── 5. Basic SELECT Queries ───────────────────────────────────────────────────
-- Projection and filtering
SELECT name, salary
FROM   employees
WHERE  country = 'US'
  AND  salary > 70000
ORDER BY salary DESC;

-- Aggregation
SELECT department,
       COUNT(*)         AS headcount,
       AVG(salary)      AS avg_salary,
       MAX(salary)      AS max_salary,
       MIN(salary)      AS min_salary
FROM   employees
GROUP BY department
ORDER BY avg_salary DESC;

-- HAVING clause
SELECT department, AVG(salary) AS avg_sal
FROM   employees
GROUP BY department
HAVING AVG(salary) > 80000;

-- ── 6. String & Date Functions ───────────────────────────────────────────────
SELECT
  UPPER(name)                        AS upper_name,
  LENGTH(name)                       AS name_len,
  SUBSTR(name, 1, 3)                 AS name_prefix,
  CONCAT(name, ' (', country, ')')   AS name_country,
  TO_DATE(hire_date)                 AS hire_date,
  YEAR(hire_date)                    AS hire_year,
  MONTHS_BETWEEN(CURRENT_DATE, TO_DATE(hire_date)) / 12 AS years_employed,
  ROUND(salary / 12, 2)              AS monthly_salary
FROM employees
LIMIT 5;

-- ── 7. Conditional Expressions ───────────────────────────────────────────────
SELECT name, salary,
  CASE
    WHEN salary >= 100000 THEN 'Senior'
    WHEN salary >= 80000  THEN 'Mid-level'
    ELSE                       'Junior'
  END AS level,
  IF(country = 'US', salary * 0.75, salary * 0.8) AS after_tax
FROM employees;

-- ── 8. LIMIT and TABLESAMPLE ──────────────────────────────────────────────────
SELECT * FROM employees LIMIT 3;

-- Sample 50% of rows (approximate)
SELECT * FROM employees TABLESAMPLE(50 PERCENT);

-- ── 9. UPDATE and DELETE (requires ACID — ORC + transactional table) ─────────
-- First create a transactional table
SET hive.support.concurrency=true;
SET hive.txn.manager=org.apache.hadoop.hive.ql.lockmgr.DbTxnManager;

CREATE TABLE IF NOT EXISTS employees_acid (
  emp_id     INT,
  name       STRING,
  department STRING,
  salary     DOUBLE,
  country    STRING
)
CLUSTERED BY (emp_id) INTO 4 BUCKETS
STORED AS ORC
TBLPROPERTIES ('transactional'='true');

INSERT INTO employees_acid
SELECT emp_id, name, department, salary, country FROM employees;

UPDATE employees_acid SET salary = salary * 1.10 WHERE department = 'Engineering';
DELETE FROM employees_acid WHERE emp_id = 12;

SELECT * FROM employees_acid WHERE department = 'Engineering';
