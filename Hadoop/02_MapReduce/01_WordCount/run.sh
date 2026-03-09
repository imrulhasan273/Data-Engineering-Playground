#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run.sh — Run WordCount with Python + Hadoop Streaming
# Run inside NameNode: bash /opt/mapreduce/01_WordCount/run.sh
# ─────────────────────────────────────────────────────────────────────────────

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_HDFS="/mr/wordcount/input"
OUTPUT_HDFS="/mr/wordcount/output"
STREAMING_JAR=$(find /opt -name "hadoop-streaming*.jar" 2>/dev/null | head -1)

echo "════════════════════════════════════════════"
echo "  WordCount — Python Hadoop Streaming"
echo "════════════════════════════════════════════"

# ── Step 1: Local test ────────────────────────────────────────────────────────
echo -e "\n[1] Local test (no Hadoop needed)"
echo "hello hadoop hello world hadoop hadoop" \
  | python3 "$SCRIPT_DIR/mapper.py" \
  | sort \
  | python3 "$SCRIPT_DIR/reducer.py"

# ── Step 2: Prepare HDFS input ───────────────────────────────────────────────
echo -e "\n[2] Uploading input to HDFS..."
hdfs dfs -rm -r -f "$INPUT_HDFS" "$OUTPUT_HDFS"
hdfs dfs -mkdir -p "$INPUT_HDFS"

cat > /tmp/words.txt << 'EOF'
apache hadoop mapreduce yarn hdfs hive hbase pig sqoop spark
data engineering data pipeline batch processing stream processing
hadoop is a distributed storage and processing framework
apache spark runs on hadoop yarn using hdfs storage
hive provides sql queries on hadoop data in hdfs
EOF
hdfs dfs -put /tmp/words.txt "$INPUT_HDFS/"
hdfs dfs -ls "$INPUT_HDFS/"

# ── Step 3: Submit Streaming job ─────────────────────────────────────────────
echo -e "\n[3] Submitting Hadoop Streaming job..."
hadoop jar "$STREAMING_JAR" \
  -files "$SCRIPT_DIR/mapper.py,$SCRIPT_DIR/reducer.py" \
  -mapper  "python3 mapper.py" \
  -reducer "python3 reducer.py" \
  -input   "$INPUT_HDFS" \
  -output  "$OUTPUT_HDFS" \
  -numReduceTasks 2

# ── Step 4: Results ───────────────────────────────────────────────────────────
echo -e "\n[4] Output files:"
hdfs dfs -ls "$OUTPUT_HDFS/"

echo -e "\n[5] Top 15 words by frequency:"
hdfs dfs -cat "$OUTPUT_HDFS/part-*" | sort -t$'\t' -k2 -rn | head -15

echo -e "\n════════════════════════════════════════════"
echo "  WordCount — DONE"
echo "  View job: http://localhost:8088"
echo "════════════════════════════════════════════"
