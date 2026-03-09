# 08 — Apache Spark on YARN

## What is Spark on YARN?
Running Spark on YARN allows Spark jobs to share cluster resources with other Hadoop workloads. Spark reads/writes HDFS natively.

## Submit Modes
| Mode | Description |
|------|-------------|
| `--master yarn --deploy-mode client` | Driver runs on submitting node, output in terminal |
| `--master yarn --deploy-mode cluster` | Driver runs inside the cluster, submit and detach |

## How to Run
```bash
docker exec -it hadoop-spark bash

# Submit a Python job
spark-submit \
  --master yarn \
  --deploy-mode client \
  --num-executors 2 \
  --executor-memory 512m \
  /tmp/scripts/02_wordcount.py hdfs:///input/sample.txt hdfs:///output/spark_wc
```

## Scripts

| File | What It Tests |
|------|---------------|
| `01_submit.sh` | spark-submit commands, config options |
| `02_wordcount.py` | Word count with RDD and DataFrame API |
| `03_dataframe_ops.py` | DataFrame operations on HDFS data |
