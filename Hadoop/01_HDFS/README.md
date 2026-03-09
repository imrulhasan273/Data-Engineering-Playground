# 01 — HDFS (Hadoop Distributed File System)

## What is HDFS?
HDFS is the primary storage layer of Hadoop. It splits large files into 128 MB blocks (default) and distributes them across DataNodes with configurable replication.

## Key Concepts
| Concept | Description |
|---------|-------------|
| NameNode | Stores file system metadata (directory tree, block locations) |
| DataNode | Stores actual data blocks |
| Block Size | Default 128 MB per block |
| Replication | Default 3 copies per block |
| Secondary NameNode | Periodically merges fsimage + edits log (NOT a failover) |

## Scripts in This Module

| File | What It Tests |
|------|---------------|
| `01_basic_operations.sh` | mkdir, put, get, ls, cat, mv, cp, rm |
| `02_file_permissions.sh` | chmod, chown, ACLs |
| `03_replication_snapshots.sh` | Replication factor, HDFS snapshots |
| `04_advanced_features.sh` | Trash, quota, safe mode, fsck |

## How to Run
```bash
# Enter the NameNode container
docker exec -it hadoop-namenode bash

# Copy a script in and run it
docker cp 01_HDFS/01_basic_operations.sh hadoop-namenode:/tmp/
docker exec -it hadoop-namenode bash /tmp/01_basic_operations.sh
```
