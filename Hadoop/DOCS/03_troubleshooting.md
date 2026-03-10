# Troubleshooting Guide

Common issues and how to fix them, organized by component.
Commands are shown for **Linux (AlmaLinux 9)** and **Windows** where they differ.

---

## Cluster Won't Start

### Containers exit immediately after `docker compose up`

**Check logs first (same on all platforms):**
```bash
docker compose logs namenode
docker compose logs resourcemanager
docker compose logs hive
```

**NameNode exits with "Storage directory is not formatted":**
```bash
# Full reset — destroys all data (Linux / Mac / Git Bash / PowerShell)
docker compose down -v
docker compose up -d
```

### Port conflict (address already in use)

**Linux (AlmaLinux 9):**
```bash
# Find what's using port 9870
sudo ss -tlnp | grep 9870
# or
sudo lsof -i :9870

# Kill the process (replace PID)
sudo kill -9 <PID>

# Or change the port in .env and restart
nano 00_Setup/.env          # edit with nano
docker compose down && docker compose up -d
```

**Windows (PowerShell):**
```powershell
netstat -ano | findstr :9870

# Kill the process (replace PID with actual number)
taskkill /PID <PID> /F

# Or change the port in .env and restart
notepad 00_Setup\.env
docker compose down
docker compose up -d
```

### Docker daemon not running

**Linux (AlmaLinux 9):**
```bash
# Check status
sudo systemctl status docker

# Start Docker
sudo systemctl start docker

# Enable auto-start on boot
sudo systemctl enable docker

# If docker group issue (permission denied)
sudo usermod -aG docker $USER
newgrp docker    # apply group change without logout
```

**Windows:** Start Docker Desktop from the Start Menu and wait for it to show "Running" in the system tray (green icon).

### Not enough memory

**Linux VPS:**
```bash
# Check available RAM
free -h

# Check which containers use most memory
docker stats --no-stream

# If RAM < 6 GB, reduce YARN memory in .env:
# YARN_NODEMANAGER_MEMORY_MB=1024
# YARN_NODEMANAGER_VCORES=1
nano 00_Setup/.env
docker compose down && docker compose up -d
```

**Windows (Docker Desktop):**
```
Docker Desktop → Settings → Resources → Memory → set to 6 GB+
Click "Apply & Restart"
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

### WebHDFS not reachable from host / VPS

**Linux VPS — open firewall port:**
```bash
sudo firewall-cmd --add-port=9870/tcp --permanent
sudo firewall-cmd --reload

# Test WebHDFS from host
curl -s "http://localhost:9870/webhdfs/v1/?op=LISTSTATUS&user.name=root" | python3 -m json.tool
```

**Windows — test from browser or PowerShell:**
```powershell
Invoke-WebRequest "http://localhost:9870/webhdfs/v1/?op=LISTSTATUS&user.name=root"
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

**Windows (PowerShell) — check cluster metrics:**
```powershell
Invoke-WebRequest "http://localhost:8088/ws/v1/cluster/metrics" | ConvertFrom-Json | Select-Object -ExpandProperty clusterMetrics
```

### Job fails with "Container killed by the ApplicationMaster"
```bash
# Usually out of memory — increase container memory
hadoop jar $STREAMING_JAR \
  -jobconf mapreduce.map.memory.mb=2048 \
  -jobconf mapreduce.reduce.memory.mb=2048 \
  ...
```

### Find the Streaming JAR

**Linux / Mac / Git Bash:**
```bash
STREAMING_JAR=$(find /opt -name "hadoop-streaming*.jar" 2>/dev/null | head -1)
echo $STREAMING_JAR
```

**Inside NameNode container (always Linux):**
```bash
docker exec hadoop-namenode find /opt -name "hadoop-streaming*.jar" | head -1
```

**Windows (PowerShell) — set jar path after exec into container:**
```powershell
# Run this inside the container shell (docker exec -it hadoop-namenode bash)
# Then:  STREAMING_JAR=$(find /opt -name "hadoop-streaming*.jar" | head -1)
```

### Streaming job fails with "PipeMapRed.mapRedFinished"
```bash
# Your Python script is crashing. Test locally first:

# Linux / Mac / Git Bash:
echo "test input" | python3 mapper.py

# Windows (PowerShell):
echo "test input" | python mapper.py

# Check Python is available in container
docker exec -it hadoop-namenode python3 --version
```

### "Output directory already exists" error
```bash
# MapReduce refuses to overwrite output
hdfs dfs -rm -r /hdfs/output/path
# Then re-run the job
```

### Local pipeline test

**Linux / Mac / Git Bash:**
```bash
cat input.txt | python3 mapper.py | sort | python3 reducer.py
```

**Windows (PowerShell):**
```powershell
Get-Content input.txt | python mapper.py | Sort-Object | python reducer.py
```

**Windows (Git Bash) — recommended:**
```bash
cat input.txt | python3 mapper.py | sort | python3 reducer.py
```

### YARN logs: "GC overhead limit exceeded"
```bash
# Java heap space exhausted — increase JVM heap
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

-- Recompute statistics
ANALYZE TABLE sales PARTITION (year=2023) COMPUTE STATISTICS;
ANALYZE TABLE sales COMPUTE STATISTICS FOR COLUMNS category, amount;
```

### UPDATE/DELETE fails — transaction manager error
```sql
-- UPDATE/DELETE require ACID. Enable it:
SET hive.support.concurrency=true;
SET hive.txn.manager=org.apache.hadoop.hive.ql.lockmgr.DbTxnManager;

-- Table must be ORC + transactional=true
CREATE TABLE t (...) CLUSTERED BY (id) INTO 4 BUCKETS
STORED AS ORC TBLPROPERTIES ('transactional'='true');
```

### MSCK REPAIR TABLE not finding partitions
```bash
# Partition directories must follow naming convention: col=value
# hdfs:///warehouse/db/table/year=2024/month=01/
# Not: hdfs:///warehouse/db/table/2024/01/

# Check actual HDFS structure
hdfs dfs -ls /user/hive/warehouse/mydb.db/mytable/
```

### Metastore connection error
```bash
# PostgreSQL metastore may not be ready yet
docker compose logs postgres | tail -20

# Check Hive can reach PostgreSQL
docker exec -it hadoop-hive bash
PGPASSWORD=hive psql -h postgres -U hive -d hive_metastore -c "\dt"
```

### MapReduce/Tez task failed
```bash
# Get the YARN application ID from error output, then check logs:
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

# ZooKeeper must be running first (embedded in dajobe/hbase image)
```

### Python HappyBase connection refused
```bash
# Thrift server must be started first
docker exec -it hadoop-hbase bash
hbase thrift start &   # start in background
sleep 5

# Now connect from Python (default port 9090)

# Linux / Mac — from host:
python3 02_python_happybase.py

# Windows — from host (PowerShell):
python 02_python_happybase.py
```

### Install Python packages

**Linux (AlmaLinux 9):**
```bash
pip3 install happybase kazoo
```

**Windows:**
```powershell
pip install happybase kazoo
```

### Region not available after container restart
```bash
# HBase regions need time to re-assign after restart
# Wait 30-60 seconds, then retry
# Check Web UI: http://localhost:16010  (or http://YOUR_VPS_IP:16010)

# Force region reassignment if needed
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

# Windows (PowerShell):
# Invoke-WebRequest "http://localhost:8088/ws/v1/cluster/info" | ConvertFrom-Json
```

### Spark executor fails with "ExecutorLostFailure"
```bash
# Usually OOM — reduce executor memory pressure
spark-submit \
  --executor-memory 512m \
  --conf spark.memory.fraction=0.6 \
  --conf spark.sql.shuffle.partitions=10 \
  ...
```

### "Initial job has not accepted any resources"
```bash
# Not enough cluster resources
yarn node -list -all                # check available nodes
docker compose restart nodemanager  # restart if not responsive
```

### PySpark: ImportError / ModuleNotFoundError

**Linux:**
```bash
pip3 install pandas -t ./dependencies/
zip -r deps.zip dependencies/
spark-submit --py-files deps.zip script.py
```

**Windows (PowerShell):**
```powershell
pip install pandas -t .\dependencies\
Compress-Archive -Path .\dependencies\* -DestinationPath deps.zip
# Then submit from Git Bash or WSL2:
# spark-submit --py-files deps.zip script.py
```

**Windows (Git Bash):**
```bash
pip install pandas -t ./dependencies/
zip -r deps.zip dependencies/
spark-submit --py-files deps.zip script.py
```

---

## Sqoop Issues

### Connection refused to PostgreSQL
```bash
# Check PostgreSQL is running
docker ps | grep postgres
PGPASSWORD=hive psql -h postgres -U hive -d hive_metastore -c "SELECT 1"

# Use container hostname, not localhost
--connect jdbc:postgresql://postgres:5432/dbname   # NOT localhost

# PostgreSQL JDBC driver must be in Sqoop lib:
wget -q https://jdbc.postgresql.org/download/postgresql-42.7.4.jar \
  -O /opt/sqoop/lib/postgresql.jar
```

### Sqoop import: "No primary key could be found"
```bash
# Use --split-by to specify the split column
sqoop import ... --split-by id

# Or force single mapper (no split needed)
sqoop import ... --num-mappers 1
```

---

## Flume Issues

### Flume agent won't start

**Linux (AlmaLinux 9):**
```bash
# Check Java is installed
java -version

# Check Flume is in PATH
which flume-ng || echo "Add /opt/flume/bin to PATH"
export PATH=$PATH:/opt/flume/bin

# Check config syntax
flume-ng agent --conf-file 10_Flume/01_flume_basic.conf --name agent1 \
  -Dflume.root.logger=DEBUG,console
```

**Windows (Git Bash):**
```bash
# Same commands work in Git Bash if Flume is in PATH
export PATH=$PATH:/c/flume/bin
flume-ng agent --conf-file 10_Flume/01_flume_basic.conf --name agent1 \
  -Dflume.root.logger=DEBUG,console
```

### Flume HDFS sink can't write

```bash
# Ensure NameNode is running and reachable
hdfs dfs -ls /

# Check HDFS path exists
hdfs dfs -mkdir -p /flume/logs

# Verify Flume user has write permission
hdfs dfs -chmod 777 /flume
```

---

## ZooKeeper Issues

### zkCli.sh: connection refused

```bash
# Check ZooKeeper is running (embedded in HBase container)
docker ps | grep hbase
docker exec hadoop-hbase zkCli.sh -server localhost:2181 ls /

# Test ZK health with four-letter word
echo ruok | nc localhost 2181   # should return "imok"
```

**Windows (PowerShell):**
```powershell
# Use docker exec to run inside container
docker exec hadoop-hbase bash -c "echo ruok | nc localhost 2181"
```

### Python kazoo: connection error

**Linux:**
```bash
pip3 install kazoo
# Verify ZK is reachable
python3 -c "from kazoo.client import KazooClient; zk = KazooClient('localhost:2181'); zk.start(); print(zk.state); zk.stop()"
```

**Windows:**
```powershell
pip install kazoo
python -c "from kazoo.client import KazooClient; zk = KazooClient('localhost:2181'); zk.start(); print(zk.state); zk.stop()"
```

---

## General Debugging

### Check container resource usage

```bash
# All platforms
docker stats --no-stream   # snapshot of CPU/memory for all containers
docker stats               # live (Ctrl+C to stop)
```

### Get full log for any YARN application

**Linux / Mac / Git Bash:**
```bash
yarn logs -applicationId application_XXXXX_XXXX > job.log 2>&1
grep -i "error\|exception\|failed" job.log | head -30
```

**Windows (PowerShell):**
```powershell
yarn logs -applicationId application_XXXXX_XXXX | Out-File job.log
Select-String -Path job.log -Pattern "error|exception|failed" | Select-Object -First 30
```

### Enable debug logging for Hive

```sql
SET hive.log.level=DEBUG;
-- Run your query
-- Check log:
```
```bash
docker exec -it hadoop-hive tail -f /tmp/root/hive.log
```

### Test HDFS from Python/Spark

```python
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("test").getOrCreate()
spark.sparkContext.textFile("hdfs:///user/").take(1)
```

### Copy files into container

**Linux / Mac / Git Bash:**
```bash
docker cp ./script.sh hadoop-namenode:/tmp/script.sh
docker cp ./scripts/ hadoop-namenode:/opt/scripts/
```

**Windows (PowerShell):**
```powershell
docker cp .\script.sh hadoop-namenode:/tmp/script.sh
docker cp .\scripts\ hadoop-namenode:/opt/scripts/
```

### Line ending issues (Windows → Linux)

If scripts fail with "bad interpreter" or strange parse errors after editing on Windows:

**Git Bash or WSL2:**
```bash
# Install dos2unix (if not available)
# WSL2 Ubuntu: sudo apt install dos2unix
# Git Bash: bundled

dos2unix 01_HDFS/01_basic_operations.sh
dos2unix 00_Setup/verify_setup.sh

# Prevent future issues
git config --global core.autocrlf input
```

**Using sed (Git Bash / Linux / WSL2):**
```bash
sed -i 's/\r//' script.sh
```

**Windows (PowerShell) — convert before copying:**
```powershell
(Get-Content script.sh -Raw) -replace "`r`n", "`n" | Set-Content script.sh -NoNewline
```
