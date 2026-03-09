"""
03_dataframe_ops.py — Spark DataFrame operations on Hive/HDFS data

Usage:
    spark-submit --master yarn --deploy-mode client 03_dataframe_ops.py
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, avg, sum as spark_sum, max as spark_max, min as spark_min,
    count, when, round as spark_round, year, month,
    row_number, rank, lag, desc, asc
)
from pyspark.sql.window import Window
from pyspark.sql.types import StructType, StructField, IntegerType, StringType, DoubleType

spark = SparkSession.builder \
    .appName("DataFrameOps") \
    .enableHiveSupport() \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")

# ── 1. Read from HDFS CSV ─────────────────────────────────────────────────────
print("\n[1] Read CSV from HDFS")
schema = StructType([
    StructField("emp_id",     IntegerType(), True),
    StructField("name",       StringType(),  True),
    StructField("department", StringType(),  True),
    StructField("salary",     DoubleType(),  True),
    StructField("hire_date",  StringType(),  True),
    StructField("country",    StringType(),  True),
])

df = spark.read.csv(
    "hdfs:///hive/raw/employees/employees.csv",
    schema=schema,
    header=False
)
df.printSchema()
df.show()

# ── 2. Aggregations ───────────────────────────────────────────────────────────
print("\n[2] Department Statistics")
df.groupBy("department") \
  .agg(
    count("*").alias("headcount"),
    spark_round(avg("salary"), 2).alias("avg_salary"),
    spark_max("salary").alias("max_salary"),
    spark_min("salary").alias("min_salary"),
    spark_sum("salary").alias("total_payroll"),
  ) \
  .orderBy(desc("avg_salary")) \
  .show()

# ── 3. Filtering and Projection ───────────────────────────────────────────────
print("\n[3] High earners in Engineering")
df.filter((col("department") == "Engineering") & (col("salary") > 85000)) \
  .select("name", "salary", "country") \
  .orderBy(desc("salary")) \
  .show()

# ── 4. Conditional Columns ────────────────────────────────────────────────────
print("\n[4] Salary bands")
df.withColumn(
    "band",
    when(col("salary") >= 100000, "Senior")
    .when(col("salary") >= 80000,  "Mid")
    .otherwise("Junior")
) \
  .select("name", "salary", "band") \
  .show()

# ── 5. Window Functions ───────────────────────────────────────────────────────
print("\n[5] Rank within department")
window_dept = Window.partitionBy("department").orderBy(desc("salary"))

df.withColumn("rank", rank().over(window_dept)) \
  .withColumn("prev_salary", lag("salary", 1).over(window_dept)) \
  .select("name", "department", "salary", "rank", "prev_salary") \
  .orderBy("department", "rank") \
  .show()

# ── 6. Write to HDFS as Parquet ───────────────────────────────────────────────
print("\n[6] Write to HDFS as Parquet")
df.write \
  .mode("overwrite") \
  .partitionBy("country") \
  .parquet("hdfs:///spark/output/employees_parquet")
print("  Written: hdfs:///spark/output/employees_parquet")

# ── 7. Read back and verify ───────────────────────────────────────────────────
parquet_df = spark.read.parquet("hdfs:///spark/output/employees_parquet")
print(f"  Rows read back: {parquet_df.count()}")

# ── 8. SQL API ────────────────────────────────────────────────────────────────
print("\n[8] Spark SQL")
df.createOrReplaceTempView("employees")

spark.sql("""
  SELECT department,
         COUNT(*)       AS headcount,
         AVG(salary)    AS avg_salary
  FROM   employees
  GROUP BY department
  ORDER BY avg_salary DESC
""").show()

spark.stop()
