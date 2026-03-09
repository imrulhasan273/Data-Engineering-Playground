-- ─────────────────────────────────────────────────────────────────────────────
-- 04_partitioning.hql — Hive Static & Dynamic Partitioning
-- Partitioning splits data into subdirectories by column value
-- → Query only reads relevant partitions (partition pruning)
-- ─────────────────────────────────────────────────────────────────────────────

USE playground;

-- ── 1. Create a Partitioned Table ─────────────────────────────────────────────
-- Partition by 'year' and 'quarter' — NOT stored as regular columns
CREATE TABLE IF NOT EXISTS sales_partitioned (
  sale_id  INT,
  category STRING,
  amount   DOUBLE
)
PARTITIONED BY (year INT, quarter STRING)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS ORC;

-- ── HDFS structure created:
-- /user/hive/warehouse/playground.db/sales_partitioned/
--   year=2023/quarter=Q1/
--   year=2023/quarter=Q2/
--   year=2024/quarter=Q1/

-- ── 2. Static Partitioning ────────────────────────────────────────────────────
-- You explicitly specify the partition value in the INSERT
SET hive.exec.dynamic.partition.mode=nonstrict;

INSERT INTO sales_partitioned PARTITION (year=2023, quarter='Q1')
VALUES (1, 'Electronics', 1500.00),
       (2, 'Clothing',    250.00);

INSERT INTO sales_partitioned PARTITION (year=2023, quarter='Q2')
VALUES (3, 'Electronics', 2200.00),
       (4, 'Food',        180.00);

INSERT INTO sales_partitioned PARTITION (year=2023, quarter='Q3')
VALUES (5, 'Electronics', 3100.00),
       (6, 'Clothing',    420.00);

INSERT INTO sales_partitioned PARTITION (year=2023, quarter='Q4')
VALUES (7, 'Electronics', 4500.00),
       (8, 'Food',        310.00);

INSERT INTO sales_partitioned PARTITION (year=2024, quarter='Q1')
VALUES (9,  'Electronics', 1800.00),
       (10, 'Clothing',    290.00);

-- ── 3. Show Partitions ────────────────────────────────────────────────────────
SHOW PARTITIONS sales_partitioned;
-- Output: year=2023/quarter=Q1, year=2023/quarter=Q2, ...

-- ── 4. Partition Pruning (queries that use partition columns are fast) ─────────
-- This query reads ONLY year=2023/quarter=Q1 partition
EXPLAIN
SELECT * FROM sales_partitioned
WHERE year = 2023 AND quarter = 'Q1';

SELECT * FROM sales_partitioned
WHERE year = 2023 AND quarter = 'Q1';

-- Aggregate across specific partitions only
SELECT quarter, SUM(amount) AS total
FROM   sales_partitioned
WHERE  year = 2023
GROUP BY quarter
ORDER BY quarter;

-- ── 5. Dynamic Partitioning ───────────────────────────────────────────────────
-- Hive automatically determines partition value from data
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;
SET hive.exec.max.dynamic.partitions=1000;
SET hive.exec.max.dynamic.partitions.pernode=200;

-- Source: external raw sales table
CREATE EXTERNAL TABLE IF NOT EXISTS sales_raw (
  sale_id  INT,
  year     INT,
  quarter  STRING,
  category STRING,
  amount   DOUBLE
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/hive/raw/sales';

-- LOAD from HDFS
-- (The file was uploaded in 01_setup.sh)

-- Dynamic INSERT: Hive reads 'year' and 'quarter' from the data
CREATE TABLE IF NOT EXISTS sales_dynamic_part
LIKE sales_partitioned;

INSERT INTO sales_dynamic_part PARTITION (year, quarter)
SELECT sale_id, category, amount, year, quarter
FROM   sales_raw;
-- Note: partition columns MUST come last in the SELECT

SHOW PARTITIONS sales_dynamic_part;

-- ── 6. Add & Drop Partitions Manually ────────────────────────────────────────
-- Add a new empty partition
ALTER TABLE sales_partitioned
  ADD IF NOT EXISTS PARTITION (year=2024, quarter='Q2');

-- Point partition to a specific HDFS path
ALTER TABLE sales_partitioned
  ADD IF NOT EXISTS PARTITION (year=2024, quarter='Q3')
  LOCATION '/hive/raw/sales_q3_2024';

-- Drop a partition (removes metadata; for external tables keeps HDFS data)
ALTER TABLE sales_partitioned
  DROP IF EXISTS PARTITION (year=2024, quarter='Q3');

SHOW PARTITIONS sales_partitioned;

-- ── 7. MSCK REPAIR (recover partitions from HDFS) ────────────────────────────
-- If partitions were added to HDFS manually without Hive, run this to sync
MSCK REPAIR TABLE sales_dynamic_part;
