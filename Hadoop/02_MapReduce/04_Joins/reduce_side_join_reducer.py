#!/usr/bin/env python3
"""
reduce_side_join_reducer.py — Reduce-Side Join Reducer

Input  (stdin): dept_id\t<E|D>|fields  (sorted by dept_id)
Output (stdout): emp_id, name, salary, dept_name, location

Strategy: buffer D (small) records, cross-join with E (large) records.
"""

import sys

current_key = None
dept_rows   = []     # small side buffered in memory
emp_rows    = []     # large side (could also stream instead of buffering)

def emit_joins(dept_rows, emp_rows):
    for dept in dept_rows:
        dept_name, location = dept
        for emp in emp_rows:
            emp_id, name, salary = emp
            print(f"{emp_id}\t{name}\t{salary}\t{dept_name}\t{location}")

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    key, value = line.split('\t', 1)
    tag, rest  = value.split('|', 1)

    if key != current_key:
        if current_key is not None:
            emit_joins(dept_rows, emp_rows)
        current_key = key
        dept_rows   = []
        emp_rows    = []

    if tag == 'D':
        parts = rest.split('|')
        dept_rows.append((parts[0], parts[1] if len(parts) > 1 else ''))
    elif tag == 'E':
        parts = rest.split('|')
        emp_rows.append((parts[0], parts[1], parts[2] if len(parts) > 2 else ''))

# Last group
if current_key is not None:
    emit_joins(dept_rows, emp_rows)
