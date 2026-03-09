-- ─────────────────────────────────────────────────────────────────────────────
-- 06_joins.hql — All Hive Join Types
-- ─────────────────────────────────────────────────────────────────────────────

USE playground;

-- Setup lookup table
CREATE TABLE IF NOT EXISTS departments_lookup (
  dept_name  STRING,
  division   STRING,
  location   STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS ORC;

INSERT INTO departments_lookup VALUES
  ('Engineering', 'Technology',  'San Francisco'),
  ('Marketing',   'Business',    'New York'),
  ('HR',          'Operations',  'Chicago'),
  ('Finance',     'Business',    'New York');

-- ── 1. INNER JOIN ────────────────────────────────────────────────────────────
-- Only rows matching in BOTH tables
SELECT e.name, e.salary, d.location
FROM   employees e
JOIN   departments_lookup d
  ON   e.department = d.dept_name;

-- ── 2. LEFT OUTER JOIN ───────────────────────────────────────────────────────
-- All rows from left table; NULLs for non-matching right rows
SELECT e.name, e.department, d.location
FROM   employees e
LEFT OUTER JOIN departments_lookup d
  ON e.department = d.dept_name;

-- ── 3. RIGHT OUTER JOIN ──────────────────────────────────────────────────────
-- All rows from right table; NULLs for non-matching left rows
SELECT e.name, d.dept_name, d.location
FROM   employees e
RIGHT OUTER JOIN departments_lookup d
  ON e.department = d.dept_name;

-- ── 4. FULL OUTER JOIN ───────────────────────────────────────────────────────
-- All rows from both tables; NULLs where no match
SELECT e.name, d.dept_name, d.location
FROM   employees e
FULL OUTER JOIN departments_lookup d
  ON e.department = d.dept_name;

-- ── 5. CROSS JOIN ────────────────────────────────────────────────────────────
-- Cartesian product (every row × every row)
SELECT e.name, d.dept_name
FROM   employees e
CROSS JOIN departments_lookup d
LIMIT 20;

-- ── 6. LEFT SEMI JOIN ────────────────────────────────────────────────────────
-- Equivalent to IN subquery — returns left rows WHERE a match exists
-- More efficient than EXISTS/IN in Hive
SELECT e.name, e.salary
FROM   employees e
LEFT SEMI JOIN departments_lookup d
  ON e.department = d.dept_name;

-- ── 7. Map-Side Join (Broadcast Join) ────────────────────────────────────────
-- Small table is loaded into memory on each mapper — no reduce phase needed
-- Automatically applied if table < hive.mapjoin.smalltable.filesize (25MB default)
SET hive.auto.convert.join=true;
SET hive.mapjoin.smalltable.filesize=25000000;

-- Hint to force map join (/*+ MAPJOIN(d) */)
SELECT /*+ MAPJOIN(d) */ e.name, e.salary, d.location
FROM   employees e
JOIN   departments_lookup d
  ON   e.department = d.dept_name;

-- ── 8. Multi-table JOIN ───────────────────────────────────────────────────────
SELECT e.name, e.salary, d.location, s.amount
FROM   employees e
JOIN   departments_lookup d  ON e.department = d.dept_name
JOIN   sales_partitioned s   ON e.department = s.category
WHERE  s.year = 2023 AND s.quarter = 'Q1'
LIMIT 10;

-- ── 9. Self JOIN ─────────────────────────────────────────────────────────────
-- Find employees with salary above department average
SELECT e1.name, e1.department, e1.salary, dept_avg.avg_sal
FROM   employees e1
JOIN (
  SELECT department, AVG(salary) AS avg_sal
  FROM   employees
  GROUP BY department
) dept_avg ON e1.department = dept_avg.department
WHERE  e1.salary > dept_avg.avg_sal
ORDER BY e1.department, e1.salary DESC;

-- ── 10. Subquery (correlated) ────────────────────────────────────────────────
SELECT name, salary, department
FROM   employees
WHERE  salary > (
  SELECT AVG(salary)
  FROM   employees
)
ORDER BY salary DESC;
