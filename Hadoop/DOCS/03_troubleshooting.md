# Troubleshooting Guide

Common issues and how to fix them, organized by component.

---

## Cluster Won't Start

### Containers exit immediately after `docker compose up`

**Check logs first:**
```bash
docker compose logs namenode
docker compose logs resourcemanager
docker compose logs hive
```

**NameNode exits with "Storage directory is not formatted":**
```bash
# Full reset — destroys all data
docker compose down -v
docker compose up -d
```

**Port conflict (address already in use):**
```bash
# Find what's using port 9870
netstat -ano | findstr :9870    # Windows
lsof -i :9870                   # Linux/Mac

# Fix: edit .env and change the conflicting port, then restart
docker compose down && docker compose up -d
```

**Docker Desktop not running:**
```
Error: Cannot connect to the Docker daemon
Fix: Start Docker Desktop and wait for it to be "Running"
```

**Not enough memory:**
```bash
# Docker Desktop needs at least 6 GB assigned
# Settings → Resources → Memory → set to 6GB+
docker stats   # check current usage
```

---

## HDFS Issues

### `hdfs dfs -put` fails — "No such file or directory"
```bash
# Create parent directory first
hdfs dfs -mkdir -p /user/hadoop/data
hdfs dfs -put localfile.txt /user/hadoop/data/
```

### `hdfs dfs -put` fails — "File exists"
```bash
# Use -f to overwrite
hdfs dfs -put -f localfile.txt /hdfs/path/file.txt
```

### Cannot write to HDFS — "Name node is in safe mode"
```bash
# Check safe mode status
hdfs dfsadmin -safemode get

# Manually exit (only if cluster is healthy)
hdfs dfsadmin -safemode leave
```

### NameNode reports 0 live DataNodes
```bash
# Check if DataNodes are running
docker compose ps

# Check DataNode logs
docker compose logs datanode1

# Restart DataNodes
docker compose restart datanode1 datanode2

# Wait 30 seconds then check
hdfs dfsadmin -report
```

### HDFS is full / quota exceeded
```bash
# Check usage
hdfs dfs -du -s -h /

# Check quotas
hdfs dfs -count -q -h /user/

# Remove large/unnecessary data
hdfs dfs -rm -r /tmp/old_outputs/

# Increase space quota (admin)
hdfs dfsadmin -setSpaceQuota 100g /user/hadoop
```

### `hdfs fsck` shows corrupt blocks
```bash
# List all corrupt files
hdfs fsck / -list-corruptfileblocks

# Delete corrupt files (only if you can re-generate them)
hdfs fsck /path -delete

# Check DataNode health
hdfs dfsadmin -report | grep -A5 "Dead datanodes"
```

---

## MapReduce / YARN Issues

### Job stays in ACCEPTED state and never runs
```bash
# ResourceManager has no available containers
yarn node -list -all      # check if NodeManagers are running

# Check cluster resources
curl http://localhost:8088/ws/v1/cluster/metrics | python3 -m json.tool | grep -E "availableMB|allocatedMB"

# Fix: NodeManager may be down
docker compose restart nodemanager
```

### Job fails with "Container killed by the ApplicationMaster"
```bash
# Usually out of memory — increase container memory
hadoop jar $STREAMING_JAR \
  -jobconf mapreduce.map.memory.mb=2048 \
  -jobconf mapreduce.reduce.memory.mb=2048 \
  ...
```

### Streaming job fails with "PipeMapRed.mapRedFinished: java.io.IOException"
```bash
# Your Python script is crashing. Test it locally first:
echo "test input" | python3 mapper.py
# Fix Python errors before re-submitting

# Also check: Python3 installed in container?
docker exec -it hadoop-namenode python3 --version
```

### "Output directory already exists" error
```bash
# MapReduce refuses to overwrite output
hdfs dfs -rm -r /hdfs/output/path
# Then re-run the job
```

### Job runs but reducer output is wrong / missing
```bash
# Missing sort between mapper and reducer in local test?
# Correct local pipeline:
cat input.txt | python3 mapper.py | sort | python3 reducer.py
#                                   ^^^^ sort is critical

# In Hadoop Streaming, Hadoop handles the sort automatically
```

### Streaming job: mapper.py: No such file or directory
```bash
# Must ship the files to all nodes with -files
hadoop jar $STREAMING_JAR \
  -files "mapper.py,reducer.py" \    # <-- this line is required
  -mapper "python3 mapper.py" \
  ...
```

### YARN logs: "GC overhead limit exceeded"
```bash
# Java heap space exhausted — increase JVM heap
# For MapReduce:
-jobconf mapreduce.map.java.opts=-Xmx1g
-jobconf mapreduce.reduce.java.opts=-Xmx2g
```

---

## Hive Issues

### Beeline can't connect
```bash
# Check if HiveServer2 is running
docker ps | grep hive
docker compose logs hive | tail -30

# Wait for HiveServer2 to finish starting (takes 1-2 minutes)
# It's ready when you see: "Started HiveServer2"

# Try connecting with explicit credentials
beeline -u "jdbc:hive2://localhost:10000" -n root -p ''
```

### Hive query runs slowly / no partition pruning
```sql
-- Verify partition columns are in WHERE clause
EXPLAIN SELECT * FROM sales WHERE year=2023 AND month='Jan';
-- Look for "Partition Condition" in the plan

-- Check if statistics exist
DESCRIBE FORMATTED tablename PARTITION (year=2023);

-- Recompute statistics
ANALYZE TABLE sales PARTITION (year=2023) COMPUTE STATISTICS;
ANALYZE TABLE sales COMPUTE STATISTICS FOR COLUMNS category, amount;
```

### "FAILED: SemanticException [Error 10294]: Attempt to do update or delete using transaction manager that does not support these operations"
```sql
-- UPDATE/DELETE require ACID. Enable it:
SET hive.support.concurrency=true;
SET hive.txn.manager=org.apache.hadoop.hive.ql.lockmgr.DbTxnManager;

-- Also: table must be ORC + transactional=true
CREATE TABLE t (...) CLUSTERED BY (id) INTO 4 BUCKETS
STORED AS ORC TBLPROPERTIES ('transactional'='true');
```

### "MSCK REPAIR TABLE" not finding partitions
```bash
# Partition directories must follow naming convention: col=value
# hdfs:///warehouse/db/table/year=2024/month=01/
# Not: hdfs:///warehouse/db/table/2024/01/

# Check actual HDFS structure
hdfs dfs -ls /user/hive/warehouse/mydb.db/mytable/
```

### Metastore connection error
```bash
# MySQL metastore may not be ready yet
docker compose logs mysql | tail -20

# Check Hive can reach MySQL
docker exec -it hadoop-hive bash
mysql -h mysql -u hive -phive hive_metastore -e "SHOW TABLES;"
```

### "Error: Execution Error, return code 2 from org.apache.hadoop.hive.ql.exec.mr.MapRedTask"
```bash
# MapReduce task failed. Get the YARN application ID from error output
# Then check logs:
yarn logs -applicationId application_XXXXXXX_XXXX

# Or check Hive log:
docker exec -it hadoop-hive tail -100 /tmp/root/hive.log
```

---

## HBase Issues

### HBase shell hangs on connect
```bash
# Check if HBase master is running
docker ps | grep hbase
docker compose logs hbase | tail -30

# ZooKeeper must be running first
# dajobe/hbase manages its own ZooKeeper
```

### Python HappyBase connection refused
```bash
# Thrift server must be started first
docker exec -it hadoop-hbase bash
hbase thrift start &   # start in background
sleep 5

# Now connect from Python (default port 9090)
python3 02_python_happybase.py
```

### Region not available / Table not found after container restart
```bash
# HBase regions need time to re-assign after restart
# Wait 30-60 seconds then retry
# Check in Web UI: http://localhost:16010

# Force region reassignment
echo "assign '<region_id>'" | hbase shell
```

---

## Spark Issues

### `spark-submit` fails: "YARN cluster is unavailable"
```bash
# ResourceManager must be running
docker compose ps resourcemanager

# Check YARN is healthy
curl http://localhost:8088/ws/v1/cluster/info | python3 -m json.tool
```

### Spark executor fails with "ExecutorLostFailure"
```bash
# Usually OOM — reduce executor memory pressure
spark-submit \
  --executor-memory 512m \          # reduce memory
  --conf spark.memory.fraction=0.6 \
  --conf spark.sql.shuffle.partitions=10 \
  ...
```

### "Initial job has not accepted any resources"
```bash
# Not enough cluster resources
yarn node -list -all                 # check available nodes
docker compose restart nodemanager  # restart if not responsive
```

### PySpark: ImportError / ModuleNotFoundError
```bash
# Install the package on all nodes OR ship it with --py-files
pip install pandas -t ./dependencies/
zip -r deps.zip dependencies/

spark-submit --py-files deps.zip script.py
```

---

## Sqoop Issues

### Connection refused to MySQL
```bash
# Check MySQL is running
docker ps | grep mysql
mysql -h mysql -u hive -phive hive_metastore -e "SELECT 1"

# Use container hostname, not localhost
--connect jdbc:mysql://mysql:3306/dbname   # NOT localhost
```

### Sqoop import: "Error during import: No primary key could be found"
```bash
# Use --split-by to specify the split column
sqoop import ... --split-by id

# Or force single mapper (no split needed)
sqoop import ... --num-mappers 1
```

### Data truncation / type mismatch
```bash
# Map JDBC types explicitly
sqoop import \
  --map-column-java created_at=String \   # force Java type
  --map-column-hive created_at=STRING     # force Hive type
```

---

## General Debugging Tips

### Check container resource usage
```bash
docker stats --no-stream   # snapshot of CPU/memory for all containers
```

### Get full log for any YARN application
```bash
yarn logs -applicationId application_XXXXX_XXXX > job.log 2>&1
grep -i "error\|exception\|failed" job.log | head -30
```

### Enable debug logging for a Hive query
```sql
SET hive.log.level=DEBUG;
-- Run your query
-- Check: docker exec -it hadoop-hive tail -f /tmp/root/hive.log
```

### Test HDFS connectivity from within Python/Spark
```python
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("test").getOrCreate()
spark.sparkContext.textFile("hdfs:///user/").take(1)
```

### Windows-specific: line ending issues in shell scripts
```bash
# If scripts fail with "No such file" or strange parse errors:
# Convert CRLF → LF
dos2unix script.sh

# Or use Git Bash setting:
git config --global core.autocrlf input
```
