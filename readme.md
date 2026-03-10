# Data Engineering Playground

A hands-on learning repository for Data Engineering topics.

## Modules

| Folder | Topics |
|--------|--------|
| [Hadoop](Hadoop/) | HDFS, YARN, MapReduce, Hive, HBase, Pig, Sqoop, Spark, Flume, Oozie, ZooKeeper |

---

## Cluster Overview

| Container | Image | Role |
|-----------|-------|------|
| `hadoop-namenode` | bde2020/hadoop-namenode:2.0.0-hadoop3.2.1-java8 | HDFS NameNode |
| `hadoop-datanode1` | bde2020/hadoop-datanode:2.0.0-hadoop3.2.1-java8 | HDFS DataNode 1 |
| `hadoop-datanode2` | bde2020/hadoop-datanode:2.0.0-hadoop3.2.1-java8 | HDFS DataNode 2 |
| `hadoop-resourcemgr` | bde2020/hadoop-resourcemanager:2.0.0-hadoop3.2.1-java8 | YARN ResourceManager |
| `hadoop-nodemanager` | bde2020/hadoop-nodemanager:2.0.0-hadoop3.2.1-java8 | YARN NodeManager |
| `hadoop-history` | bde2020/hadoop-historyserver:2.0.0-hadoop3.2.1-java8 | MapReduce History Server |
| `hadoop-postgres` | postgres:17 | Hive Metastore backend |
| `hadoop-hive` | bde2020/hive:2.3.2-postgresql-metastore | HiveServer2 + Metastore |
| `hadoop-hbase` | dajobe/hbase | HBase + ZooKeeper |
| `hadoop-spark` | bde2020/spark-master:3.3.0-hadoop3.3 | Spark Master |

## Port Reference

All ports are configurable via `Hadoop/00_Setup/.env`.

| Service | Port | Config Key | UI / Purpose |
|---------|------|------------|--------------|
| HDFS NameNode | 9870 | `NAMENODE_HTTP_PORT` | Web UI |
| HDFS NameNode RPC | 9000 | `NAMENODE_RPC_PORT` | HDFS RPC |
| YARN ResourceManager | 8088 | `YARN_RESOURCEMANAGER_PORT` | Web UI |
| YARN NodeManager | 8042 | `YARN_NODEMANAGER_PORT` | Web UI |
| MapReduce History | 19888 | `MR_HISTORY_PORT` | Web UI |
| HiveServer2 Thrift | 10000 | `HIVE_SERVER2_PORT` | Beeline / JDBC |
| HiveServer2 Web UI | 10002 | `HIVE_WEBUI_PORT` | Web UI |
| HBase Master | 16000 | `HBASE_MASTER_PORT` | RPC |
| HBase Master Web UI | 16010 | `HBASE_MASTER_WEBUI_PORT` | Web UI |
| HBase RegionServer | 16020 | `HBASE_REGIONSERVER_PORT` | RPC |
| ZooKeeper | 2181 | `ZOOKEEPER_PORT` | Client port |
| Spark History | 18080 | `SPARK_HISTORY_PORT` | Web UI |
| Spark Web UI | 8080 | — | Web UI |
| Spark Master RPC | 7077 | — | Spark submit |
| PostgreSQL | 5432 | `POSTGRES_PORT` | Hive metastore DB |

---

## Setup on Linux VPS (AlmaLinux 9 / RHEL)

### Step 1 — Clone the repository

```bash
git clone https://github.com/imrulhasan273/Data-Engineering-Playground.git
cd Data-Engineering-Playground
```

### Step 2 — Install Docker

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker
```

Verify:
```bash
docker --version
docker compose version
```

### Step 3 — Configure resources (optional)

Edit `Hadoop/00_Setup/.env` to adjust memory, vcores, and ports before starting:

```bash
# Default resource limits
YARN_NODEMANAGER_MEMORY_MB=2048   # increase for heavier jobs
YARN_NODEMANAGER_VCORES=2

# Default credentials (PostgreSQL / Hive metastore)
POSTGRES_USER=hive
POSTGRES_PASSWORD=hive
POSTGRES_DB=hive_metastore
```

### Step 4 — Start the Hadoop cluster

```bash
cd Hadoop/00_Setup
docker compose up -d
```

> First run downloads ~4 GB of images. Takes 5-10 minutes.

Check all containers are running:
```bash
docker compose ps
```

Expected output:
```
hadoop-namenode     running
hadoop-datanode1    running
hadoop-datanode2    running
hadoop-resourcemgr  running
hadoop-nodemanager  running
hadoop-history      running
hadoop-postgres     running
hadoop-hive         running
hadoop-hbase        running
hadoop-spark        running
```

### Step 5 — Run smoke test

```bash
bash verify_setup.sh
```

### Step 6 — Open firewall ports

```bash
sudo firewall-cmd --add-port=9870/tcp --permanent   # HDFS NameNode UI
sudo firewall-cmd --add-port=8088/tcp --permanent   # YARN ResourceManager UI
sudo firewall-cmd --add-port=8042/tcp --permanent   # YARN NodeManager UI
sudo firewall-cmd --add-port=19888/tcp --permanent  # MapReduce History UI
sudo firewall-cmd --add-port=10000/tcp --permanent  # HiveServer2 (Beeline/JDBC)
sudo firewall-cmd --add-port=10002/tcp --permanent  # HiveServer2 Web UI
sudo firewall-cmd --add-port=16010/tcp --permanent  # HBase Master UI
sudo firewall-cmd --add-port=18080/tcp --permanent  # Spark History UI
sudo firewall-cmd --add-port=8080/tcp --permanent   # Spark Web UI
sudo firewall-cmd --reload
```

### Step 7 — Access Web UIs

Replace `YOUR_VPS_IP` with your server's public IP:

| Service | URL |
|---------|-----|
| HDFS NameNode | http://YOUR_VPS_IP:9870 |
| YARN ResourceManager | http://YOUR_VPS_IP:8088 |
| YARN NodeManager | http://YOUR_VPS_IP:8042 |
| MapReduce History | http://YOUR_VPS_IP:19888 |
| HiveServer2 UI | http://YOUR_VPS_IP:10002 |
| HBase Master | http://YOUR_VPS_IP:16010 |
| Spark History | http://YOUR_VPS_IP:18080 |
| Spark Web UI | http://YOUR_VPS_IP:8080 |

### Step 8 — Connect to services

```bash
# Hive — Beeline
docker exec -it hadoop-hive beeline -u jdbc:hive2://localhost:10000

# PostgreSQL — psql (Hive metastore)
docker exec -it hadoop-postgres psql -U hive -d hive_metastore

# HBase shell
docker exec -it hadoop-hbase hbase shell

# HDFS commands
docker exec -it hadoop-namenode hdfs dfs -ls /
```

### Step 9 — Python environment (for HBase / ZooKeeper scripts)

```bash
sudo dnf install -y epel-release
sudo dnf install -y python3.13 python3.13-pip

cd /home/Data-Engineering-Playground/Hadoop
python3.13 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Activate every session before running host-side scripts:
```bash
source .venv/bin/activate
```

---

## Setup on Windows

| Tool | Purpose | Install |
|------|---------|---------|
| Docker Desktop >= 24.x | Run the cluster | https://www.docker.com/products/docker-desktop/ |
| Git Bash or WSL2 | Run `.sh` scripts | Bundled with Git / Windows Store |
| Python 3.13 | HBase / ZooKeeper scripts | https://www.python.org/ |

```powershell
# Clone
git clone https://github.com/imrulhasan273/Data-Engineering-Playground.git
cd Data-Engineering-Playground

# Start cluster
cd Hadoop\00_Setup
docker compose up -d

# Python venv
cd ..\..
python -m venv Hadoop\.venv
Hadoop\.venv\Scripts\Activate.ps1
pip install -r Hadoop\requirements.txt
```

> Run `.sh` scripts inside Git Bash or WSL2, not PowerShell.

---

## Git Sync (Windows)

A helper script is included to pull, commit, and push in one command:

```powershell
# First time only — allow script execution
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

# Auto timestamp commit
.\git-sync.ps1

# With custom message
.\git-sync.ps1 "my changes"
```

- Git identity is pre-configured in the script (`imrulhasan273@gmail.com`)
- Logs are saved to `log/git-sync_YYYY-MM-DD.log`
- Runs: pull -> add -> commit -> push in order

---

## Stop / Reset the Cluster

```bash
cd Hadoop/00_Setup

docker compose stop        # pause (keeps all data)
docker compose start       # resume

docker compose down        # stop and remove containers (keeps volumes)
docker compose down -v     # full reset — destroys all data volumes
```

---

## Credentials (default)

| Service | User | Password | DB |
|---------|------|----------|----|
| PostgreSQL (Hive metastore) | `hive` | `hive` | `hive_metastore` |

> Change defaults in `Hadoop/00_Setup/.env` before starting the cluster.
