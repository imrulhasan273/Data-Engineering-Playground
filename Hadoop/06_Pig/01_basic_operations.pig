-- ─────────────────────────────────────────────────────────────────────────────
-- 01_basic_operations.pig — Pig Latin fundamentals
-- Run: pig -x mapreduce 01_basic_operations.pig
--   or: pig -x local 01_basic_operations.pig   (local mode, no HDFS needed)
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. LOAD — Read data from HDFS ────────────────────────────────────────────
employees = LOAD '/hive/raw/employees/employees.csv'
  USING PigStorage(',')
  AS (emp_id:int, name:chararray, department:chararray,
      salary:double, hire_date:chararray, country:chararray);

-- DUMP displays contents (use only for debugging; triggers a MapReduce job)
-- DUMP employees;

DESCRIBE employees;   -- show schema

-- ── 2. FILTER — WHERE clause ─────────────────────────────────────────────────
engineers = FILTER employees BY department == 'Engineering';
DUMP engineers;

high_earners = FILTER employees BY salary > 80000 AND country == 'US';
DUMP high_earners;

-- ── 3. FOREACH ... GENERATE — SELECT / Transform ──────────────────────────────
-- Select specific columns
names_salaries = FOREACH employees GENERATE name, salary;
DUMP names_salaries;

-- Compute new column
with_monthly = FOREACH employees GENERATE
  name,
  salary,
  salary / 12.0 AS monthly_salary:double,
  UPPER(name)   AS upper_name:chararray;
DUMP with_monthly;

-- ── 4. ORDER BY ──────────────────────────────────────────────────────────────
sorted = ORDER employees BY salary DESC;
top3   = LIMIT sorted 3;
DUMP top3;

-- ── 5. GROUP BY ──────────────────────────────────────────────────────────────
grouped = GROUP employees BY department;
-- 'grouped' is: (department, {bag of tuples})

DESCRIBE grouped;

-- Aggregate per group
dept_stats = FOREACH grouped GENERATE
  group                     AS department,
  COUNT(employees)          AS headcount,
  AVG(employees.salary)     AS avg_salary,
  MAX(employees.salary)     AS max_salary,
  MIN(employees.salary)     AS min_salary,
  SUM(employees.salary)     AS total_salary;

DUMP dept_stats;

-- ── 6. STORE — Write output to HDFS ─────────────────────────────────────────
STORE dept_stats INTO '/pig/output/dept_stats'
  USING PigStorage(',');

-- ── 7. JOIN ──────────────────────────────────────────────────────────────────
departments = LOAD '/hive/raw/departments/departments.csv'
  USING PigStorage(',')
  AS (dept_name:chararray, division:chararray, location:chararray);

joined = JOIN employees BY department, departments BY dept_name;

result = FOREACH joined GENERATE
  employees::name       AS name,
  employees::salary     AS salary,
  departments::location AS location;

DUMP result;

-- ── 8. DISTINCT ──────────────────────────────────────────────────────────────
countries = FOREACH employees GENERATE country;
unique_countries = DISTINCT countries;
DUMP unique_countries;

-- ── 9. UNION ─────────────────────────────────────────────────────────────────
us_staff = FILTER employees BY country == 'US';
uk_staff = FILTER employees BY country == 'UK';
combined = UNION us_staff, uk_staff;
DUMP combined;

-- ── 10. CROSS (Cartesian Product) ────────────────────────────────────────────
-- small_a = LIMIT employees 2;
-- small_b = LOAD ... ;
-- crossed = CROSS small_a, small_b;   -- use carefully on large data

-- ── 11. SPLIT ────────────────────────────────────────────────────────────────
-- Split one relation into multiple based on conditions
SPLIT employees INTO
  senior    IF salary >= 90000,
  mid_level IF salary >= 70000 AND salary < 90000,
  junior    OTHERWISE;

DUMP senior;
DUMP mid_level;
DUMP junior;
