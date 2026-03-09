#!/usr/bin/env python3
"""
mapper.py — TopN Mapper

Reads WordCount output (word\tcount) and emits top-N candidates locally.
Emits: dummy_key\tcount\tword
A single reducer can then find the global top N.

Test locally:
    echo -e "hadoop\t5\napache\t3\nspark\t8" | python mapper.py
"""

import sys
import heapq
import os

N = int(os.environ.get('TOPN_N', '10'))

# Use a min-heap to keep top N locally
heap = []  # (count, word)

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split('\t')
    if len(parts) != 2:
        continue
    try:
        word  = parts[0]
        count = int(parts[1])
    except ValueError:
        continue

    heapq.heappush(heap, (count, word))
    if len(heap) > N:
        heapq.heappop(heap)  # remove smallest

# Emit local top-N candidates with dummy key
for count, word in heap:
    print(f"topn\t{count}\t{word}")
