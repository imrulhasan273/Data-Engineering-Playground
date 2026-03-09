#!/usr/bin/env python3
"""
reducer.py — WordCount Reducer

Input  (stdin): word\t1  (sorted by key, from Hadoop shuffle)
Output (stdout): word\ttotal_count

Test locally:
    echo "Hello Hadoop Hello World" | python mapper.py | sort | python reducer.py
"""

import sys

current_word  = None
current_count = 0

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    word, count = line.split('\t', 1)
    count = int(count)

    if word == current_word:
        current_count += count
    else:
        if current_word is not None:
            print(f"{current_word}\t{current_count}")
        current_word  = word
        current_count = count

# Emit the last word
if current_word is not None:
    print(f"{current_word}\t{current_count}")
