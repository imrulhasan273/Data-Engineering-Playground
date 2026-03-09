#!/usr/bin/env bash
# run.sh — Run InvertedIndex with Python + Hadoop Streaming

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_HDFS="/mr/invindex/input"
OUTPUT_HDFS="/mr/invindex/output"
STREAMING_JAR=$(find /opt -name "hadoop-streaming*.jar" 2>/dev/null | head -1)

echo "════════════════════════════════════════════"
echo "  Inverted Index — Python Hadoop Streaming"
echo "════════════════════════════════════════════"

# ── Create multiple input files ───────────────────────────────────────────────
hdfs dfs -rm -r -f "$INPUT_HDFS" "$OUTPUT_HDFS"
hdfs dfs -mkdir -p "$INPUT_HDFS"

echo "hadoop is a distributed storage and processing framework" > /tmp/doc1.txt
echo "hadoop mapreduce is the batch processing engine of hadoop" > /tmp/doc2.txt
echo "apache spark is faster than mapreduce for iterative jobs" > /tmp/doc3.txt

hdfs dfs -put /tmp/doc1.txt "$INPUT_HDFS/doc1.txt"
hdfs dfs -put /tmp/doc2.txt "$INPUT_HDFS/doc2.txt"
hdfs dfs -put /tmp/doc3.txt "$INPUT_HDFS/doc3.txt"

# ── Local test ────────────────────────────────────────────────────────────────
echo -e "\n[Local test]"
map_input_file=doc1.txt echo "hadoop is great hadoop" \
  | map_input_file=doc1.txt python3 "$SCRIPT_DIR/mapper.py" \
  | sort \
  | python3 "$SCRIPT_DIR/reducer.py" \
  | grep "hadoop"

# ── Submit Streaming job ──────────────────────────────────────────────────────
echo -e "\n[Submitting Hadoop Streaming job...]"
hadoop jar "$STREAMING_JAR" \
  -files "$SCRIPT_DIR/mapper.py,$SCRIPT_DIR/reducer.py" \
  -mapper  "python3 mapper.py" \
  -reducer "python3 reducer.py" \
  -input   "$INPUT_HDFS" \
  -output  "$OUTPUT_HDFS" \
  -numReduceTasks 1

# ── Results ───────────────────────────────────────────────────────────────────
echo -e "\n[Results] Inverted Index (key words):"
hdfs dfs -cat "$OUTPUT_HDFS/part-*" | sort | grep -E "^(hadoop|spark|mapreduce|apache)"

echo -e "\n════════════════════════════════════════════"
echo "  Inverted Index — DONE"
echo "════════════════════════════════════════════"
