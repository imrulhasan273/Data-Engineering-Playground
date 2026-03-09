#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 01_sqoop_operations.sh — Sqoop import/export/incremental
# Run inside NameNode: docker exec -it hadoop-namenode bash 01_sqoop_operations.sh
#
# Prerequisites:
#   MySQL is running (hadoop-mysql container)
#   MySQL JDBC driver in $SQOOP_HOME/lib/
# ─────────────────────────────────────────────────────────────────────────────

MYSQL_HOST="mysql"
MYSQL_PORT="3306"
MYSQL_DB="hive_metastore"
MYSQL_USER="hive"
MYSQL_PASS="hive"
CONNECT="jdbc:mysql://${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DB}"

echo "════════════════════════════════════════════"
echo "  Sqoop Operations"
echo "════════════════════════════════════════════"

# ── 0. Setup: create source table in MySQL ────────────────────────────────────
echo -e "\n[0] Creating source table in MySQL..."
mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" << 'SQL'
CREATE TABLE IF NOT EXISTS employees (
  emp_id     INT PRIMARY KEY AUTO_INCREMENT,
  name       VARCHAR(100),
  department VARCHAR(100),
  salary     DECIMAL(10,2),
  hire_date  DATE,
  country    CHAR(2),
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

TRUNCATE TABLE employees;

INSERT INTO employees (name, department, salary, hire_date, country) VALUES
  ('Alice',  'Engineering', 95000, '2020-01-15', 'US'),
  ('Bob',    'Marketing',   72000, '2019-06-01', 'US'),
  ('Carol',  'Engineering', 88000, '2021-03-20', 'UK'),
  ('Dave',   'HR',          65000, '2018-09-10', 'US'),
  ('Eve',    'Engineering', 105000,'2017-11-05', 'DE');
SQL

# ── 1. List Databases ─────────────────────────────────────────────────────────
echo -e "\n[1] List MySQL databases"
sqoop list-databases \
  --connect "jdbc:mysql://${MYSQL_HOST}:${MYSQL_PORT}/" \
  --username "$MYSQL_USER" \
  --password "$MYSQL_PASS"

# ── 2. List Tables ────────────────────────────────────────────────────────────
echo -e "\n[2] List tables in database"
sqoop list-tables \
  --connect "$CONNECT" \
  --username "$MYSQL_USER" \
  --password "$MYSQL_PASS"

# ── 3. Import Full Table to HDFS ─────────────────────────────────────────────
echo -e "\n[3] Full table import to HDFS"
hdfs dfs -rm -r -f /sqoop/employees

sqoop import \
  --connect "$CONNECT" \
  --username "$MYSQL_USER" \
  --password "$MYSQL_PASS" \
  --table employees \
  --target-dir /sqoop/employees \
  --fields-terminated-by ',' \
  --lines-terminated-by '\n' \
  --num-mappers 2 \
  --split-by emp_id

echo "Imported data:"
hdfs dfs -cat /sqoop/employees/part-m-00000 | head -5

# ── 4. Import with WHERE clause ───────────────────────────────────────────────
echo -e "\n[4] Import with WHERE filter"
hdfs dfs -rm -r -f /sqoop/engineers

sqoop import \
  --connect "$CONNECT" \
  --username "$MYSQL_USER" \
  --password "$MYSQL_PASS" \
  --table employees \
  --where "department = 'Engineering'" \
  --target-dir /sqoop/engineers \
  --fields-terminated-by ',' \
  --num-mappers 1

hdfs dfs -cat /sqoop/engineers/part-m-00000

# ── 5. Import to Hive Table ───────────────────────────────────────────────────
echo -e "\n[5] Import directly into Hive"
sqoop import \
  --connect "$CONNECT" \
  --username "$MYSQL_USER" \
  --password "$MYSQL_PASS" \
  --table employees \
  --hive-import \
  --hive-database playground \
  --hive-table employees_from_mysql \
  --hive-overwrite \
  --num-mappers 1

# ── 6. Import with Custom Query ───────────────────────────────────────────────
echo -e "\n[6] Import using custom SQL query"
hdfs dfs -rm -r -f /sqoop/custom_query

sqoop import \
  --connect "$CONNECT" \
  --username "$MYSQL_USER" \
  --password "$MYSQL_PASS" \
  --query "SELECT emp_id, name, salary FROM employees WHERE salary > 80000 AND \$CONDITIONS" \
  --split-by emp_id \
  --target-dir /sqoop/custom_query \
  --fields-terminated-by ',' \
  --num-mappers 1

hdfs dfs -cat /sqoop/custom_query/part-m-00000

# ── 7. Incremental Import ─────────────────────────────────────────────────────
echo -e "\n[7] Incremental import (append mode — new rows only)"
# First full import
hdfs dfs -rm -r -f /sqoop/employees_incremental
sqoop import \
  --connect "$CONNECT" \
  --username "$MYSQL_USER" \
  --password "$MYSQL_PASS" \
  --table employees \
  --target-dir /sqoop/employees_incremental \
  --incremental append \
  --check-column emp_id \
  --last-value 0 \
  --num-mappers 1

# Add new rows in MySQL
mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" \
  -e "INSERT INTO employees (name, department, salary, hire_date, country)
      VALUES ('Frank', 'Marketing', 78000, '2022-01-30', 'UK');"

# Incremental: only import emp_id > 5
sqoop import \
  --connect "$CONNECT" \
  --username "$MYSQL_USER" \
  --password "$MYSQL_PASS" \
  --table employees \
  --target-dir /sqoop/employees_incremental \
  --incremental append \
  --check-column emp_id \
  --last-value 5 \
  --num-mappers 1

echo "After incremental import:"
hdfs dfs -cat /sqoop/employees_incremental/part-m-*

# ── 8. Export — HDFS to MySQL ─────────────────────────────────────────────────
echo -e "\n[8] Export from HDFS to MySQL"

# Create target table in MySQL
mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" \
  -e "CREATE TABLE IF NOT EXISTS employees_backup LIKE employees;
      TRUNCATE TABLE employees_backup;"

sqoop export \
  --connect "$CONNECT" \
  --username "$MYSQL_USER" \
  --password "$MYSQL_PASS" \
  --table employees_backup \
  --export-dir /sqoop/employees \
  --input-fields-terminated-by ',' \
  --num-mappers 1

mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" \
  -e "SELECT COUNT(*) AS exported_rows FROM employees_backup;"

echo -e "\n════════════════════════════════════════════"
echo "  Sqoop Operations — DONE"
echo "════════════════════════════════════════════"
