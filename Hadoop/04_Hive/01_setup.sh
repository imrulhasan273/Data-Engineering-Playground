#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 01_setup.sh — Prepare HDFS data for Hive exercises
# Run inside Hive container: docker exec -it hadoop-hive bash 01_setup.sh
# ─────────────────────────────────────────────────────────────────────────────

echo "════════════════════════════════════════════"
echo "  Hive — Setup Sample Data"
echo "════════════════════════════════════════════"

# ── Create CSV files ──────────────────────────────────────────────────────────

# employees.csv
cat > /tmp/employees.csv << 'EOF'
1,Alice,Engineering,95000,2020-01-15,US
2,Bob,Marketing,72000,2019-06-01,US
3,Carol,Engineering,88000,2021-03-20,UK
4,Dave,HR,65000,2018-09-10,US
5,Eve,Engineering,105000,2017-11-05,DE
6,Frank,Marketing,78000,2022-01-30,UK
7,Grace,HR,68000,2020-07-15,US
8,Heidi,Engineering,92000,2021-08-01,DE
9,Ivan,Marketing,75000,2019-12-01,US
10,Judy,Engineering,98000,2016-04-10,UK
EOF

# departments.csv
cat > /tmp/departments.csv << 'EOF'
Engineering,Technology,San Francisco
Marketing,Business,New York
HR,Operations,Chicago
Finance,Business,New York
EOF

# sales.csv (for partitioning/bucketing)
cat > /tmp/sales.csv << 'EOF'
1,2023,Q1,Electronics,1500.00
2,2023,Q1,Clothing,250.00
3,2023,Q2,Electronics,2200.00
4,2023,Q2,Food,180.00
5,2023,Q3,Electronics,3100.00
6,2023,Q3,Clothing,420.00
7,2023,Q4,Electronics,4500.00
8,2023,Q4,Food,310.00
9,2024,Q1,Electronics,1800.00
10,2024,Q1,Clothing,290.00
11,2024,Q2,Electronics,2500.00
12,2024,Q2,Food,220.00
EOF

# ── Upload to HDFS ────────────────────────────────────────────────────────────
hdfs dfs -mkdir -p /hive/raw/employees
hdfs dfs -mkdir -p /hive/raw/departments
hdfs dfs -mkdir -p /hive/raw/sales

hdfs dfs -put -f /tmp/employees.csv   /hive/raw/employees/
hdfs dfs -put -f /tmp/departments.csv /hive/raw/departments/
hdfs dfs -put -f /tmp/sales.csv       /hive/raw/sales/

echo "Data uploaded:"
hdfs dfs -ls /hive/raw/

echo -e "\n════════════════════════════════════════════"
echo "  Setup DONE. Run scripts 02-07 in Beeline:"
echo "  beeline -u 'jdbc:hive2://localhost:10000'"
echo "════════════════════════════════════════════"
