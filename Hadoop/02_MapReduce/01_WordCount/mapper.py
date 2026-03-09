#!/usr/bin/env python3
"""
mapper.py — WordCount Mapper

Input  (stdin):  one line of text per line
Output (stdout): word\t1  (one per token)

Test locally:
    echo "Hello Hadoop Hello World" | python mapper.py
"""

import sys
import re

for line in sys.stdin:
    # Lowercase and tokenize
    words = re.split(r'\W+', line.strip().lower())
    for word in words:
        if word:          # skip empty tokens
            print(f"{word}\t1")
