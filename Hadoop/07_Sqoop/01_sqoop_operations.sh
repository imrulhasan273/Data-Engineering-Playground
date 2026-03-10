#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 01_sqoop_operations.sh — Sqoop import/export/incremental
# Run inside NameNode: docker exec -it hadoop-namenode bash 01_sqoop_operations.sh
#
# Prerequisites:
#   PostgreSQL is running (hadoop-postgres container)
#   PostgreSQL JDBC driver in $SQOOP_HOME/lib/
#
# Download JDBC driver into Sqoop lib (run once):
#   wget -q https://jdbc.postgresql.org/download/postgresql-42.7.4.jar \
#     -O /opt/sqoop/lib/postgresql.jar
# ─────────────────────────────────────────────────────────────────────────────

PG_HOST="postgres"
PG_PORT="5432"
PG_DB="hive_metastore"
PG_USER="hive"
PG_PASS="hive"
CONNECT="jdbc:postgresql://${PG_HOST}:${PG_PORT}/${PG_DB}"
DRIVER="org.postgresql.Driver"

echo "════════════════════════════════════════════"
echo "  Sqoop Operations (PostgreSQL)"
echo "════════════════════════════════════════════"

# ── 0. Setup: create source table in PostgreSQL ───────────────────────────────
echo -e "\n[0] Creating source table in PostgreSQL..."
PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" << 'SQL'
CREATE TABLE IF NOT EXISTS employees (
  emp_id     SERIAL PRIMARY KEY,
  name       VARCHAR(100),
  department VARCHAR(100),
  salary     NUMERIC(10,2),
  hire_date  DATE,
  country    CHAR(2),
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

TRUNCATE TABLE employees RESTART IDENTITY;

INSERT INTO employees (name, department, salary, hire_date, country) VALUES
  ('Alice',  'Engineering', 95000,  '2020-01-15', 'US'),
  ('Bob',    'Marketing',   72000,  '2019-06-01', 'US'),
  ('Carol',  'Engineering', 88000,  '2021-03-20', 'UK'),
  ('Dave',   'HR',          65000,  '2018-09-10', 'US'),
  ('Eve',    'Engineering', 105000, '2017-11-05', 'DE');
SQL

# ── 1. List Databases ─────────────────────────────────────────────────────────
echo -e "\n[1] List PostgreSQL databases"
sqoop list-databases \
  --connect "jdbc:postgresql://${PG_HOST}:${PG_PORT}/" \
  --driver "$DRIVER" \
  --username "$PG_USER" \
  --password "$PG_PASS"

# ── 2. List Tables ────────────────────────────────────────────────────────────
echo -e "\n[2] List tables in database"
sqoop list-tables \
  --connect "$CONNECT" \
  --driver "$DRIVER" \
  --username "$PG_USER" \
  --password "$PG_PASS"

# ── 3. Import Full Table to HDFS ─────────────────────────────────────────────
echo -e "\n[3] Full table import to HDFS"
hdfs dfs -rm -r -f /sqoop/employees

sqoop import \
  --connect "$CONNECT" \
  --driver "$DRIVER" \
  --username "$PG_USER" \
  --password "$PG_PASS" \
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
  --driver "$DRIVER" \
  --username "$PG_USER" \
  --password "$PG_PASS" \
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
  --driver "$DRIVER" \
  --username "$PG_USER" \
  --password "$PG_PASS" \
  --table employees \
  --hive-import \
  --hive-database playground \
  --hive-table employees_from_postgres \
  --hive-overwrite \
  --num-mappers 1

# ── 6. Import with Custom Query ───────────────────────────────────────────────
echo -e "\n[6] Import using custom SQL query"
hdfs dfs -rm -r -f /sqoop/custom_query

sqoop import \
  --connect "$CONNECT" \
  --driver "$DRIVER" \
  --username "$PG_USER" \
  --password "$PG_PASS" \
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
  --driver "$DRIVER" \
  --username "$PG_USER" \
  --password "$PG_PASS" \
  --table employees \
  --target-dir /sqoop/employees_incremental \
  --incremental append \
  --check-column emp_id \
  --last-value 0 \
  --num-mappers 1

# Add a new row in PostgreSQL
PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" \
  -c "INSERT INTO employees (name, department, salary, hire_date, country)
      VALUES ('Frank', 'Marketing', 78000, '2022-01-30', 'UK');"

# Incremental: only import emp_id > 5
sqoop import \
  --connect "$CONNECT" \
  --driver "$DRIVER" \
  --username "$PG_USER" \
  --password "$PG_PASS" \
  --table employees \
  --target-dir /sqoop/employees_incremental \
  --incremental append \
  --check-column emp_id \
  --last-value 5 \
  --num-mappers 1

echo "After incremental import:"
hdfs dfs -cat /sqoop/employees_incremental/part-m-*

# ── 8. Export — HDFS to PostgreSQL ───────────────────────────────────────────
echo -e "\n[8] Export from HDFS to PostgreSQL"

# Create target table in PostgreSQL
PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" << 'SQL'
CREATE TABLE IF NOT EXISTS employees_backup (LIKE employees INCLUDING ALL);
TRUNCATE TABLE employees_backup;
SQL

sqoop export \
  --connect "$CONNECT" \
  --driver "$DRIVER" \
  --username "$PG_USER" \
  --password "$PG_PASS" \
  --table employees_backup \
  --export-dir /sqoop/employees \
  --input-fields-terminated-by ',' \
  --num-mappers 1

PGPASSWORD="$PG_PASS" psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" \
  -c "SELECT COUNT(*) AS exported_rows FROM employees_backup;"

echo -e "\n════════════════════════════════════════════"
echo "  Sqoop Operations — DONE"
echo "════════════════════════════════════════════"
