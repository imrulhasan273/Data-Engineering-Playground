"""
02_python_happybase.py — HBase Python API using HappyBase (Thrift-based)

Prerequisites:
    pip install happybase

Start Thrift server first:
    docker exec -it hadoop-hbase hbase thrift start &

Run:
    python 02_python_happybase.py
"""

import happybase

# ── Connect ───────────────────────────────────────────────────────────────────
print("=" * 48)
print("  HBase Python (HappyBase) Examples")
print("=" * 48)

conn = happybase.Connection(host='localhost', port=9090)
conn.open()
print("\n[OK] Connected to HBase via Thrift")

# ── 1. Table Management ───────────────────────────────────────────────────────
print("\n[1] Create table 'employees'")
if b'employees' in conn.tables():
    conn.disable_table('employees')
    conn.delete_table('employees')

conn.create_table(
    'employees',
    {
        'personal': dict(max_versions=3),
        'work':     dict(max_versions=1, compression='SNAPPY'),
    }
)
print("  Tables:", conn.tables())

# ── 2. Insert Rows ───────────────────────────────────────────────────────────
print("\n[2] Insert rows")
table = conn.table('employees')

employees = [
    ('emp:001', {'personal:name': 'Alice',  'personal:country': 'US',
                 'work:department': 'Engineering', 'work:salary': '95000'}),
    ('emp:002', {'personal:name': 'Bob',    'personal:country': 'US',
                 'work:department': 'Marketing',   'work:salary': '72000'}),
    ('emp:003', {'personal:name': 'Carol',  'personal:country': 'UK',
                 'work:department': 'Engineering', 'work:salary': '88000'}),
    ('emp:004', {'personal:name': 'Dave',   'personal:country': 'US',
                 'work:department': 'HR',           'work:salary': '65000'}),
    ('emp:005', {'personal:name': 'Eve',    'personal:country': 'DE',
                 'work:department': 'Engineering', 'work:salary': '105000'}),
]

for row_key, data in employees:
    table.put(row_key, data)
    print(f"  Inserted: {row_key}")

# ── 3. Get a Single Row ───────────────────────────────────────────────────────
print("\n[3] Get single row (emp:001)")
row = table.row(b'emp:001')
for col, val in row.items():
    print(f"  {col.decode()}: {val.decode()}")

# Get specific columns only
row = table.row(b'emp:001', columns=[b'personal:name', b'work:salary'])
print(f"  Name: {row[b'personal:name'].decode()}, Salary: {row[b'work:salary'].decode()}")

# ── 4. Get Multiple Rows ──────────────────────────────────────────────────────
print("\n[4] Get multiple rows")
rows = table.rows([b'emp:001', b'emp:003', b'emp:005'])
for row_key, data in rows:
    name   = data.get(b'personal:name', b'').decode()
    salary = data.get(b'work:salary',   b'').decode()
    print(f"  {row_key.decode()}: {name}, ${salary}")

# ── 5. Scan All Rows ──────────────────────────────────────────────────────────
print("\n[5] Scan all rows")
for key, data in table.scan():
    name = data.get(b'personal:name', b'?').decode()
    dept = data.get(b'work:department', b'?').decode()
    print(f"  {key.decode()}: {name} — {dept}")

# ── 6. Scan with Filters ─────────────────────────────────────────────────────
print("\n[6] Scan with row prefix filter")
for key, data in table.scan(row_prefix=b'emp:00'):
    print(f"  {key.decode()}: {data.get(b'personal:name', b'').decode()}")

print("\n[7] Scan row range")
for key, data in table.scan(row_start=b'emp:002', row_stop=b'emp:004'):
    print(f"  {key.decode()}: {data.get(b'personal:name', b'').decode()}")

print("\n[8] Scan specific columns only")
for key, data in table.scan(columns=[b'personal:name', b'work:salary']):
    name   = data.get(b'personal:name', b'').decode()
    salary = data.get(b'work:salary', b'').decode()
    print(f"  {key.decode()}: {name} = ${salary}")

# ── 7. Batch Write ────────────────────────────────────────────────────────────
print("\n[9] Batch insert (more efficient for bulk writes)")
with table.batch() as batch:
    for i in range(6, 11):
        row_key = f'emp:{i:03d}'
        batch.put(row_key, {
            'personal:name':    f'Employee{i}',
            'personal:country': 'US',
            'work:department':  'Finance',
            'work:salary':      str(60000 + i * 1000),
        })
print("  Batch of 5 rows inserted")
print(f"  Total rows: {sum(1 for _ in table.scan())}")

# ── 8. Increment a Counter ───────────────────────────────────────────────────
print("\n[10] Counter column (atomic increment)")
conn.create_table('counters', {'c': {}}) if b'counters' not in conn.tables() else None
ctable = conn.table('counters')
ctable.put('page:/home', {'c:views': happybase.hbase.ttypes.TCell})

# Use counter_inc for atomic increment
val = ctable.counter_inc(b'page:/home', b'c:views', value=1)
val = ctable.counter_inc(b'page:/home', b'c:views', value=1)
val = ctable.counter_inc(b'page:/home', b'c:views', value=5)
print(f"  Page views: {ctable.counter_get(b'page:/home', b'c:views')}")

# ── 9. Delete ────────────────────────────────────────────────────────────────
print("\n[11] Delete operations")
# Delete a specific column
table.delete(b'emp:001', columns=[b'work:salary'])
row = table.row(b'emp:001')
print(f"  After column delete: {list(row.keys())}")

# Delete entire row
table.delete(b'emp:010')
print(f"  Rows after row delete: {sum(1 for _ in table.scan())}")

# ── 10. Table Info ────────────────────────────────────────────────────────────
print("\n[12] Table families")
families = table.families()
for name, desc in families.items():
    print(f"  {name.decode()}: max_versions={desc.get('max_versions')}")

# ── Cleanup ───────────────────────────────────────────────────────────────────
conn.disable_table('employees')
conn.delete_table('employees')
if b'counters' in conn.tables():
    conn.disable_table('counters')
    conn.delete_table('counters')

conn.close()
print("\n[OK] Connection closed. All done.")
