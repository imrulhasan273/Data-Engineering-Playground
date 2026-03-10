#!/usr/bin/env python3
"""
map_side_join.py — Map-Side (Broadcast) Join via Distributed Cache

For joining a LARGE table with a SMALL lookup table.
The small table is loaded entirely into each mapper's memory.
No reducer needed — zero shuffle cost.

Usage (submit with run.sh):
    hadoop jar $STREAMING_JAR \
      -files "map_side_join.py,departments.csv" \
      -mapper "python3 map_side_join.py" \
      -reducer NONE \
      -numReduceTasks 0 \
      -input  /mr/joins/employees \
      -output /mr/joins/map_side_output

Local test:
    cat employees.csv | python3 map_side_join.py
"""

import sys
import os
import csv

# ── Load small lookup table into memory (once per mapper) ────────────────────
# The file is distributed to each mapper via -files
LOOKUP_FILE = 'departments.csv'   # shipped with -files

dept_lookup = {}   # dept_id → (dept_name, location)

if os.path.exists(LOOKUP_FILE):
    with open(LOOKUP_FILE, newline='') as f:
        for row in csv.reader(f):
            if len(row) >= 2:
                dept_id   = row[0].strip()
                dept_name = row[1].strip()
                location  = row[2].strip() if len(row) > 2 else 'Unknown'
                dept_lookup[dept_id] = (dept_name, location)
else:
    # Fallback for local testing without the file
    dept_lookup = {
        '10': ('Engineering', 'San Francisco'),
        '20': ('Marketing',   'New York'),
        '30': ('HR',          'Chicago'),
    }

# ── Stream and join employees with in-memory lookup ──────────────────────────
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    fields = line.split(',')
    if len(fields) < 3:
        continue

    emp_id  = fields[0].strip()
    name    = fields[1].strip()
    dept_id = fields[2].strip()
    salary  = fields[3].strip() if len(fields) > 3 else ''

    # Lookup — O(1), no network/shuffle
    if dept_id in dept_lookup:
        dept_name, location = dept_lookup[dept_id]
        print(f"{emp_id}\t{name}\t{salary}\t{dept_name}\t{location}")
    else:
        # Left join: emit NULLs for unmatched
        print(f"{emp_id}\t{name}\t{salary}\tNULL\tNULL")
