#!/usr/bin/env python3
"""
udf_clean_name.py — Hive Python UDF (TRANSFORM)

Input  (stdin):  emp_id\tname\tcountry
Output (stdout): emp_id\tclean_name\tname_length\tcountry_code
"""

import sys
import re
import unicodedata

def clean_name(name: str) -> str:
    """Normalize unicode, strip non-alpha, title-case."""
    normalized = unicodedata.normalize('NFKC', name)
    cleaned    = re.sub(r'[^a-zA-Z\s\-]', '', normalized)
    return ' '.join(cleaned.split()).title()

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    fields  = line.split('\t')
    emp_id  = fields[0] if len(fields) > 0 else ''
    name    = fields[1] if len(fields) > 1 else ''
    country = fields[2] if len(fields) > 2 else ''

    cleaned      = clean_name(name)
    name_length  = len(cleaned)
    country_code = country.upper()[:2]  # normalize to 2-char code

    print(f"{emp_id}\t{cleaned}\t{name_length}\t{country_code}")
