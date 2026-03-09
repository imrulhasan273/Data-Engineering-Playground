#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 01_shell_operations.sh — HBase shell commands (run inside HBase container)
# Usage: docker exec -it hadoop-hbase bash 01_shell_operations.sh
# ─────────────────────────────────────────────────────────────────────────────

echo "════════════════════════════════════════════"
echo "  HBase Shell Operations"
echo "════════════════════════════════════════════"

# ── Start Thrift Server (for Python API) ─────────────────────────────────────
echo "[0] Starting HBase Thrift server (for Python HappyBase)..."
hbase thrift start &
sleep 3

# ── Run HBase Shell commands via heredoc ─────────────────────────────────────
hbase shell << 'HBASE_COMMANDS'

# ── 1. Status & Version ───────────────────────────────────────────────────────
status
version
whoami

# ── 2. Create Tables ─────────────────────────────────────────────────────────
# Syntax: create 'table_name', 'column_family1', 'column_family2'

create 'employees', 'personal', 'work'
# Column families: 'personal' (name, country) and 'work' (dept, salary)

create 'products',
  {NAME => 'info', VERSIONS => 3, COMPRESSION => 'SNAPPY'},
  {NAME => 'pricing', VERSIONS => 1, TTL => 86400}
# VERSIONS: keep last 3 versions of each cell
# TTL: auto-expire after 86400 seconds (1 day)

list

# ── 3. Insert Data (put) ──────────────────────────────────────────────────────
# Syntax: put 'table', 'rowkey', 'family:column', 'value'

put 'employees', 'emp:001', 'personal:name',    'Alice'
put 'employees', 'emp:001', 'personal:country', 'US'
put 'employees', 'emp:001', 'work:department',  'Engineering'
put 'employees', 'emp:001', 'work:salary',      '95000'
put 'employees', 'emp:001', 'work:hire_date',   '2020-01-15'

put 'employees', 'emp:002', 'personal:name',    'Bob'
put 'employees', 'emp:002', 'personal:country', 'US'
put 'employees', 'emp:002', 'work:department',  'Marketing'
put 'employees', 'emp:002', 'work:salary',      '72000'

put 'employees', 'emp:003', 'personal:name',    'Carol'
put 'employees', 'emp:003', 'personal:country', 'UK'
put 'employees', 'emp:003', 'work:department',  'Engineering'
put 'employees', 'emp:003', 'work:salary',      '88000'

# ── 4. Get — Read a Single Row ────────────────────────────────────────────────
get 'employees', 'emp:001'
get 'employees', 'emp:001', 'work'                    # all columns in 'work' family
get 'employees', 'emp:001', 'personal:name'           # specific column
get 'employees', 'emp:001', {COLUMN => 'work:salary', VERSIONS => 3}  # versions

# ── 5. Scan — Read Multiple Rows ─────────────────────────────────────────────
scan 'employees'                                       # all rows
scan 'employees', {LIMIT => 2}                        # first 2 rows
scan 'employees', {STARTROW => 'emp:001', STOPROW => 'emp:003'}  # row range
scan 'employees', {COLUMNS => ['personal:name', 'work:salary']}  # specific columns
scan 'employees', {FILTER => "ValueFilter(=, 'binary:Engineering')"}  # filter by value
scan 'employees', {FILTER => "PrefixFilter('emp:00')"}            # row key prefix

# ── 6. Update — Just put again (HBase is append-only, put overwrites) ─────────
put 'employees', 'emp:002', 'work:salary', '75000'
get 'employees', 'emp:002', 'work:salary'

# Check version history
get 'employees', 'emp:002', {COLUMN => 'work:salary', VERSIONS => 3}

# ── 7. Delete ────────────────────────────────────────────────────────────────
delete 'employees', 'emp:001', 'work:hire_date'       # delete specific column
deleteall 'employees', 'emp:003'                      # delete entire row

scan 'employees'

# ── 8. Count Rows ─────────────────────────────────────────────────────────────
count 'employees'
count 'employees', INTERVAL => 1                      # print every row

# ── 9. Table Management ───────────────────────────────────────────────────────
describe 'employees'

# Disable table before altering or dropping
disable 'products'

# Alter: add a new column family
alter 'products', {NAME => 'reviews', VERSIONS => 5}

# Re-enable
enable 'products'
describe 'products'

# Check if table exists
exists 'employees'
is_enabled 'employees'

# ── 10. Flush & Compaction ────────────────────────────────────────────────────
flush 'employees'           # write MemStore to HFile on disk
major_compact 'employees'   # merge all HFiles into one per region

# ── 11. Namespace Operations ──────────────────────────────────────────────────
list_namespace
create_namespace 'analytics'
create 'analytics:events', 'data'
put 'analytics:events', 'evt:001', 'data:type', 'click'
scan 'analytics:events'
drop 'analytics:events'
drop_namespace 'analytics'

# ── 12. Cleanup ───────────────────────────────────────────────────────────────
disable 'employees'
drop 'employees'
disable 'products'
drop 'products'

list

HBASE_COMMANDS

echo -e "\n════════════════════════════════════════════"
echo "  HBase Shell — DONE"
echo "  HBase Master UI: http://localhost:16010"
echo "════════════════════════════════════════════"
