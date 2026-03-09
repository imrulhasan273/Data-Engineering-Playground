# 07 — Apache Sqoop

## What is Sqoop?
Sqoop transfers data between **HDFS/Hive/HBase** and **relational databases** (MySQL, PostgreSQL, Oracle, etc.) using MapReduce for parallelism.

## Connect
```bash
docker exec -it hadoop-namenode bash
# Sqoop is included in the NameNode image
sqoop version
```

## Scripts

| File | What It Tests |
|------|---------------|
| `01_sqoop_operations.sh` | Import, export, incremental import, list tables |
