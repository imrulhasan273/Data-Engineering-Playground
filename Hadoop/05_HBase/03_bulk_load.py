#!/usr/bin/env python3
"""
03_bulk_load.py — HBase Bulk Load via HappyBase + ImportTsv pattern

Two approaches:
  A) Python batch put (moderate scale — thousands of rows)
  B) Shell script showing ImportTsv → completebulkload (millions of rows)

Run:
    python3 03_bulk_load.py

For ImportTsv bulk load: see bulk_load_shell.sh
"""

import happybase
import csv
import io
import time
import struct

# ── Connect ───────────────────────────────────────────────────────────────────
conn = happybase.Connection(host='localhost', port=9090)
conn.open()

TABLE = 'employees_bulk'

# ── Setup table ───────────────────────────────────────────────────────────────
if TABLE.encode() in conn.tables():
    conn.disable_table(TABLE)
    conn.delete_table(TABLE)

conn.create_table(TABLE, {
    'personal': dict(max_versions=1, compression='SNAPPY'),
    'work':     dict(max_versions=1, compression='SNAPPY'),
})
table = conn.table(TABLE)
print(f"[OK] Table '{TABLE}' created")

# ────────────────────────────────────────────────────────────────────────────
# APPROACH A: Batch put (HappyBase batch)
# Good for up to ~1M rows depending on available RAM
# ────────────────────────────────────────────────────────────────────────────
print("\n[A] Batch put — 10,000 rows")

SAMPLE_DATA = io.StringIO("""\
1,Alice,Engineering,95000,US
2,Bob,Marketing,72000,US
3,Carol,Engineering,88000,UK
4,Dave,HR,65000,US
5,Eve,Engineering,105000,DE
""")

# Generate a larger dataset
rows = []
base_rows = list(csv.reader(SAMPLE_DATA))
for i in range(1, 10_001):
    base = base_rows[(i - 1) % len(base_rows)]
    rows.append((i, f"Employee_{i}", base[2], float(base[3]) + i, base[4]))

start = time.time()
BATCH_SIZE = 500

with table.batch(batch_size=BATCH_SIZE) as batch:
    for emp_id, name, dept, salary, country in rows:
        # Row key design: zero-padded ID for range scans
        row_key = f"emp:{emp_id:06d}".encode()
        batch.put(row_key, {
            b'personal:name':    name.encode(),
            b'personal:country': country.encode(),
            b'work:department':  dept.encode(),
            b'work:salary':      str(int(salary)).encode(),
        })

elapsed = time.time() - start
total   = sum(1 for _ in table.scan())
print(f"  Inserted: {total:,} rows in {elapsed:.2f}s ({total/elapsed:.0f} rows/sec)")

# ── Range scan to verify ──────────────────────────────────────────────────────
print("\n[B] Scan a range of rows (emp:000001 → emp:000010)")
for key, data in table.scan(row_start=b'emp:000001', row_stop=b'emp:000011'):
    name = data.get(b'personal:name', b'').decode()
    dept = data.get(b'work:department', b'').decode()
    print(f"  {key.decode()}: {name} — {dept}")

# ── Count by department (full scan with filter) ───────────────────────────────
print("\n[C] Count employees per department (scan + Python aggregation)")
from collections import Counter
dept_counts = Counter()
for _, data in table.scan(columns=[b'work:department']):
    dept = data.get(b'work:department', b'Unknown').decode()
    dept_counts[dept] += 1

for dept, count in sorted(dept_counts.items()):
    print(f"  {dept}: {count}")

# ── Cleanup ───────────────────────────────────────────────────────────────────
conn.disable_table(TABLE)
conn.delete_table(TABLE)
conn.close()
print("\n[OK] Done. Table dropped.")
