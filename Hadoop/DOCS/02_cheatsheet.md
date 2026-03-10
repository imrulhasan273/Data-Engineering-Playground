# Hadoop Commands Cheatsheet

All essential commands in one place. Copy-paste ready.

> **Platform notes:**
> - Most commands here are **bash** — run them on Linux / Mac / Git Bash (Windows) or inside a Docker container
> - Docker commands (`docker exec`, `docker compose`) work identically on Linux and Windows PowerShell
> - Inside containers the OS is always Linux — all paths use forward slashes `/`
> - Windows-specific alternatives are noted with **[Windows PS]**

---

## Install Docker

**Linux (AlmaLinux 9 / RHEL):**
```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER   # run without sudo (re-login after)
```

**Ubuntu / Debian:**
```bash
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

**Windows:** Install Docker Desktop from https://www.docker.com/products/docker-desktop/

---

## Connect to Containers

```bash
# Linux / Mac / Git Bash / PowerShell — all identical
docker exec -it hadoop-namenode  bash   # HDFS, YARN, MapReduce, Pig, Sqoop
docker exec -it hadoop-hive      bash   # Hive / Beeline
docker exec -it hadoop-hbase     bash   # HBase shell
docker exec -it hadoop-spark     bash   # Spark submit
docker exec -it hadoop-postgres  bash   # PostgreSQL (psql -U hive -d hive_metastore)
```

---

## HDFS (`hdfs dfs`)

### Navigation & Listing
```bash
hdfs dfs -ls /                          # list root
hdfs dfs -ls -h /user/hadoop/           # human-readable sizes
hdfs dfs -ls -R /data/                  # recursive listing
hdfs dfs -du -h /data/                  # disk usage per file/dir
hdfs dfs -du -s -h /data/               # total size of directory
hdfs dfs -count /data/                  # dirs, files, bytes
hdfs dfs -count -q -h /data/            # with quota info
```

### Create / Delete
```bash
hdfs dfs -mkdir /newdir
hdfs dfs -mkdir -p /a/b/c               # create parents too
hdfs dfs -rm /file.txt                  # delete file (to trash)
hdfs dfs -rm -r /directory/             # delete directory recursively
hdfs dfs -rm -skipTrash /file.txt       # permanent delete (no trash)
hdfs dfs -rmdir /emptydir               # delete empty directory only
```

### Upload / Download
```bash
hdfs dfs -put localfile.txt /hdfs/path/         # upload
hdfs dfs -put -f localfile.txt /hdfs/path/      # overwrite if exists
hdfs dfs -copyFromLocal file.txt /hdfs/path/    # same as -put
hdfs dfs -moveFromLocal file.txt /hdfs/path/    # upload + delete local

hdfs dfs -get /hdfs/file.txt localfile.txt      # download
hdfs dfs -copyToLocal /hdfs/file.txt local/     # same as -get
hdfs dfs -getmerge /hdfs/dir/ merged.txt        # merge all files in dir
```

### Read
```bash
hdfs dfs -cat /hdfs/file.txt            # print file contents
hdfs dfs -head /hdfs/file.txt           # first 1KB
hdfs dfs -tail /hdfs/file.txt           # last 1KB
hdfs dfs -text /hdfs/file.seq           # decode SequenceFile/Avro/gzip
```

### Copy / Move within HDFS
```bash
hdfs dfs -cp /src/file.txt /dst/file.txt
hdfs dfs -cp -p /src/ /dst/             # preserve timestamps/permissions
hdfs dfs -mv /old/path /new/path        # rename / move
```

### Permissions
```bash
hdfs dfs -chmod 755 /path
hdfs dfs -chmod -R 750 /dir/            # recursive
hdfs dfs -chown user /path
hdfs dfs -chown user:group /path
hdfs dfs -chgrp groupname /path

hdfs dfs -setfacl -m user:alice:rwx /path       # set ACL
hdfs dfs -setfacl -m default:group:devs:r-x /dir  # default ACL on dir
hdfs dfs -getfacl /path                          # view ACLs
hdfs dfs -setfacl -x user:alice /path           # remove ACL entry
hdfs dfs -setfacl -b /path                      # remove all ACLs
```

### Replication & Snapshots
```bash
hdfs dfs -setrep 2 /path/file.txt               # change replication
hdfs dfs -setrep -w 2 /path/file.txt            # wait until done
hdfs dfs -setrep -R 2 /directory/               # recursive
hdfs dfs -stat "%r" /file.txt                   # check replication factor

hdfs dfsadmin -allowSnapshot /data/dir          # enable snapshots on dir
hdfs dfs -createSnapshot /data/dir snap1        # take snapshot
hdfs dfs -ls /data/dir/.snapshot/               # list snapshots
hdfs dfs -cat /data/dir/.snapshot/snap1/file    # read from snapshot
hdfs snapshotDiff /data/dir snap1 snap2         # diff two snapshots
hdfs dfs -renameSnapshot /data/dir snap1 v1     # rename snapshot
hdfs dfs -deleteSnapshot /data/dir snap1        # delete snapshot
hdfs dfsadmin -disallowSnapshot /data/dir       # disable snapshots
```

### File Information
```bash
hdfs dfs -stat /file.txt                        # file info
hdfs dfs -stat "%n %b %r %o" /file.txt          # name, bytes, replication, blocksize
hdfs fsck /path -files -blocks -locations       # block details
hdfs fsck /       -summary                      # cluster-wide health
hdfs fsck / -list-corruptfileblocks             # corrupted blocks
```

### Admin Commands
```bash
hdfs dfsadmin -report                           # cluster overview
hdfs dfsadmin -safemode get                     # check safe mode
hdfs dfsadmin -safemode enter                   # enter safe mode
hdfs dfsadmin -safemode leave                   # exit safe mode
hdfs dfsadmin -setQuota 1000 /path              # namespace quota
hdfs dfsadmin -setSpaceQuota 10g /path          # space quota
hdfs dfsadmin -clrQuota /path                   # remove namespace quota
hdfs dfsadmin -clrSpaceQuota /path              # remove space quota
hdfs dfsadmin -refreshNodes                     # re-read includes/excludes
hdfs dfsadmin -printTopology                    # rack topology
```

### Trash
```bash
hdfs dfs -expunge                               # permanently delete trash
# Trash location: /user/<username>/.Trash/Current/
# Set fs.trash.interval in core-site.xml (minutes, 0=disabled)
```

---

## YARN

### Applications
```bash
yarn application -list                          # running apps
yarn application -list -appStates ALL           # all states
yarn application -list -appTypes MAPREDUCE      # filter by type
yarn application -status <app_id>               # app details
yarn application -kill <app_id>                 # kill running app
yarn logs -applicationId <app_id>               # fetch logs
yarn logs -applicationId <app_id> -containerId <c_id>  # specific container
```

### Nodes & Cluster
```bash
yarn node -list -all                            # all NodeManagers
yarn node -status <node_id>                     # node details
yarn cluster --status                           # cluster info
yarn queue -status default                      # queue info
```

### Job History
```bash
yarn application -list -appStates FINISHED      # completed jobs
mapred job -list all                            # via mapred tool
mapred job -status <job_id>                     # job status
mapred job -logs <job_id>                       # job logs
mapred job -kill <job_id>                       # kill job
```

---

## MapReduce Streaming (Python)

### Submit a Job
```bash
STREAMING_JAR=$(find /opt -name "hadoop-streaming*.jar" | head -1)

hadoop jar "$STREAMING_JAR" \
  -files   "mapper.py,reducer.py" \        # ship scripts to all nodes
  -mapper  "python3 mapper.py" \
  -reducer "python3 reducer.py" \
  -input   "/hdfs/input/path" \
  -output  "/hdfs/output/path" \
  -numReduceTasks 4                         # reducer parallelism
```

### Advanced Streaming Options
```bash
hadoop jar "$STREAMING_JAR" \
  -files   "mapper.py,reducer.py,config.json" \
  -mapper  "python3 mapper.py" \
  -combiner "python3 reducer.py" \          # optional combiner
  -reducer "python3 reducer.py" \
  -input   "/in" \
  -output  "/out" \
  -numReduceTasks 2 \
  -cmdenv  "MY_VAR=value" \                 # pass env var to scripts
  -inputformat  "org.apache.hadoop.mapred.TextInputFormat" \
  -outputformat "org.apache.hadoop.mapred.TextOutputFormat" \
  -jobconf "mapreduce.job.name=MyJob" \
  -jobconf "mapreduce.map.memory.mb=1024" \
  -jobconf "mapreduce.reduce.memory.mb=2048"
```

### Local Pipeline Test

**Linux / Mac / Git Bash:**
```bash
# Simulate MapReduce without Hadoop
cat input.txt | python3 mapper.py | sort | python3 reducer.py

# With env var
cat wordcount_output.txt \
  | TOPN_N=10 python3 mapper.py \
  | sort \
  | TOPN_N=10 python3 reducer.py
```

**Windows (PowerShell):**
```powershell
# Basic pipeline
Get-Content input.txt | python mapper.py | Sort-Object | python reducer.py

# With env var — set before running
$env:TOPN_N = "10"
Get-Content wordcount_output.txt | python mapper.py | Sort-Object | python reducer.py
```

**Windows (Git Bash) — recommended (same as Linux):**
```bash
cat input.txt | python3 mapper.py | sort | python3 reducer.py
TOPN_N=10 python3 mapper.py < input.txt | sort | TOPN_N=10 python3 reducer.py
```

---

## Hive / Beeline

### Connect
```bash
beeline -u "jdbc:hive2://localhost:10000"                   # interactive shell
beeline -u "jdbc:hive2://localhost:10000" -e "SHOW TABLES"  # one-liner
beeline -u "jdbc:hive2://localhost:10000" -f query.hql      # run file
beeline -u "jdbc:hive2://localhost:10000" \
  --outputformat=csv2 \                                      # CSV output
  -e "SELECT * FROM employees" > output.csv
```

### Inside Beeline / HiveQL
```sql
-- Database
SHOW DATABASES;
CREATE DATABASE mydb;
USE mydb;
DROP DATABASE mydb CASCADE;

-- Tables
SHOW TABLES;
SHOW TABLES LIKE 'emp*';
DESCRIBE tablename;
DESCRIBE FORMATTED tablename;   -- full details
SHOW PARTITIONS tablename;
SHOW CREATE TABLE tablename;    -- DDL

-- Settings
SET hive.execution.engine=tez;
SET hive.exec.dynamic.partition.mode=nonstrict;
SET hive.auto.convert.join=true;
SET hive.vectorized.execution.enabled=true;

-- Explain a query
EXPLAIN SELECT * FROM employees WHERE department='Engineering';
EXPLAIN EXTENDED SELECT ...;    -- detailed plan
```

---

## HBase Shell

### Connect
```bash
hbase shell                     # interactive shell
hbase shell script.rb           # run HBase Ruby script
hbase version
```

### Inside HBase Shell
```ruby
# Status
status
list                            # all tables
describe 'tablename'
exists 'tablename'
is_enabled 'tablename'

# Create / Drop
create 'mytable', 'cf1', 'cf2'
create 'mytable', {NAME => 'cf1', VERSIONS => 3, COMPRESSION => 'SNAPPY'}
disable 'mytable'               # must disable before alter/drop
enable 'mytable'
drop 'mytable'
alter 'mytable', {NAME => 'cf3', VERSIONS => 5}

# CRUD
put 'table', 'rowkey', 'cf:col', 'value'
get 'table', 'rowkey'
get 'table', 'rowkey', 'cf:col'
get 'table', 'rowkey', {COLUMN => 'cf:col', VERSIONS => 3}
delete 'table', 'rowkey', 'cf:col'    # delete column
deleteall 'table', 'rowkey'           # delete entire row

# Scan
scan 'table'
scan 'table', {LIMIT => 10}
scan 'table', {STARTROW => 'a', STOPROW => 'b'}
scan 'table', {COLUMNS => ['cf:col1', 'cf:col2']}
scan 'table', {FILTER => "ValueFilter(=, 'binary:myvalue')"}
scan 'table', {FILTER => "PrefixFilter('prefix')"}

# Admin
count 'table'
flush 'table'                   # write MemStore to HFiles
major_compact 'table'           # merge all HFiles
```

---

## Pig

```bash
pig                             # interactive grunt shell
pig -x local                    # local mode
pig -x mapreduce                # run on cluster
pig -x tez                      # run with Tez
pig script.pig                  # run a script
pig -param DATE=2024-01 script.pig   # parameterized script
```

### Inside Grunt Shell
```pig
-- Check/debug
DESCRIBE relation;      -- show schema
DUMP relation;          -- trigger execution + print
ILLUSTRATE relation;    -- sample-based trace
EXPLAIN relation;       -- show execution plan

-- Execution hints
SET default_parallel 10;        -- hint for number of reducers
SET job.name 'MyPigJob';
```

---

## Sqoop

```bash
# PostgreSQL JDBC driver must be in Sqoop lib (run once):
# wget -q https://jdbc.postgresql.org/download/postgresql-42.7.4.jar -O /opt/sqoop/lib/postgresql.jar

# List
sqoop list-databases --connect jdbc:postgresql://postgres:5432/ --driver org.postgresql.Driver -u hive -p hive
sqoop list-tables    --connect jdbc:postgresql://postgres:5432/db --driver org.postgresql.Driver -u hive -p hive

# Import full table
sqoop import \
  --connect jdbc:postgresql://postgres:5432/db \
  --driver org.postgresql.Driver \
  --username hive --password hive \
  --table tablename \
  --target-dir /hdfs/output \
  --num-mappers 4 \
  --split-by primary_key_col

# Import to Hive
sqoop import --hive-import --hive-table mydb.mytable ...

# Import with query
sqoop import \
  --query "SELECT id,name FROM t WHERE \$CONDITIONS" \
  --split-by id --target-dir /out --num-mappers 2

# Incremental import
sqoop import --incremental append \
  --check-column id --last-value 1000 ...

# Export
sqoop export \
  --connect jdbc:postgresql://postgres:5432/db \
  --driver org.postgresql.Driver \
  --username hive --password hive \
  --table target_table \
  --export-dir /hdfs/input \
  --input-fields-terminated-by ','

# Save job (reuse)
sqoop job --create myjob -- import --connect ... --table t
sqoop job --exec myjob
sqoop job --list
```

---

## Spark

```bash
# Interactive PySpark shell
pyspark --master yarn --num-executors 2

# Submit
spark-submit \
  --master yarn \
  --deploy-mode client \
  --num-executors 2 \
  --executor-memory 1g \
  --executor-cores 2 \
  script.py [args...]

# Submit with extra config
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --conf spark.sql.shuffle.partitions=20 \
  --conf spark.eventLog.enabled=true \
  --conf spark.eventLog.dir=hdfs:///spark-logs \
  --py-files deps.zip \
  script.py

# Check running/finished Spark jobs
yarn application -list -appTypes SPARK
yarn application -list -appTypes SPARK -appStates FINISHED
```

### PySpark Quick Reference
```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("MyApp").getOrCreate()

# Read
df = spark.read.csv("hdfs:///path", header=True, inferSchema=True)
df = spark.read.parquet("hdfs:///path")
df = spark.read.json("hdfs:///path")
df = spark.table("hive_db.table")   # from Hive (need enableHiveSupport)

# Transform
df.filter(col("salary") > 50000)
df.select("name", "salary")
df.withColumn("monthly", col("salary") / 12)
df.groupBy("dept").agg(avg("salary"), count("*"))
df.orderBy(desc("salary"))
df.join(other_df, "id", "inner")
df.dropDuplicates(["id"])
df.fillna({"salary": 0, "name": "unknown"})

# Write
df.write.mode("overwrite").parquet("hdfs:///output")
df.write.mode("append").partitionBy("year").parquet("hdfs:///output")
df.write.saveAsTable("hive_db.table")  # write to Hive

# SQL
df.createOrReplaceTempView("my_table")
spark.sql("SELECT * FROM my_table WHERE salary > 50000").show()
```

---

## Docker Cluster Management

The following `docker compose` and `docker exec` commands work **identically** on Linux, Mac, and Windows PowerShell/Git Bash.

```bash
# Linux / Mac / Git Bash / PowerShell — all the same
cd Hadoop/00_Setup

# Start / Stop
docker compose up -d            # start all services
docker compose stop             # stop (keep volumes)
docker compose start            # restart stopped services
docker compose restart          # restart all
docker compose down -v          # destroy + delete volumes (full reset)

# Status
docker compose ps               # container status
docker compose logs namenode    # logs for one service
docker compose logs -f          # follow all logs

# Resource usage
docker stats                    # live CPU/memory per container

# Shell into container
docker exec -it hadoop-namenode bash
docker exec hadoop-namenode hdfs dfs -ls /   # one-off command
```

### Copy files to container

**Linux / Mac / Git Bash:**
```bash
docker cp ./myscript.sh  hadoop-namenode:/tmp/myscript.sh
docker cp ./scripts/     hadoop-namenode:/opt/scripts/
```

**Windows (PowerShell):**
```powershell
docker cp .\myscript.sh  hadoop-namenode:/tmp/myscript.sh
docker cp .\scripts\     hadoop-namenode:/opt/scripts/
```

### Check port usage on host

**Linux (AlmaLinux 9):**
```bash
sudo ss -tlnp | grep 9870     # check port 9870
sudo lsof -i :9870            # alternative
```

**Windows (PowerShell):**
```powershell
netstat -ano | findstr :9870
```

### VPS-specific: open firewall ports

```bash
# AlmaLinux 9 / RHEL / CentOS
sudo firewall-cmd --add-port=9870/tcp  --permanent   # HDFS UI
sudo firewall-cmd --add-port=8088/tcp  --permanent   # YARN UI
sudo firewall-cmd --add-port=19888/tcp --permanent   # MR History
sudo firewall-cmd --add-port=18080/tcp --permanent   # Spark History
sudo firewall-cmd --add-port=16010/tcp --permanent   # HBase UI
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports          # verify

# Ubuntu / Debian (ufw)
sudo ufw allow 9870/tcp
sudo ufw allow 8088/tcp
sudo ufw allow 19888/tcp
sudo ufw allow 18080/tcp
sudo ufw allow 16010/tcp
sudo ufw reload
```
