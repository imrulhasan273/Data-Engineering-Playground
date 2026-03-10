# Hadoop Concepts Reference

A deep-dive reference covering every major concept in the Hadoop ecosystem. Read this alongside the hands-on exercises.

---

## Table of Contents

1. [HDFS — Distributed File System](#1-hdfs)
2. [MapReduce — Batch Processing](#2-mapreduce)
3. [YARN — Resource Management](#3-yarn)
4. [Hive — SQL on Hadoop](#4-hive)
5. [HBase — NoSQL Store](#5-hbase)
6. [Pig — Data Flow Language](#6-pig)
7. [Sqoop — Data Transfer](#7-sqoop)
8. [Spark on YARN](#8-spark-on-yarn)
9. [Advanced Topics](#9-advanced-topics)

---

## 1. HDFS

### Architecture

```
Write path:
  Client → NameNode (get block locations)
         → DataNode 1 (write block, pipeline to DN2, DN3)

Read path:
  Client → NameNode (get block locations)
         → nearest DataNode (fetch block)
```

### NameNode
- Stores **all filesystem metadata** in memory: directory tree, file-to-block mapping, block-to-DataNode mapping
- Persists metadata to disk as `fsimage` + `edits` log
- **Single point of failure** → use HA with standby NameNode + JournalNodes
- Rule of thumb: ~150 bytes of NameNode RAM per file/block/directory

### DataNode
- Stores actual **data blocks** on local disk
- Reports block inventory to NameNode on startup (block report)
- Sends heartbeats every 3 seconds; declared dead after 10 minutes
- Replication pipeline: DN1 → DN2 → DN3 (writes flow through, ACKs flow back)

### Blocks
| Property | Default | Notes |
|----------|---------|-------|
| Block size | 128 MB | Set per file with `-Ddfs.blocksize=` |
| Replication | 3 | Set per file with `-Ddfs.replication=` |
| Block naming | `blk_<id>_<gen>` | Stored under `dfs.datanode.data.dir` |

### Replication Placement (Rack Awareness)
```
Default 3-replica placement:
  Replica 1 → same node as writer (or random if remote client)
  Replica 2 → different rack
  Replica 3 → same rack as replica 2, different node
```
This tolerates 1 complete rack failure while minimizing cross-rack write bandwidth.

### HDFS Federation
Multiple independent NameNodes sharing DataNodes:
- Each NameNode manages a separate **namespace** + **block pool**
- Scales metadata beyond a single NameNode's RAM
- **ViewFs** or **Router-Based Federation** provides a unified namespace

### High Availability (HA)
```
Active NN ←→ Standby NN
    ↓             ↓
  JournalNode Quorum (3+)   ← shared edit log
    ↓
  ZooKeeper (leader election)
  ↓
  ZKFC (ZooKeeper Failover Controller) on each NN
```
Automatic failover in ~30 seconds when Active NN dies.

### Key HDFS Properties (hdfs-site.xml)
| Property | Description |
|----------|-------------|
| `dfs.replication` | Default replication factor (3) |
| `dfs.blocksize` | Default block size (128m) |
| `dfs.namenode.handler.count` | RPC threads on NameNode (default 10) |
| `dfs.datanode.data.dir` | DataNode storage directories |
| `dfs.namenode.name.dir` | NameNode metadata directory |
| `dfs.permissions.enabled` | POSIX-like permissions (true) |
| `dfs.namenode.acls.enabled` | Enable ACLs (false by default) |

---

## 2. MapReduce

### Execution Flow

```
1. Job Submission
   Client → ResourceManager → ApplicationMaster launched

2. Map Phase
   Input → InputSplit (1 per mapper) → RecordReader → map()
   Each mapper reads ~1 HDFS block (data locality)

3. Shuffle & Sort
   Mapper output → partitioned by key (hash % numReducers)
   → sorted by key within each partition
   → spilled to disk, merged

4. Reduce Phase
   Reducer reads sorted partitions from all mappers
   → reduce() called once per unique key
   → output written to HDFS
```

### Combiner
A **mini-reducer** that runs locally on the mapper node before shuffle:
- Reduces network I/O (less data to shuffle)
- Only valid for **commutative + associative** operations (sum, max, min — not average)
- Same class as reducer for simple aggregations

### Partitioner
Determines which reducer gets each key:
- Default: `HashPartitioner` — `hash(key) % numReducers`
- Custom: extend `Partitioner` class to control data distribution
- Used to prevent data skew (one reducer getting all the work)

### Python Hadoop Streaming
```
Input file → Hadoop splits into lines
          → pipes each line to mapper.py via stdin
          → mapper writes key\tvalue to stdout
          → Hadoop sorts all output by key (shuffle)
          → pipes sorted lines to reducer.py via stdin
          → reducer writes final key\tvalue to stdout
          → written to HDFS output directory
```

Key environment variables available in streaming scripts:
| Variable | Value |
|----------|-------|
| `map_input_file` | HDFS path of current input file |
| `mapreduce_task_id` | Current task ID |
| `mapreduce_map_input_start` | Byte offset of current split |

### MapReduce Tuning
| Parameter | Effect |
|-----------|--------|
| `mapreduce.job.maps` | Number of map tasks (hint; actual = num splits) |
| `mapreduce.job.reduces` | Number of reduce tasks (default 1) |
| `mapreduce.task.io.sort.mb` | Sort buffer size per mapper (100 MB) |
| `mapreduce.reduce.shuffle.parallelcopies` | Parallel copy threads (5) |
| `mapreduce.map.memory.mb` | Container memory for mappers (1024) |
| `mapreduce.reduce.memory.mb` | Container memory for reducers (1024) |

---

## 3. YARN

### Components

```
ResourceManager
├── Scheduler          — allocates CPU/memory containers
│   ├── FIFO Scheduler       (simple, no preemption)
│   ├── Capacity Scheduler   (multi-tenant, default)
│   └── Fair Scheduler       (equal sharing over time)
└── ApplicationsManager
    └── Accepts job submissions, starts ApplicationMaster

NodeManager (one per worker node)
├── Launches containers (JVMs or any process)
├── Monitors CPU/memory usage
└── Reports health to ResourceManager

ApplicationMaster (one per job)
├── Negotiates containers from Scheduler
├── Tracks task progress
└── Handles failures (re-launches failed tasks)
```

### Container
The fundamental unit of resource allocation in YARN:
- A container = `<memory_mb, vcores>` running on a NodeManager
- Every Map task, every Reduce task, every Spark executor = one container
- ApplicationMaster itself runs in a container

### Capacity Scheduler Queues
```xml
<!-- capacity-scheduler.xml -->
<property>
  <name>yarn.scheduler.capacity.root.queues</name>
  <value>default,engineering,analytics</value>
</property>
<property>
  <name>yarn.scheduler.capacity.root.engineering.capacity</name>
  <value>50</value>  <!-- 50% of cluster -->
</property>
```

### Application States
`NEW → ACCEPTED → RUNNING → FINISHED (SUCCEEDED | FAILED | KILLED)`

### Key YARN Properties (yarn-site.xml)
| Property | Description |
|----------|-------------|
| `yarn.nodemanager.resource.memory-mb` | Total memory per node for containers |
| `yarn.nodemanager.resource.cpu-vcores` | Total vCores per node for containers |
| `yarn.scheduler.minimum-allocation-mb` | Smallest container (1024 MB) |
| `yarn.scheduler.maximum-allocation-mb` | Largest container (8192 MB) |
| `yarn.log-aggregation-enable` | Collect logs from all nodes (true) |

---

## 4. Hive

### Architecture

```
Client (beeline / JDBC)
    ↓
HiveServer2
    ├── Parser + Analyzer   (SQL → AST → Logical Plan)
    ├── Optimizer           (partition pruning, join reorder, etc.)
    └── Execution Engine    (Tez / MR / Spark)
         ↓
    HDFS (data) + Metastore (PostgreSQL 17 — table schemas)
```

### Table Types

| Type | HDFS Data Ownership | Drop behavior |
|------|---------------------|---------------|
| Managed (Internal) | Hive owns it | DROP deletes HDFS data |
| External | User owns it | DROP keeps HDFS data |

**Rule**: always use **External** tables for production data. Use managed tables only for intermediate/temp tables.

### Storage Formats Comparison

| Format | Type | Compression | Best For |
|--------|------|-------------|----------|
| TextFile | Row | Optional | Import/export, interop |
| SequenceFile | Row | Yes | MapReduce intermediate |
| ORC | Columnar | Yes (Snappy/Zlib) | Hive analytics, ACID |
| Parquet | Columnar | Yes (Snappy/Gzip) | Spark/Presto interop |
| Avro | Row | Optional | Schema evolution, Kafka |

**ORC** is the best choice for pure Hive workloads. **Parquet** for multi-engine environments.

### Partitioning vs Bucketing

| | Partitioning | Bucketing |
|-|-------------|-----------|
| How | Subdirectory per partition value | Hash-split into N files |
| Benefit | Partition pruning (skip irrelevant data) | Uniform sampling, bucket map join |
| When to use | Low-cardinality cols (date, country, status) | High-cardinality join keys |
| Files | 1+ per partition | Exactly N files total |

**Don't** partition on high-cardinality columns (e.g., user_id) — creates millions of tiny files (small file problem).

### Query Execution Engines

| Engine | Use Case | Config |
|--------|----------|--------|
| MapReduce | Legacy, large stable batches | `SET hive.execution.engine=mr;` |
| Tez | Default, faster DAG execution | `SET hive.execution.engine=tez;` |
| Spark | Spark cluster available | `SET hive.execution.engine=spark;` |

### Hive ACID (Transactions)
Required for UPDATE/DELETE:
- Table must be ORC + `'transactional'='true'`
- Enable: `SET hive.txn.manager=org.apache.hadoop.hive.ql.lockmgr.DbTxnManager;`
- Compaction (minor/major) merges delta files to maintain read performance

### HiveQL Performance Tips
```sql
-- 1. Use partition columns in WHERE (enables partition pruning)
SELECT * FROM sales WHERE year=2024 AND month='Jan';

-- 2. Use map-side join for small tables (< 25MB)
SET hive.auto.convert.join=true;

-- 3. Enable vectorization (batch process 1024 rows at a time)
SET hive.vectorized.execution.enabled=true;

-- 4. Use ORC with statistics
ANALYZE TABLE employees COMPUTE STATISTICS FOR COLUMNS;

-- 5. Set parallelism
SET hive.exec.parallel=true;
SET hive.exec.parallel.thread.number=8;
```

---

## 5. HBase

### Data Model

```
Table
└── Row (sorted by RowKey)
    └── Column Family (stored together on disk)
        └── Column (qualifier)
            └── Cell value (with timestamp/version)

Example:
Row key: "user:001"
  cf_profile:name       = "Alice"      @ t=100
  cf_profile:name       = "Alice Chen" @ t=90   (previous version)
  cf_profile:country    = "US"         @ t=100
  cf_activity:last_login = "2024-01"   @ t=100
```

### Row Key Design — Most Important Decision
HBase is sorted by row key. Bad row keys cause hotspotting (all writes go to one region).

| Pattern | Problem | Fix |
|---------|---------|-----|
| Sequential IDs (1,2,3...) | All writes hit last region | Salt prefix: `hash(id) + id` |
| Timestamps as prefix | All writes hit latest region | Reverse timestamp: `Long.MAX - ts` |
| Customer ID prefix | Good for per-customer queries | ✓ |

**Good row key examples:**
```
user:001                          # point lookup
order:2024-01-15:user:001         # time-range scan per user
sensor:NYC-01:2024-01-15T10:00:00 # time-range scan per sensor
```

### Architecture

```
HMaster
├── Assigns regions to RegionServers
└── Handles schema changes, failover

RegionServer (worker)
├── Serves 10-1000 regions
└── Region
    ├── MemStore (write buffer, 64-128MB)
    └── HFiles (immutable, HDFS)

Write path: RowKey → RegionServer → WAL → MemStore
             (MemStore flush → HFile when full or size threshold)

Read path:  RowKey → RegionServer → BlockCache + MemStore + HFiles
```

### Column Family Design Rules
- **Minimize column families** (1-3 is normal) — each CF is a separate HFile
- Put columns accessed together in the **same CF**
- Configure `VERSIONS` per CF (default 1 — only keep latest value)
- Configure `TTL` for automatic expiry
- Configure `COMPRESSION` per CF (SNAPPY for speed, ZLIB for ratio)

### HBase vs Hive

| | HBase | Hive |
|-|-------|------|
| Access pattern | Random read/write (ms latency) | Full scans, analytics (minutes) |
| Data model | Key-value, flexible columns | Structured, schema-on-read |
| Query language | Shell, Java/Python API | SQL (HiveQL) |
| Use case | OLTP, real-time lookups | OLAP, batch analytics |

---

## 6. Pig

### Execution Modes
| Mode | Command | Use |
|------|---------|-----|
| MapReduce | `pig -x mapreduce` | Production, runs on cluster |
| Local | `pig -x local` | Development, no HDFS needed |
| Tez | `pig -x tez` | Faster DAG execution |

### Pig Latin Execution Model
Pig is **lazy** — statements build a logical plan. Execution only triggers on:
- `DUMP` (show results)
- `STORE` (write to HDFS)
- `EXPLAIN` (show plan without running)

### Pig vs Hive
| | Pig | Hive |
|-|-----|------|
| Language | Procedural (data flow) | Declarative (SQL) |
| Best for | ETL pipelines, complex transforms | Analytics queries, reporting |
| Schema | Schema-on-use (flexible) | Schema-on-read (structured) |
| Nesting | Native support (bags, tuples) | Limited |

---

## 7. Sqoop

### Architecture
```
Sqoop (client tool)
→ Generates Java code to read JDBC source
→ Launches MapReduce job (map-only, no reduce)
→ Each mapper reads a range of rows (split by --split-by column)
→ Writes to HDFS / Hive / HBase
```

### Import Modes
| Mode | Description | When |
|------|-------------|------|
| Full import | Read entire table | Initial load |
| Incremental append | New rows since last run | `--check-column id --last-value N` |
| Incremental lastmodified | Updated rows | `--check-column updated_at` |
| Free-form query | Custom SQL | Complex joins/filters |

### Key Sqoop Options
```bash
sqoop import \
  --connect jdbc:postgresql://postgres:5432/db \
  --driver org.postgresql.Driver \
  --username user --password pass \
  --table employees \
  --target-dir /hdfs/path \
  --num-mappers 4 \           # parallelism
  --split-by emp_id \         # split column for parallelism
  --fields-terminated-by ',' \
  --null-string '' \          # replace NULL strings
  --null-non-string -1 \      # replace NULL numerics
  --compress \                # enable compression
  --compression-codec snappy
```

---

## 8. Spark on YARN

### Deploy Modes

```
Client mode:  (development/debugging)
  Your machine → YARN → ApplicationMaster on cluster
                      → Executors on cluster
  Driver runs on YOUR machine (sees logs in terminal)

Cluster mode: (production)
  Your machine → YARN → ApplicationMaster = Driver on cluster
                      → Executors on cluster
  Submit and detach; monitor via YARN UI
```

### Resource Configuration
```bash
spark-submit \
  --master yarn \
  --deploy-mode client \
  --num-executors 4 \          # total executor processes
  --executor-cores 2 \         # CPU cores per executor
  --executor-memory 2g \       # RAM per executor
  --driver-memory 1g \         # Driver RAM
  --conf spark.default.parallelism=8 \    # default partitions
  --conf spark.sql.shuffle.partitions=8 \ # partitions after shuffle
```

**Rule of thumb**: `num-executors × executor-cores = total vCores used`

### Spark RDD vs DataFrame vs Dataset

| API | Language | Optimization | Use |
|-----|----------|-------------|-----|
| RDD | Python/Java/Scala | None (manual) | Low-level, custom logic |
| DataFrame | Python/Java/Scala | Catalyst optimizer | SQL-style analytics |
| Dataset | Java/Scala only | Catalyst + encoder | Type-safe DataFrame |

**Always prefer DataFrame API** in Python — it uses the Catalyst optimizer which rewrites your query for performance.

### Reading/Writing HDFS in Spark
```python
# Read
df = spark.read.csv("hdfs:///path/to/data", header=True, inferSchema=True)
df = spark.read.parquet("hdfs:///path/to/parquet")
df = spark.read.orc("hdfs:///path/to/orc")

# Write
df.write.mode("overwrite").parquet("hdfs:///output/path")
df.write.mode("append").partitionBy("year","month").parquet("hdfs:///output/path")
df.write.mode("overwrite").saveAsTable("hive_db.table_name")  # write to Hive
```

---

## 9. Advanced Topics

### Small Files Problem
**Problem**: HDFS NameNode stores ~150 bytes of metadata per file. 1 million 1KB files = same NameNode memory as 1 million 1GB files.
**Solutions**:
- HAR (Hadoop Archive): `hadoop archive -archiveName data.har -p /input /output`
- SequenceFile: combine small files into one with key=filename
- CombineFileInputFormat: process multiple files per mapper
- Hive: avoid creating too many partitions

### Data Skew in MapReduce/Hive
**Problem**: One reducer gets 90% of the data (hot key).
**Solutions**:
```sql
-- Hive: enable skew join optimization
SET hive.optimize.skewjoin=true;
SET hive.skewjoin.key=100000;  -- threshold for "skewed" key

-- MapReduce: add salt to skewed keys in mapper
-- key "hadoop" becomes "hadoop_0", "hadoop_1", etc.
-- reducer strips salt and re-aggregates
```

### Compression in Hadoop
| Codec | Ratio | Speed | Splittable | Use |
|-------|-------|-------|-----------|-----|
| Snappy | Medium | Very fast | No | Intermediate data, ORC/Parquet inner |
| LZ4 | Medium | Fastest | No | High-throughput pipelines |
| Gzip | High | Slow | No | Cold archival |
| Bzip2 | Highest | Very slow | **Yes** | Text files needing splitting |
| LZO | Medium | Fast | Yes (w/index) | Large text files |

**Key rule**: For text InputFormat files you plan to split across mappers, use **bzip2** or **LZO** (with index). For ORC/Parquet, compression is handled internally — use Snappy.

### Erasure Coding (Hadoop 3.x)
Replaces 3x replication with parity blocks:
```
RS(6,3): 6 data blocks + 3 parity blocks
         Overhead: 1.5x  (vs 3x for replication)
         Tolerance: 3 block failures

RS(3,2): 3 data + 2 parity
         Overhead: 1.67x
         Works on clusters with ≥ 5 DataNodes
```
Best for: large, cold/archival data. Not ideal for small files or frequently accessed data.

### HDFS Transparent Encryption
```
Key Management Server (KMS) → stores Encryption Zone Keys (EZK)
NameNode → maps directory to EZK (encryption zone)
Client → gets DEK (Data Encryption Key) from KMS
       → encrypts block before writing to DataNode
DataNode → stores ciphertext only
```
Data is encrypted/decrypted **at the client** — even cluster admins can't read data without KMS access.
