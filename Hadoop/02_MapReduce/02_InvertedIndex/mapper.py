#!/usr/bin/env python3
"""
mapper.py — Inverted Index Mapper

Input  (stdin):  one line of text per line
Output (stdout): word\tfilename

The current input filename is available via the environment variable:
  map_input_file  (Hadoop Streaming sets this automatically)

Test locally:
    map_input_file=doc1.txt echo "hello world" | python mapper.py
"""

import sys
import os
import re

# Hadoop Streaming sets this env var to the current input file path
input_file = os.environ.get('map_input_file', 'unknown_file')
# Extract just the filename (basename)
filename = os.path.basename(input_file)

for line in sys.stdin:
    words = re.split(r'\W+', line.strip().lower())
    for word in words:
        if word:
            print(f"{word}\t{filename}")
