#!/usr/bin/env python3
"""
reducer.py — TopN Reducer

Receives all local top-N candidates and emits the global top N sorted by count.
Input:  topn\tcount\tword
Output: word\tcount  (sorted descending by count)

Test locally:
    echo -e "hadoop\t5\napache\t3\nspark\t8" | python mapper.py | sort | python reducer.py
"""

import sys
import heapq
import os

N = int(os.environ.get('TOPN_N', '10'))
candidates = []  # (count, word)

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split('\t')
    if len(parts) != 3:
        continue
    try:
        count = int(parts[1])
        word  = parts[2]
    except ValueError:
        continue
    candidates.append((count, word))

# Sort descending and emit top N
candidates.sort(key=lambda x: -x[0])
for count, word in candidates[:N]:
    print(f"{word}\t{count}")
