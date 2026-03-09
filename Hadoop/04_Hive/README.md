# 04 — Apache Hive

## What is Hive?
Hive provides a SQL-like interface (HiveQL) for querying data stored in HDFS. Queries are compiled to MapReduce, Tez, or Spark jobs.

## Architecture
```
Client → HiveServer2 → (MetaStore → MySQL)
                      → (Execution Engine: Tez/MR/Spark)
                      → HDFS (data)
```

## How to Connect

```bash
# Interactive Beeline shell
docker exec -it hadoop-hive beeline -u "jdbc:hive2://localhost:10000"

# Run a HQL file
docker exec -it hadoop-hive beeline -u "jdbc:hive2://localhost:10000" -f /tmp/query.hql

# Copy and run our scripts
docker cp 04_Hive/ hadoop-hive:/tmp/hive_scripts/
docker exec -it hadoop-hive beeline -u "jdbc:hive2://localhost:10000" -f /tmp/hive_scripts/02_ddl.hql
```

## Scripts in This Module

| File | What It Tests |
|------|---------------|
| `01_setup.sh` | Upload data to HDFS, launch beeline |
| `02_ddl.hql` | CREATE/DROP/ALTER databases & tables |
| `03_dml.hql` | INSERT, LOAD DATA, SELECT, UPDATE, DELETE |
| `04_partitioning.hql` | Static & dynamic partitioning |
| `05_bucketing.hql` | Bucketing + sampling |
| `06_joins.hql` | Inner, outer, map-side joins |
| `07_window_functions.hql` | ROW_NUMBER, RANK, LAG, LEAD, aggregates |
