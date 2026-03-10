#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# run.sh — MapReduce Join patterns (reduce-side + map-side)
# Run inside NameNode: bash /opt/mapreduce/04_Joins/run.sh
# ─────────────────────────────────────────────────────────────────────────────

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STREAMING_JAR=$(find /opt -name "hadoop-streaming*.jar" 2>/dev/null | head -1)

echo "════════════════════════════════════════════"
echo "  MapReduce Join Patterns"
echo "════════════════════════════════════════════"

# ── Create sample data ────────────────────────────────────────────────────────
cat > /tmp/employees.csv << 'EOF'
1,Alice,10,95000
2,Bob,20,72000
3,Carol,10,88000
4,Dave,30,65000
5,Eve,10,105000
6,Frank,20,78000
EOF

cat > /tmp/departments.csv << 'EOF'
10,Engineering,San Francisco
20,Marketing,New York
30,HR,Chicago
EOF

hdfs dfs -rm -r -f /mr/joins/
hdfs dfs -mkdir -p /mr/joins/emp_input
hdfs dfs -mkdir -p /mr/joins/dept_input
hdfs dfs -put /tmp/employees.csv  /mr/joins/emp_input/employees.csv
hdfs dfs -put /tmp/departments.csv /mr/joins/dept_input/departments.csv

# ═══════════════════════════════════════════════════════════════════
# PATTERN 1: Reduce-Side Join
# Both datasets sent to reducer, joined on common key (dept_id)
# Works for ANY size datasets — uses shuffle
# ═══════════════════════════════════════════════════════════════════
echo -e "\n[1] Local test — Reduce-Side Join"
{
  map_input_file=employees.csv   cat /tmp/employees.csv   | map_input_file=employees.csv   python3 "$SCRIPT_DIR/reduce_side_join_mapper.py"
  map_input_file=departments.csv cat /tmp/departments.csv | map_input_file=departments.csv python3 "$SCRIPT_DIR/reduce_side_join_mapper.py"
} | sort | python3 "$SCRIPT_DIR/reduce_side_join_reducer.py"

echo -e "\n[2] Hadoop Streaming — Reduce-Side Join"
hdfs dfs -rm -r -f /mr/joins/reduce_output

hadoop jar "$STREAMING_JAR" \
  -files  "$SCRIPT_DIR/reduce_side_join_mapper.py,$SCRIPT_DIR/reduce_side_join_reducer.py" \
  -mapper  "python3 reduce_side_join_mapper.py" \
  -reducer "python3 reduce_side_join_reducer.py" \
  -input  "/mr/joins/emp_input,/mr/joins/dept_input" \
  -output "/mr/joins/reduce_output" \
  -numReduceTasks 2

echo "Reduce-side join output:"
hdfs dfs -cat /mr/joins/reduce_output/part-* | head -10

# ═══════════════════════════════════════════════════════════════════
# PATTERN 2: Map-Side Join (Broadcast/Replicated Join)
# Small table loaded into mapper memory — NO reducer, NO shuffle
# Requirements: small table fits in RAM per mapper
# ═══════════════════════════════════════════════════════════════════
echo -e "\n[3] Local test — Map-Side Join"
cat /tmp/employees.csv | python3 "$SCRIPT_DIR/map_side_join.py"

echo -e "\n[4] Hadoop Streaming — Map-Side Join (numReduceTasks=0)"
hdfs dfs -rm -r -f /mr/joins/map_side_output

hadoop jar "$STREAMING_JAR" \
  -files   "$SCRIPT_DIR/map_side_join.py,/tmp/departments.csv" \
  -mapper  "python3 map_side_join.py" \
  -reducer NONE \
  -numReduceTasks 0 \
  -input   "/mr/joins/emp_input" \
  -output  "/mr/joins/map_side_output"

echo "Map-side join output (no reducer — much faster for small lookup):"
hdfs dfs -cat /mr/joins/map_side_output/part-* | head -10

echo -e "\n════════════════════════════════════════════"
echo "  Join Patterns — DONE"
echo ""
echo "  Reduce-Side: full shuffle, works at any scale"
echo "  Map-Side:    no shuffle, fast — small table must fit in RAM"
echo "════════════════════════════════════════════"
