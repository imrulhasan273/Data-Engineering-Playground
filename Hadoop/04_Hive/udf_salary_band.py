#!/usr/bin/env python3
"""
udf_salary_band.py — Hive Python UDF (TRANSFORM)

Input  (stdin):  name\tsalary\tdepartment   (tab-separated by Hive)
Output (stdout): name\tsalary\tband\ttax_rate

Upload to container then register:
    docker cp udf_salary_band.py hadoop-hive:/tmp/hive_scripts/
    -- In Beeline: ADD FILE /tmp/hive_scripts/udf_salary_band.py;
"""

import sys

# Country-based tax rates
TAX_RATES = {'US': 0.30, 'UK': 0.40, 'DE': 0.35, 'default': 0.25}

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    fields  = line.split('\t')
    name    = fields[0] if len(fields) > 0 else ''
    salary  = float(fields[1]) if len(fields) > 1 and fields[1] else 0.0
    dept    = fields[2] if len(fields) > 2 else ''

    # Classify salary band
    if salary >= 100_000:
        band = 'Senior'
    elif salary >= 80_000:
        band = 'Mid'
    else:
        band = 'Junior'

    # Default tax (country not in input here; use dept as proxy)
    tax_rate = 0.30

    print(f"{name}\t{salary}\t{band}\t{tax_rate}")
