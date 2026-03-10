#!/usr/bin/env python3
"""
reduce_side_join_mapper.py — Reduce-Side Join Mapper

Joins two datasets: employees (emp_id, name, dept_id) and departments (dept_id, dept_name).
Both files are fed as input. The mapper tags each record with its source table.

Input  (stdin):  raw lines from BOTH input files
Output (stdout): dept_id\tsource_tag|rest_of_fields

Local test:
    cat employees.txt departments.txt | map_input_file=employees.txt python3 reduce_side_join_mapper.py | sort | python3 reduce_side_join_reducer.py

How it works:
  - Reducer receives all records grouped by dept_id
  - Records tagged "E" = employee rows, "D" = department rows
  - Reducer cross-joins D rows with E rows to produce output
"""

import sys
import os
import re

# Hadoop sets this to the current input file path
input_file = os.environ.get('map_input_file', '')
filename   = os.path.basename(input_file)

# Detect which dataset we're reading from by filename
if 'department' in filename.lower():
    tag = 'D'   # department record
else:
    tag = 'E'   # employee record (default)

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    fields = line.split(',')

    if tag == 'E':
        # Employee: emp_id, name, dept_id, salary
        if len(fields) < 3:
            continue
        emp_id   = fields[0].strip()
        name     = fields[1].strip()
        dept_id  = fields[2].strip()
        salary   = fields[3].strip() if len(fields) > 3 else ''
        # Key = dept_id  (join key), value = tagged record
        print(f"{dept_id}\tE|{emp_id}|{name}|{salary}")

    else:
        # Department: dept_id, dept_name, location
        if len(fields) < 2:
            continue
        dept_id   = fields[0].strip()
        dept_name = fields[1].strip()
        location  = fields[2].strip() if len(fields) > 2 else ''
        # Key = dept_id  (join key)
        print(f"{dept_id}\tD|{dept_name}|{location}")
