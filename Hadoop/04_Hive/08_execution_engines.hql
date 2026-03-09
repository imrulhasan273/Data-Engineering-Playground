-- ─────────────────────────────────────────────────────────────────────────────
-- 08_execution_engines.hql — Hive Execution Engines: Tez & Spark
-- Run: beeline -u "jdbc:hive2://localhost:10000" -f 08_execution_engines.hql
--
-- Hive supports 3 execution engines:
--   1. MapReduce (legacy, default in Hive 1.x)
--   2. Apache Tez  (DAG-based, default in Hive 2.x/3.x)
--   3. Apache Spark (RDD/DataFrame-based)
-- ─────────────────────────────────────────────────────────────────────────────

-- ════════════════════════════════════════════════════════════
-- SECTION 1: MapReduce Engine (legacy)
-- ════════════════════════════════════════════════════════════

-- Switch to MapReduce engine
SET hive.execution.engine=mr;

-- Verify active engine
SET hive.execution.engine;

-- MapReduce characteristics:
-- • Each stage = one MapReduce job → intermediate results written to HDFS
-- • Multi-stage queries: stage1 result → HDFS → stage2 reads → HDFS → ...
-- • High disk I/O, high latency
-- • Stable, battle-tested, universally available

-- Example: multi-join query (3 MR jobs in MR mode, but 1 DAG stage in Tez)
CREATE DATABASE IF NOT EXISTS exec_engine_demo;
USE exec_engine_demo;

CREATE TABLE IF NOT EXISTS orders (
    order_id   INT,
    customer_id INT,
    product_id  INT,
    amount     DOUBLE,
    order_date STRING
) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE;

CREATE TABLE IF NOT EXISTS customers (
    customer_id INT,
    name        STRING,
    region      STRING
) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE;

CREATE TABLE IF NOT EXISTS products (
    product_id  INT,
    product_name STRING,
    category    STRING,
    price       DOUBLE
) ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE;

-- Insert sample data
INSERT INTO orders VALUES
  (1, 101, 201, 500.0, '2024-01-10'),
  (2, 102, 202, 300.0, '2024-01-11'),
  (3, 101, 203, 150.0, '2024-01-12'),
  (4, 103, 201, 700.0, '2024-01-13'),
  (5, 102, 204, 200.0, '2024-01-14');

INSERT INTO customers VALUES
  (101, 'Alice', 'West'),
  (102, 'Bob',   'East'),
  (103, 'Carol', 'West');

INSERT INTO products VALUES
  (201, 'Laptop',  'Electronics', 999.99),
  (202, 'Phone',   'Electronics', 499.99),
  (203, 'Tablet',  'Electronics', 299.99),
  (204, 'Monitor', 'Electronics', 349.99);

-- ════════════════════════════════════════════════════════════
-- SECTION 2: Apache Tez Engine (recommended default)
-- ════════════════════════════════════════════════════════════

SET hive.execution.engine=tez;

-- Verify
SET hive.execution.engine;

-- Tez advantages over MapReduce:
-- • Expresses query as DAG (Directed Acyclic Graph)
-- • Chained operators run in-memory without intermediate HDFS writes
-- • Reuses containers (no JVM startup cost per task)
-- • 2x–10x faster than MapReduce for complex queries

-- ── Tez key settings ──────────────────────────────────────────────────────────

-- Container reuse (avoids JVM startup overhead)
SET hive.tez.container.size=1024;
SET hive.tez.java.opts=-Xmx800m;

-- Vectorized execution (process data in batches of 1024 rows)
SET hive.vectorized.execution.enabled=true;
SET hive.vectorized.execution.reduce.enabled=true;

-- Dynamic partitioning pruning (skip reading non-matching partitions at runtime)
SET hive.tez.dynamic.partition.pruning=true;

-- Reduce auto-parallelism (Tez adjusts reducer count at runtime)
SET hive.tez.auto.reducer.parallelism=true;
SET hive.exec.reducers.bytes.per.reducer=67108864;  -- 64 MB per reducer

-- Tez AM (Application Master) container reuse across queries
SET hive.server2.tez.initialize.default.sessions=true;
SET hive.server2.tez.sessions.per.default.queue=2;

-- ── Query on Tez: multi-table join (single DAG, no intermediate HDFS writes) ──
SELECT
    c.name        AS customer,
    c.region,
    p.product_name,
    p.category,
    o.amount,
    o.order_date
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN products  p ON o.product_id  = p.product_id
ORDER BY o.amount DESC;

-- ── Tez: Map-side join (broadcast small table into memory) ───────────────────
SET hive.auto.convert.join=true;
SET hive.mapjoin.smalltable.filesize=25000000;  -- auto-convert if < 25 MB

-- Hive auto-detects customers (3 rows) is small → broadcasts to all mappers
-- No reduce phase needed for this join!
SELECT c.name, SUM(o.amount) AS total_spend
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.name;

-- ── Tez: Skew join optimization ───────────────────────────────────────────────
SET hive.optimize.skewjoin=true;
SET hive.skewjoin.key=100000;  -- key count threshold to trigger skew handling

-- ── Cost-Based Optimizer (CBO) with Tez ──────────────────────────────────────
SET hive.cbo.enable=true;
SET hive.compute.query.using.stats=true;
SET hive.stats.fetch.column.stats=true;
SET hive.stats.fetch.partition.stats=true;

-- Collect statistics for CBO to use
ANALYZE TABLE orders COMPUTE STATISTICS;
ANALYZE TABLE orders COMPUTE STATISTICS FOR COLUMNS;
ANALYZE TABLE customers COMPUTE STATISTICS;
ANALYZE TABLE customers COMPUTE STATISTICS FOR COLUMNS;
ANALYZE TABLE products COMPUTE STATISTICS;
ANALYZE TABLE products COMPUTE STATISTICS FOR COLUMNS;

-- CBO will now choose optimal join order and join strategy
EXPLAIN
SELECT c.region, p.category, SUM(o.amount) AS revenue
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN products  p ON o.product_id  = p.product_id
GROUP BY c.region, p.category;

-- ── EXPLAIN on Tez ────────────────────────────────────────────────────────────
-- Shows the Tez DAG plan (vertices, edges, operators)
EXPLAIN
SELECT c.region, COUNT(*) AS order_count, SUM(o.amount) AS total
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.region;

-- EXPLAIN EXTENDED for full details
EXPLAIN EXTENDED
SELECT * FROM orders WHERE amount > 300;

-- ════════════════════════════════════════════════════════════
-- SECTION 3: Apache Spark Engine
-- ════════════════════════════════════════════════════════════

SET hive.execution.engine=spark;

-- Verify
SET hive.execution.engine;

-- Spark advantages over Tez:
-- • In-memory computation (no disk I/O between stages by default)
-- • Better for iterative algorithms (ML) and complex transformations
-- • Unified engine for batch + streaming + ML
-- • Hive on Spark uses Spark's Catalyst optimizer internally

-- ── Spark resource settings for Hive ─────────────────────────────────────────
SET hive.spark.client.server.connect.timeout=600000ms;

-- Executor configuration
SET spark.executor.memory=1g;
SET spark.executor.cores=1;
SET spark.executor.instances=2;

-- Driver memory
SET spark.driver.memory=512m;

-- Dynamic allocation (Spark scales executors based on load)
SET spark.dynamicAllocation.enabled=true;
SET spark.dynamicAllocation.minExecutors=1;
SET spark.dynamicAllocation.maxExecutors=4;
SET spark.dynamicAllocation.initialExecutors=2;

-- Shuffle partitions
SET spark.sql.shuffle.partitions=200;

-- ── Spark: same queries, now run on Spark engine ─────────────────────────────
SELECT c.name, SUM(o.amount) AS total_spend
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.name;

-- ── EXPLAIN on Spark shows Spark physical plan ───────────────────────────────
EXPLAIN
SELECT c.region, COUNT(*) AS cnt
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.region;

-- ════════════════════════════════════════════════════════════
-- SECTION 4: Engine Comparison & When to Use Each
-- ════════════════════════════════════════════════════════════

-- Switch back to Tez (recommended for most workloads)
SET hive.execution.engine=tez;

-- ─────────────────────────────────────────────────────────────
-- ENGINE COMPARISON TABLE
-- ─────────────────────────────────────────────────────────────
-- Engine      | Speed          | Memory   | Best For
-- ------------|----------------|----------|---------------------------
-- MapReduce   | Slow (disk I/O)| Low      | Legacy, very large stable jobs
-- Tez         | Fast (2–10x MR)| Medium   | Default, most Hive workloads
-- Spark       | Fastest (RAM)  | High     | Iterative, complex pipelines
-- ─────────────────────────────────────────────────────────────
--
-- RECOMMENDATIONS:
--   • Use Tez  as default — faster than MR, lower memory than Spark
--   • Use Spark for:
--       - Very complex multi-stage queries
--       - Iterative processing (graph, ML pipelines)
--       - When Spark cluster is already running
--   • Use MR only for:
--       - Debugging/compatibility
--       - Very memory-constrained clusters
-- ─────────────────────────────────────────────────────────────

-- ════════════════════════════════════════════════════════════
-- SECTION 5: Hive Metastore as Universal Catalog
-- ════════════════════════════════════════════════════════════

-- Hive Metastore stores table metadata independently of the execution engine.
-- Other tools can read from the same Metastore:

-- Spark reads Hive Metastore:
--   spark = SparkSession.builder \
--       .config("spark.sql.catalogImplementation", "hive") \
--       .config("hive.metastore.uris", "thrift://hive:9083") \
--       .enableHiveSupport() \
--       .getOrCreate()
--   df = spark.sql("SELECT * FROM exec_engine_demo.orders")

-- Presto/Trino reads Hive Metastore (hive.properties connector):
--   connector.name=hive-hadoop2
--   hive.metastore.uri=thrift://hive:9083

-- This makes the Metastore a universal metadata store across the ecosystem.

-- Show all tables in this database (visible from any engine)
USE exec_engine_demo;
SHOW TABLES;
DESCRIBE FORMATTED orders;

-- Cleanup
DROP DATABASE IF EXISTS exec_engine_demo CASCADE;
