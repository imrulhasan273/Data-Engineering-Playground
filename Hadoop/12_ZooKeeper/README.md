# 12 — Apache ZooKeeper

## What is ZooKeeper?
Apache ZooKeeper is a distributed coordination service. It provides a simple, hierarchical key-value store (like a filesystem) with strong consistency guarantees, used by Hadoop components for:
- Leader election (HDFS HA, YARN HA, HBase HMaster, Kafka controller)
- Service discovery (HBase RegionServer registration)
- Distributed locking
- Configuration management / distributed watches

## Data Model

```
/                         ← root
├── hbase/                ← HBase znodes
│   ├── master            ← current HBase master address (ephemeral)
│   ├── rs/               ← RegionServer registrations (ephemeral)
│   └── table/            ← table metadata
├── hadoop-ha/            ← HDFS HA active NameNode
├── yarn-leader-election/ ← YARN active ResourceManager
└── your-app/             ← your application znodes
    ├── config/
    ├── locks/
    └── workers/
```

Each node = **znode**: holds data (up to 1 MB) + metadata (version, timestamps, ACL).

## Znode Types

| Type | Persistence | Sequence | Use Case |
|------|------------|----------|----------|
| Persistent | Until deleted | No | Config, service registry |
| Persistent Sequential | Until deleted | Yes (`-0000001`) | Ordered queues |
| Ephemeral | Until client disconnects | No | Heartbeat, presence detection |
| Ephemeral Sequential | Until client disconnects | Yes | Leader election, distributed locks |

## Files in This Module

| File | Description |
|------|-------------|
| `01_zk_operations.sh` | zkCli.sh operations: CRUD, znodes types, watches, patterns |
| `02_python_kazoo.py` | Python Kazoo client: CRUD, watches, lock, election, barrier |

## Quick Start

### Connect to ZooKeeper (embedded in HBase container)

```bash
# Using the HBase container's embedded ZooKeeper
docker exec -it hadoop-hbase zkCli.sh -server localhost:2181

# Or from host (if port 2181 is exposed)
zkCli.sh -server localhost:2181
```

### Run the shell script

```bash
docker cp 01_zk_operations.sh hadoop-hbase:/tmp/
docker exec -it hadoop-hbase bash /tmp/01_zk_operations.sh
```

### Run the Python script

```bash
pip install kazoo
python 02_python_kazoo.py
```

## zkCli.sh Quick Reference

```bash
# Connection
zkCli.sh -server localhost:2181
zkCli.sh -server zk1:2181,zk2:2181,zk3:2181   # multi-node ensemble

# CRUD
ls /                             # list children
create /mynode "data"            # create persistent
create -e /mynode "data"         # create ephemeral
create -s /mynode "data"         # create sequential
create -e -s /seq- "data"        # create ephemeral + sequential
get /mynode                      # get data
stat /mynode                     # get metadata only
set /mynode "new-data"           # update data
delete /mynode                   # delete (must be empty)
deleteall /mynode                # delete recursively

# Watches
get -w /mynode                   # watch data changes
ls  -w /mynode                   # watch children changes
exists -w /mynode                # watch existence

# Health (four-letter words)
echo ruok | nc localhost 2181    # is OK?
echo stat | nc localhost 2181    # stats
echo mntr | nc localhost 2181    # metrics
echo conf | nc localhost 2181    # config
```

## Distributed Patterns

### Leader Election

```
1. All candidates: create -e -s /election/candidate-
2. Get all children, sort by sequence number
3. Lowest sequence = current leader
4. Others watch the node just before them
5. When leader disconnects → its ephemeral node disappears
   → next candidate's watch fires → it becomes leader
```

### Distributed Lock

```
1. create -e -s /locks/lock-   (get sequence number N)
2. If N is the lowest → acquired
3. Else → watch /locks/lock-(N-1)
4. When watch fires → re-check
5. On release → delete own node
```

### Service Discovery

```
Register:  create -e /services/api/10.0.0.1:8080 '{"healthy":true}'
Discover:  ls /services/api
Watch:     ls -w /services/api  (fires on join/leave)
```

## ZooKeeper in Hadoop Ecosystem

| Service | ZK Path | Purpose |
|---------|---------|---------|
| HDFS HA | `/hadoop-ha/<cluster>` | Active NameNode election |
| YARN HA | `/yarn-leader-election/<cluster>` | Active RM election |
| HBase | `/hbase/master` | HMaster election |
| HBase | `/hbase/rs` | RegionServer registration |
| Kafka | `/kafka/controller` | Broker controller election |
| Kafka | `/kafka/brokers` | Broker registration |
