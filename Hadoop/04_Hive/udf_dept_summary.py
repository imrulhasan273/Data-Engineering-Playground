#!/usr/bin/env python3
"""
udf_dept_summary.py — Hive Python Aggregate UDF (TRANSFORM + CLUSTER BY)

Input  (stdin):  department\tsalary  (sorted by department via CLUSTER BY)
Output (stdout): department\theadcount\tavg_salary\tsalary_range

Because CLUSTER BY guarantees all rows for a dept arrive together,
we can aggregate without a reducer.
"""

import sys

current_dept = None
salaries     = []

def emit(dept, salaries):
    if not salaries:
        return
    headcount    = len(salaries)
    avg_salary   = sum(salaries) / headcount
    salary_range = max(salaries) - min(salaries)
    print(f"{dept}\t{headcount}\t{avg_salary:.2f}\t{salary_range:.2f}")

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    fields = line.split('\t')
    dept   = fields[0] if len(fields) > 0 else ''
    salary = float(fields[1]) if len(fields) > 1 and fields[1] else 0.0

    if dept != current_dept:
        if current_dept is not None:
            emit(current_dept, salaries)
        current_dept = dept
        salaries     = []

    salaries.append(salary)

if current_dept is not None:
    emit(current_dept, salaries)
