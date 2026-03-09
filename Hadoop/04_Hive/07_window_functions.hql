-- ─────────────────────────────────────────────────────────────────────────────
-- 07_window_functions.hql — Hive Window (Analytic) Functions
-- ─────────────────────────────────────────────────────────────────────────────

USE playground;

-- ── 1. RANK Functions ────────────────────────────────────────────────────────
SELECT
  name, department, salary,
  ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS row_num,
  -- Unique sequential number within each partition
  RANK()       OVER (PARTITION BY department ORDER BY salary DESC) AS rank,
  -- Gaps for ties (1,1,3,4)
  DENSE_RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS dense_rank,
  -- No gaps for ties (1,1,2,3)
  PERCENT_RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS pct_rank
  -- (rank-1)/(total-1)
FROM employees;

-- ── 2. Top-N per Group ────────────────────────────────────────────────────────
-- Top 2 earners per department
SELECT name, department, salary
FROM (
  SELECT name, department, salary,
    ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS rn
  FROM employees
) ranked
WHERE rn <= 2;

-- ── 3. LAG / LEAD ────────────────────────────────────────────────────────────
-- Compare to previous/next row within the window
SELECT
  emp_id, name, salary,
  LAG(salary,  1, 0) OVER (ORDER BY emp_id) AS prev_salary,
  LEAD(salary, 1, 0) OVER (ORDER BY emp_id) AS next_salary,
  salary - LAG(salary, 1, salary) OVER (ORDER BY emp_id) AS salary_diff
FROM employees
ORDER BY emp_id;

-- ── 4. FIRST_VALUE / LAST_VALUE ───────────────────────────────────────────────
SELECT
  name, department, salary,
  FIRST_VALUE(salary) OVER (PARTITION BY department ORDER BY salary DESC
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS dept_max_salary,
  LAST_VALUE(salary)  OVER (PARTITION BY department ORDER BY salary DESC
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS dept_min_salary
FROM employees;

-- ── 5. Running Totals / Moving Averages ───────────────────────────────────────
SELECT
  name, department, salary,
  SUM(salary) OVER (PARTITION BY department
    ORDER BY salary
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total,
  AVG(salary) OVER (PARTITION BY department
    ORDER BY salary
    ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS moving_avg_3
FROM employees
ORDER BY department, salary;

-- ── 6. Cumulative Distribution ───────────────────────────────────────────────
SELECT
  name, salary,
  CUME_DIST() OVER (ORDER BY salary) AS cumulative_pct,
  -- What fraction of rows have salary <= this salary
  NTILE(4)    OVER (ORDER BY salary) AS salary_quartile
  -- Divide into N roughly equal groups
FROM employees
ORDER BY salary;

-- ── 7. Frame Specifications ───────────────────────────────────────────────────
-- ROWS BETWEEN: physical rows
-- RANGE BETWEEN: logical range (by value)
SELECT
  emp_id, salary,
  SUM(salary) OVER (ORDER BY salary
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)  AS sum_last_3_rows,
  SUM(salary) OVER (ORDER BY salary
    ROWS BETWEEN CURRENT ROW AND 2 FOLLOWING)  AS sum_next_3_rows,
  AVG(salary) OVER (ORDER BY salary
    RANGE BETWEEN 5000 PRECEDING AND 5000 FOLLOWING) AS avg_within_5k_range
FROM employees
ORDER BY salary;

-- ── 8. Named Windows (reuse window definition) ────────────────────────────────
SELECT
  name, department, salary,
  AVG(salary)   OVER dept_window AS dept_avg,
  MAX(salary)   OVER dept_window AS dept_max,
  MIN(salary)   OVER dept_window AS dept_min,
  salary - AVG(salary) OVER dept_window AS delta_from_avg
FROM employees
WINDOW dept_window AS (PARTITION BY department ORDER BY salary
  ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING);
