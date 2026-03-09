# 06 — Apache Pig

## What is Pig?
Pig provides a high-level data flow language called **Pig Latin** that compiles to MapReduce. Good for ETL pipelines.

## Connect
```bash
docker exec -it hadoop-namenode pig          # interactive grunt shell
docker exec -it hadoop-namenode pig -x local  # local mode (no HDFS)
docker exec -it hadoop-namenode pig script.pig
```

## Scripts

| File | What It Tests |
|------|---------------|
| `01_basic_operations.pig` | LOAD, DUMP, STORE, FILTER, FOREACH, GROUP, ORDER |
| `02_word_count.pig` | Classic word count in Pig Latin |
