# 02 — MapReduce (Python via Hadoop Streaming)

## What is MapReduce?
MapReduce is Hadoop's native batch processing framework. Every job has two phases:
- **Map**: Reads input lines from stdin, emits `key\tvalue` pairs to stdout
- **Reduce**: Groups by key, aggregates values from stdin

```
Input → [Split 1] [Split 2] [Split 3]
              ↓        ↓        ↓
         mapper.py  mapper.py  mapper.py      (parallel)
              ↓        ↓        ↓
           Shuffle & Sort (by key)
              ↓        ↓
         reducer.py  reducer.py               (parallel)
              ↓        ↓
          Output   Output
```

## Hadoop Streaming
Python scripts communicate via **stdin/stdout**. Hadoop Streaming launches them as subprocesses.

```bash
STREAMING_JAR=$(find /opt -name "hadoop-streaming*.jar" | head -1)

hadoop jar "$STREAMING_JAR" \
  -input  /input/path \
  -output /output/path \
  -mapper  mapper.py \
  -reducer reducer.py \
  -file    mapper.py \
  -file    reducer.py
```

## Programs in This Module

| Folder | Program | Concepts |
|--------|---------|----------|
| `01_WordCount/` | Word frequency count | Basic Streaming, stdin/stdout |
| `02_InvertedIndex/` | Word → list of files | Multi-value reduce, env vars |
| `03_TopN/` | Top N words by frequency | Chained jobs, sort |

## How to Run

```bash
# Enter NameNode
docker exec -it hadoop-namenode bash

# Copy scripts
docker cp 02_MapReduce/ hadoop-namenode:/opt/mapreduce/

# Run each exercise
bash /opt/mapreduce/01_WordCount/run.sh
bash /opt/mapreduce/02_InvertedIndex/run.sh
bash /opt/mapreduce/03_TopN/run.sh
```

## Test Locally (no Hadoop needed)

```bash
echo "hello world hello hadoop" | python mapper.py | sort | python reducer.py
```
