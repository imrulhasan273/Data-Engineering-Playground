#!/usr/bin/env python3
"""
reducer.py — Inverted Index Reducer

Input  (stdin): word\tfilename  (sorted by word)
Output (stdout): word\tfile1:3,file2:1  (word → files with occurrence counts)

Test locally:
    cat doc1.txt doc2.txt | python mapper.py | sort | python reducer.py
"""

import sys
from collections import defaultdict

current_word = None
file_counts  = defaultdict(int)

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue

    word, filename = line.split('\t', 1)

    if word != current_word:
        # Emit previous word's posting list
        if current_word is not None:
            posting = ','.join(
                f"{f}:{c}" for f, c in sorted(file_counts.items())
            )
            print(f"{current_word}\t{posting}")
        current_word = word
        file_counts  = defaultdict(int)

    file_counts[filename] += 1

# Emit last word
if current_word is not None:
    posting = ','.join(f"{f}:{c}" for f, c in sorted(file_counts.items()))
    print(f"{current_word}\t{posting}")
