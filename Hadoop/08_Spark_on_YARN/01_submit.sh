#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 01_submit.sh — spark-submit examples on YARN
# Run inside Spark container: docker exec -it hadoop-spark bash 01_submit.sh
# ─────────────────────────────────────────────────────────────────────────────

HDFS_BASE="hdfs://namenode:9000"
SPARK_HOME=${SPARK_HOME:-/spark}

echo "════════════════════════════════════════════"
echo "  Spark on YARN — Submit Examples"
echo "════════════════════════════════════════════"

# ── 0. Upload sample data ─────────────────────────────────────────────────────
echo -e "\n[0] Uploading input data to HDFS..."
cat > /tmp/sample.txt << 'EOF'
Apache Hadoop is a distributed computing framework
Apache Spark is a fast in-memory data processing engine
Hadoop uses HDFS for distributed storage
Spark can run on YARN MapReduce or standalone
YARN manages resources across the Hadoop cluster
Apache Hive provides SQL queries on Hadoop data
EOF

hdfs dfs -mkdir -p /spark/input
hdfs dfs -put -f /tmp/sample.txt /spark/input/sample.txt

# ── 1. Built-in Pi example (test cluster) ────────────────────────────────────
echo -e "\n[1] Run built-in Pi example on YARN"
spark-submit \
  --master yarn \
  --deploy-mode client \
  --num-executors 1 \
  --executor-memory 512m \
  --executor-cores 1 \
  --class org.apache.spark.examples.SparkPi \
  "$SPARK_HOME/examples/jars/spark-examples*.jar" \
  10

# ── 2. Python word count ─────────────────────────────────────────────────────
echo -e "\n[2] Python WordCount on YARN"
hdfs dfs -rm -r -f /spark/output/wordcount

spark-submit \
  --master yarn \
  --deploy-mode client \
  --num-executors 2 \
  --executor-memory 512m \
  --executor-cores 1 \
  --conf spark.yarn.submit.waitAppCompletion=true \
  /tmp/scripts/02_wordcount.py \
  "${HDFS_BASE}/spark/input/sample.txt" \
  "${HDFS_BASE}/spark/output/wordcount"

echo "Word count output:"
hdfs dfs -cat /spark/output/wordcount/part-* 2>/dev/null | sort -k2 -rn | head -10

# ── 3. DataFrame operations ───────────────────────────────────────────────────
echo -e "\n[3] DataFrame operations"
spark-submit \
  --master yarn \
  --deploy-mode client \
  --num-executors 2 \
  --executor-memory 512m \
  /tmp/scripts/03_dataframe_ops.py

# ── 4. Cluster mode (detach after submission) ─────────────────────────────────
echo -e "\n[4] Cluster mode submission (driver on YARN)"
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --num-executors 1 \
  --executor-memory 512m \
  --conf spark.yarn.submit.waitAppCompletion=false \
  /tmp/scripts/02_wordcount.py \
  "${HDFS_BASE}/spark/input/sample.txt" \
  "${HDFS_BASE}/spark/output/wordcount_cluster"

# View job status
yarn application -list -appStates ALL | grep spark | head -3

echo -e "\n════════════════════════════════════════════"
echo "  Spark on YARN — DONE"
echo "  Spark History UI: http://localhost:18080"
echo "  YARN UI:          http://localhost:8088"
echo "════════════════════════════════════════════"
