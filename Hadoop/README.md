# Hadoop Learning Playground

A complete, sequential hands-on guide to **Apache Hadoop 3.x** — from installation to advanced features. All exercises run on a local Docker cluster.

---

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| Docker Desktop | Run the cluster | https://www.docker.com/products/docker-desktop/ |
| Git Bash / WSL2 | Run `.sh` scripts on Windows | Bundled with Git / Windows Store |
| Python 3.8+ | MapReduce scripts, HBase API | https://www.python.org/ |

---

## Start the Cluster (Do This First!)

```bash
cd Hadoop/00_Setup
docker compose up -d       # first run: downloads ~4 GB of images
docker compose ps          # verify all containers are running
bash verify_setup.sh       # smoke test
```

**Web UIs** (open after cluster starts):

| UI | URL |
|----|-----|
| HDFS NameNode | http://localhost:9870 |
| YARN Jobs | http://localhost:8088 |
| MapReduce History | http://localhost:19888 |
| Spark History | http://localhost:18080 |
| HBase Master | http://localhost:16010 |

---

## Learning Path (Sequential)

Work through the modules in order — each builds on the previous.

```
00_Setup → 01_HDFS → 02_MapReduce → 03_YARN → 04_Hive
                                                  ↓
                              09_Advanced ← 08_Spark ← 07_Sqoop ← 06_Pig ← 05_HBase
```

---

## Module Overview

### [00_Setup](00_Setup/) — Cluster Setup
Docker Compose cluster with HDFS, YARN, Hive, HBase, Spark, MySQL.

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Full cluster definition |
| `.env` | Port configuration |
| `verify_setup.sh` | Smoke tests |

---

### [01_HDFS](01_HDFS/) — Distributed File System

| Script | Topics Covered |
|--------|----------------|
| `01_basic_operations.sh` | mkdir, put, get, cat, mv, cp, rm, du, count |
| `02_file_permissions.sh` | chmod, chown, chgrp, ACLs (setfacl/getfacl) |
| `03_replication_snapshots.sh` | setrep, createSnapshot, deleteSnapshot, snapshotDiff |
| `04_advanced_features.sh` | fsck, quota, safe mode, trash, admin commands |

```bash
docker exec -it hadoop-namenode bash
# Then run any script directly
bash /tmp/01_basic_operations.sh
```

---

### [02_MapReduce](02_MapReduce/) — Batch Processing (Python)

Uses **Hadoop Streaming** — Python mapper/reducer read from stdin, write to stdout.

| Folder | Program | Technique |
|--------|---------|-----------|
| `01_WordCount/` | `mapper.py` + `reducer.py` | Basic streaming, combiner |
| `02_InvertedIndex/` | `mapper.py` + `reducer.py` | env vars, multi-value reduce |
| `03_TopN/` | `mapper.py` + `reducer.py` | Chained jobs, heap-based top-N |

```bash
# Local test (no Hadoop needed)
echo "hello hadoop hello world" | python mapper.py | sort | python reducer.py

# Submit to cluster
docker exec -it hadoop-namenode bash /opt/mapreduce/01_WordCount/run.sh
```

---

### [03_YARN](03_YARN/) — Resource Management

| Script | Topics Covered |
|--------|----------------|
| `01_yarn_operations.sh` | node list, queue status, submit job, app logs, kill |

---

### [04_Hive](04_Hive/) — SQL on Hadoop

| Script | Topics Covered |
|--------|----------------|
| `01_setup.sh` | Upload CSV data to HDFS |
| `02_ddl.hql` | CREATE/ALTER/DROP databases, tables (internal/external/ORC/Parquet), views |
| `03_dml.hql` | LOAD, INSERT, CTAS, SELECT, GROUP BY, HAVING, UPDATE, DELETE (ACID) |
| `04_partitioning.hql` | Static/dynamic partitioning, MSCK REPAIR, partition pruning |
| `05_bucketing.hql` | Bucketing, TABLESAMPLE, bucket map join |
| `06_joins.hql` | INNER, LEFT/RIGHT/FULL OUTER, SEMI, map-side, multi-table, self-join |
| `07_window_functions.hql` | ROW_NUMBER, RANK, DENSE_RANK, LAG, LEAD, FIRST_VALUE, running totals |

```bash
docker exec -it hadoop-hive bash /tmp/hive_scripts/01_setup.sh
docker exec -it hadoop-hive beeline -u "jdbc:hive2://localhost:10000" -f /tmp/hive_scripts/02_ddl.hql
```

---

### [05_HBase](05_HBase/) — NoSQL Column Store

| Script | Topics Covered |
|--------|----------------|
| `01_shell_operations.sh` | create, put, get, scan, delete, filters, namespaces, compaction |
| `02_python_happybase.py` | Python HappyBase API, batch writes, counters, scan filters |

```bash
# Shell
docker exec -it hadoop-hbase bash /tmp/01_shell_operations.sh

# Python
pip install happybase
python 02_python_happybase.py
```

---

### [06_Pig](06_Pig/) — Data Flow (Pig Latin)

| Script | Topics Covered |
|--------|----------------|
| `01_basic_operations.pig` | LOAD, FILTER, FOREACH, GROUP, ORDER, JOIN, SPLIT, UNION |
| `02_word_count.pig` | TOKENIZE, FLATTEN, GROUP, COUNT, STORE |

```bash
docker exec -it hadoop-namenode pig -x mapreduce /tmp/01_basic_operations.pig
```

---

### [07_Sqoop](07_Sqoop/) — RDBMS ↔ Hadoop

| Script | Topics Covered |
|--------|----------------|
| `01_sqoop_operations.sh` | list-databases, list-tables, import, import-with-query, incremental, export |

```bash
docker exec -it hadoop-namenode bash /tmp/01_sqoop_operations.sh
```

---

### [08_Spark_on_YARN](08_Spark_on_YARN/) — Spark with Hadoop

| Script | Topics Covered |
|--------|----------------|
| `01_submit.sh` | spark-submit options (client/cluster mode, executors, memory) |
| `02_wordcount.py` | RDD API + DataFrame API word count |
| `03_dataframe_ops.py` | Read HDFS CSV, aggregations, window functions, write Parquet |

```bash
docker exec -it hadoop-spark spark-submit \
  --master yarn --deploy-mode client \
  /tmp/scripts/02_wordcount.py hdfs:///spark/input/sample.txt hdfs:///spark/output/wc
```

---

### [09_Advanced](09_Advanced/) — Advanced HDFS Features

| File | Topics Covered |
|------|----------------|
| `01_erasure_coding.sh` | EC policies (RS, XOR), enable/disable, storage savings |
| `02_hdfs_encryption.sh` | KMS, encryption zones, key rotation, TDE |
| `03_federation.md` | HDFS Federation, ViewFs, Router-Based Federation, HA concepts |

---

## Quick Command Reference

```bash
# HDFS
hdfs dfs -ls / | -put | -get | -cat | -mkdir | -rm | -du | -cp | -mv
hdfs dfsadmin -report | -safemode | -setQuota | -setSpaceQuota
hdfs fsck /path -files -blocks -locations

# YARN
yarn application -list | -kill | -logs
yarn node -list | -status
yarn queue -status default

# MapReduce Streaming
STREAMING_JAR=$(find /opt -name "hadoop-streaming*.jar" | head -1)
hadoop jar "$STREAMING_JAR" -mapper mapper.py -reducer reducer.py \
  -input /in -output /out -files mapper.py,reducer.py

# Hive
beeline -u "jdbc:hive2://localhost:10000"
beeline -u "jdbc:hive2://localhost:10000" -f query.hql

# HBase
hbase shell
hbase thrift start &

# Pig
pig -x mapreduce script.pig
pig -x local script.pig   # local mode

# Spark
spark-submit --master yarn --deploy-mode client script.py
spark-submit --master yarn --deploy-mode cluster script.py
```

---

## Documentation

| Doc | Description |
|-----|-------------|
| [DOCS/01_concepts.md](DOCS/01_concepts.md) | Deep-dive: HDFS, MapReduce, YARN, Hive, HBase, Spark internals |
| [DOCS/02_cheatsheet.md](DOCS/02_cheatsheet.md) | All commands in one place — copy-paste ready |
| [DOCS/03_troubleshooting.md](DOCS/03_troubleshooting.md) | Common errors and how to fix them |
| [DOCS/04_code_guidelines.md](DOCS/04_code_guidelines.md) | Templates and rules for Python, HiveQL, PySpark, Shell |

---

## Stop / Reset

```bash
cd Hadoop/00_Setup
docker compose stop            # pause (keep data)
docker compose start           # resume
docker compose down -v         # destroy everything (full reset)
```
