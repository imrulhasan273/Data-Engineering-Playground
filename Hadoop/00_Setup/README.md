# Hadoop Setup Guide

This guide sets up a **fully functional Hadoop 3.3.6 cluster** using Docker Compose — the easiest cross-platform approach (Linux / Windows / Mac).

---

## Prerequisites

### Linux (AlmaLinux 9 / RHEL / Ubuntu) — Recommended for this playground

```bash
# Install Docker Engine (no Docker Desktop needed on Linux)
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
sudo systemctl enable --now docker

# (Optional) Run docker without sudo — log out and back in after this
sudo usermod -aG docker $USER

# Verify
docker --version
docker compose version
```

> **AlmaLinux 9 VPS**: The above commands are all you need. All `.sh` scripts run natively in bash — no extra tools required.

### Windows

| Tool | Version | Install |
|------|---------|---------|
| Docker Desktop | >= 24.x | https://www.docker.com/products/docker-desktop/ |
| Docker Compose | >= 2.x (bundled) | Included with Docker Desktop |
| Git Bash or WSL2 | any | For running `.sh` scripts |

> **Windows users**: All `.sh` scripts must be run in **Git Bash** or **WSL2**, not PowerShell or CMD.

### Common (both platforms)

| Tool | Notes |
|------|-------|
| Java JDK 11+ | Only needed for local (non-Docker) builds. Linux: `sudo dnf install -y java-11-openjdk` |
| Python 3.8+ | For MapReduce scripts. Linux: `sudo dnf install -y python3` |
| curl | For WebHDFS exercises. Linux: `sudo dnf install -y curl` |

---

## Minimum System Resources

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 6 GB available | 8–12 GB |
| Disk | 20 GB free | 40 GB |
| CPU | 2 cores | 4+ cores |

**Linux VPS:**
```bash
# Check available RAM
free -h

# Check disk space
df -h /

# Check CPU cores
nproc
```

**Windows (Docker Desktop):**
```
Docker Desktop → Settings → Resources → Memory → set to 6 GB+
```

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
│  │    Spark     │   │  PostgreSQL  │               │
│  │  History:18080│  │  (Hive Meta) │               │
│  └──────────────┘   └──────────────┘               │
└─────────────────────────────────────────────────────┘
```

---

## Quick Start

### Step 1: Clone and enter the setup directory

**Linux / Mac / Git Bash (Windows):**
```bash
cd Hadoop/00_Setup
```

**Windows (PowerShell) — only for docker commands, not .sh scripts:**
```powershell
cd Hadoop\00_Setup
```

### Step 2: Start the Cluster

```bash
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
hadoop-postgres     running
```

### Step 3: Verify Setup

**Linux (AlmaLinux 9 VPS):**
```bash
bash verify_setup.sh
```

**Windows (Git Bash or WSL2):**
```bash
bash verify_setup.sh
```

**Windows (PowerShell) — Docker commands only:**
```powershell
docker compose ps
docker exec hadoop-namenode hdfs dfs -ls /
```

### Step 4: Access Web UIs

| Service | URL | Description |
|---------|-----|-------------|
| HDFS NameNode | http://localhost:9870 | File system browser, cluster info |
| YARN ResourceManager | http://localhost:8088 | Job monitoring |
| MapReduce History | http://localhost:19888 | Completed jobs |
| Spark History | http://localhost:18080 | Spark job history |
| HBase Master | http://localhost:16010 | HBase regions |

> **Linux VPS (remote server):** Replace `localhost` with your server's public IP.
> Make sure firewall ports are open — see Firewall section below.

---

## Connect to the Cluster

**Linux / Mac / Git Bash:**
```bash
# Main entry point — NameNode (HDFS, YARN, MapReduce, Pig, Sqoop)
docker exec -it hadoop-namenode bash

# Service-specific shells
docker exec -it hadoop-hive  bash    # Hive / Beeline
docker exec -it hadoop-hbase bash    # HBase shell
docker exec -it hadoop-spark bash    # Spark submit
docker exec -it hadoop-postgres bash # PostgreSQL (then: psql -U hive -d hive_metastore)
```

**Windows (PowerShell or CMD):**
```powershell
docker exec -it hadoop-namenode bash
docker exec -it hadoop-hive bash
docker exec -it hadoop-hbase bash
```

---

## Copy Scripts to Containers

**Linux / Mac / Git Bash:**
```bash
# Copy a single script
docker cp 01_HDFS/01_basic_operations.sh hadoop-namenode:/tmp/

# Copy an entire module directory
docker cp 02_MapReduce/ hadoop-namenode:/opt/mapreduce/

# Run it immediately
docker exec -it hadoop-namenode bash /tmp/01_basic_operations.sh
```

**Windows (PowerShell):**
```powershell
docker cp 01_HDFS\01_basic_operations.sh hadoop-namenode:/tmp/
docker cp 02_MapReduce\ hadoop-namenode:/opt/mapreduce/
docker exec -it hadoop-namenode bash /tmp/01_basic_operations.sh
```

> **Note:** Inside containers the OS is always Linux — paths always use forward slashes `/`.

---

## Stop / Reset

```bash
# Stop (preserves data volumes)
docker compose stop

# Restart stopped services
docker compose start

# Destroy everything including data volumes (full reset)
docker compose down -v
```

---

## Linux VPS Firewall Setup (AlmaLinux 9)

Open ports to access Web UIs from your browser:

```bash
# Open Hadoop web UI ports
sudo firewall-cmd --add-port=9870/tcp  --permanent   # HDFS NameNode UI
sudo firewall-cmd --add-port=8088/tcp  --permanent   # YARN ResourceManager UI
sudo firewall-cmd --add-port=19888/tcp --permanent   # MapReduce History
sudo firewall-cmd --add-port=18080/tcp --permanent   # Spark History
sudo firewall-cmd --add-port=16010/tcp --permanent   # HBase Master UI
sudo firewall-cmd --add-port=10002/tcp --permanent   # HiveServer2 Web UI
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-ports
```

> **Security tip:** On a production VPS, restrict access by source IP instead of opening to `0.0.0.0`:
> `sudo firewall-cmd --add-rich-rule='rule family=ipv4 source address=YOUR_IP port port=9870 protocol=tcp accept' --permanent`

---

## Troubleshooting

### NameNode doesn't start

**Linux / Mac / Git Bash:**
```bash
docker logs hadoop-namenode
# Usually a format issue — run full reset:
docker compose down -v && docker compose up -d
```

### Out of disk space

**Linux:**
```bash
df -h /                        # check host disk usage
docker system prune -a --volumes   # remove unused Docker data
```

**Windows:**
```bash
docker system prune -a --volumes
# Also: Docker Desktop → Settings → Resources → Disk image size → Clean / Reset
```

### Port already in use

**Linux:**
```bash
# Find what's using port 9870
sudo ss -tlnp | grep 9870
# or
sudo lsof -i :9870

# Fix: edit .env and change the conflicting port
nano 00_Setup/.env
docker compose down && docker compose up -d
```

**Windows (PowerShell):**
```powershell
netstat -ano | findstr :9870
# Find the PID, then:
taskkill /PID <pid> /F
# Or edit .env and change the port
```

### Docker daemon not running

**Linux (AlmaLinux 9):**
```bash
sudo systemctl start docker
sudo systemctl enable docker     # auto-start on boot
sudo systemctl status docker     # verify running
```

**Windows:** Start Docker Desktop and wait for it to show "Running" in the system tray.

### Not enough memory

**Linux VPS:**
```bash
free -h                          # check available RAM
# Need at least 6 GB free for the full cluster
# If RAM is low, reduce YARN memory in .env:
# YARN_NODEMANAGER_MEMORY_MB=1024
```

**Windows (Docker Desktop):**
```
Docker Desktop → Settings → Resources → Memory → set to 6 GB+
```

### Line ending issues (Windows only)

If `.sh` scripts fail with strange parse errors after being edited on Windows:

```bash
# In Git Bash or WSL2
dos2unix verify_setup.sh
dos2unix 01_HDFS/01_basic_operations.sh

# Prevent future issues — set Git to not convert line endings
git config --global core.autocrlf input
```
