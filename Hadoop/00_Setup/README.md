# Hadoop Setup Guide

This guide sets up a **fully functional Hadoop 3.3.6 cluster** using Docker Compose — the easiest cross-platform approach (Windows/Mac/Linux).

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Docker Desktop | >= 24.x | https://www.docker.com/products/docker-desktop/ |
| Docker Compose | >= 2.x (bundled) | Included with Docker Desktop |
| Java JDK | >= 11 (for local builds) | https://adoptium.net/ |
| Git Bash / WSL2 | any | For running `.sh` scripts on Windows |

> **Windows users**: All `.sh` scripts must be run in **Git Bash** or **WSL2**, not PowerShell or CMD.

---

## Cluster Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Docker Network                     │
│                                                     │
│  ┌──────────────┐   ┌──────────────┐               │
│  │  NameNode    │   │ResourceManager│               │
│  │  (HDFS)      │   │  (YARN)      │               │
│  │  :9870       │   │  :8088       │               │
│  └──────────────┘   └──────────────┘               │
│                                                     │
│  ┌──────────────┐   ┌──────────────┐               │
│  │  DataNode 1  │   │  DataNode 2  │               │
│  │  NodeManager │   │  NodeManager │               │
│  └──────────────┘   └──────────────┘               │
│                                                     │
│  ┌──────────────┐   ┌──────────────┐               │
│  │   Hive +     │   │    HBase     │               │
│  │  HiveServer2 │   │  + ZooKeeper │               │
│  │  :10000/:10002│  │  :16000/16010│               │
│  └──────────────┘   └──────────────┘               │
│                                                     │
│  ┌──────────────┐   ┌──────────────┐               │
│  │    Spark     │   │   MySQL      │               │
│  │  History:18080│  │  (Hive Meta) │               │
│  └──────────────┘   └──────────────┘               │
└─────────────────────────────────────────────────────┘
```

---

## Quick Start

### Step 1: Start the Cluster

```bash
# From the 00_Setup directory
cd Hadoop/00_Setup

# Start all services (first run downloads ~4-5 GB of images)
docker compose up -d

# Check all containers are healthy
docker compose ps
```

Expected output — all services should show `healthy` or `running`:
```
NAME                STATUS
hadoop-namenode     running
hadoop-datanode1    running
hadoop-datanode2    running
hadoop-resourcemgr  running
hadoop-hive         running
hadoop-hbase        running
hadoop-spark        running
hadoop-mysql        running
```

### Step 2: Verify Setup

```bash
bash verify_setup.sh
```

### Step 3: Access Web UIs

| Service | URL | Description |
|---------|-----|-------------|
| HDFS NameNode | http://localhost:9870 | File system browser, cluster info |
| YARN ResourceManager | http://localhost:8088 | Job monitoring |
| MapReduce History | http://localhost:19888 | Completed jobs |
| Spark History | http://localhost:18080 | Spark job history |
| HBase Master | http://localhost:16010 | HBase regions |

---

## Connect to the Cluster

```bash
# Open a shell on the NameNode (main entry point for all exercises)
docker exec -it hadoop-namenode bash

# Or connect to specific services
docker exec -it hadoop-hive bash     # Hive
docker exec -it hadoop-hbase bash    # HBase
docker exec -it hadoop-spark bash    # Spark
```

---

## Stop / Reset

```bash
# Stop (preserves data volumes)
docker compose stop

# Restart
docker compose start

# Destroy everything including data volumes (full reset)
docker compose down -v
```

---

## Troubleshooting

**NameNode doesn't start:**
```bash
docker logs hadoop-namenode
# Usually a format issue — run full reset: docker compose down -v && docker compose up -d
```

**Out of disk space:**
```bash
docker system prune -a --volumes
```

**Port conflicts:**
Edit `.env` and change the conflicting port, then `docker compose up -d`.

**Windows line endings break shell scripts:**
```bash
# In Git Bash
dos2unix verify_setup.sh
```
