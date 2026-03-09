"""
02_wordcount.py — Spark Word Count (RDD + DataFrame APIs)

Usage:
    spark-submit --master yarn --deploy-mode client \\
      02_wordcount.py hdfs:///spark/input/sample.txt hdfs:///spark/output/wc
"""

import sys
import re
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    explode, split, lower, regexp_replace, col, count, desc
)

# ── Spark Session ─────────────────────────────────────────────────────────────
spark = SparkSession.builder \
    .appName("WordCount") \
    .config("spark.eventLog.enabled", "true") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")

input_path  = sys.argv[1] if len(sys.argv) > 1 else "hdfs:///spark/input/sample.txt"
output_path = sys.argv[2] if len(sys.argv) > 2 else "hdfs:///spark/output/wordcount"

print(f"\n Input:  {input_path}")
print(f" Output: {output_path}\n")

# ════════════════════════════════════════════════════════
# APPROACH 1: RDD API (classic Hadoop-style)
# ════════════════════════════════════════════════════════
print("=" * 48)
print("  RDD API Word Count")
print("=" * 48)

lines_rdd = spark.sparkContext.textFile(input_path)

word_counts_rdd = (
    lines_rdd
    .flatMap(lambda line: re.split(r'\W+', line.lower()))  # tokenize
    .filter(lambda w: len(w) > 1)                          # remove short tokens
    .map(lambda w: (w, 1))                                 # emit (word, 1)
    .reduceByKey(lambda a, b: a + b)                       # sum counts
    .sortBy(lambda x: x[1], ascending=False)               # sort by count desc
)

top_words = word_counts_rdd.take(10)
print("Top 10 words (RDD):")
for word, count_val in top_words:
    print(f"  {word:<20} {count_val}")

# ════════════════════════════════════════════════════════
# APPROACH 2: DataFrame / Spark SQL API (preferred)
# ════════════════════════════════════════════════════════
print("\n" + "=" * 48)
print("  DataFrame API Word Count")
print("=" * 48)

df = spark.read.text(input_path)

word_counts_df = (
    df
    .select(
        explode(
            split(regexp_replace(lower(col("value")), r'[^\w\s]', ''), r'\s+')
        ).alias("word")
    )
    .filter(col("word").rlike(r'\w{2,}'))  # only words with 2+ chars
    .groupBy("word")
    .agg(count("*").alias("count"))
    .orderBy(desc("count"))
)

print("Top 10 words (DataFrame):")
word_counts_df.show(10, truncate=False)

# ── Save output ───────────────────────────────────────────────────────────────
word_counts_df.write.mode("overwrite").csv(output_path, header=True)
print(f"\nOutput saved to: {output_path}")

# ── Statistics ────────────────────────────────────────────────────────────────
total_words  = word_counts_df.agg({"count": "sum"}).collect()[0][0]
unique_words = word_counts_df.count()
print(f"\nTotal words:  {total_words}")
print(f"Unique words: {unique_words}")

spark.stop()
