#!/usr/bin/env bash
# run.sh — Run TopN with Python + Hadoop Streaming (chained after WordCount)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WC_OUTPUT="/mr/wordcount/output"
OUTPUT_HDFS="/mr/topn/output"
N=10
STREAMING_JAR=$(find /opt -name "hadoop-streaming*.jar" 2>/dev/null | head -1)

echo "════════════════════════════════════════════"
echo "  Top-$N Words — Python Hadoop Streaming"
echo "════════════════════════════════════════════"

# Run WordCount first if needed
if ! hdfs dfs -test -d "$WC_OUTPUT" 2>/dev/null; then
  echo "[Pre-req] Running WordCount first..."
  bash "$(dirname "$SCRIPT_DIR")/01_WordCount/run.sh"
fi

hdfs dfs -rm -r -f "$OUTPUT_HDFS"

# ── Local test ────────────────────────────────────────────────────────────────
echo -e "\n[Local test]"
printf "hadoop\t5\napache\t3\nspark\t8\nyarn\t4\nhdfs\t6\n" \
  | TOPN_N=3 python3 "$SCRIPT_DIR/mapper.py" \
  | sort \
  | TOPN_N=3 python3 "$SCRIPT_DIR/reducer.py"

# ── Submit Streaming job (reads WordCount output) ─────────────────────────────
echo -e "\n[Submitting Hadoop Streaming job...]"
hadoop jar "$STREAMING_JAR" \
  -files   "$SCRIPT_DIR/mapper.py,$SCRIPT_DIR/reducer.py" \
  -mapper  "python3 mapper.py" \
  -reducer "python3 reducer.py" \
  -input   "$WC_OUTPUT" \
  -output  "$OUTPUT_HDFS" \
  -numReduceTasks 1 \
  -cmdenv  "TOPN_N=$N"

echo -e "\n[Results] Top $N words:"
hdfs dfs -cat "$OUTPUT_HDFS/part-*"

echo -e "\n════════════════════════════════════════════"
echo "  Top-N — DONE"
echo "════════════════════════════════════════════"
