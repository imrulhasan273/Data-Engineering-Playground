# HDFS Federation

## What is HDFS Federation?
HDFS Federation allows multiple independent NameNodes to share the same cluster of DataNodes. Each NameNode manages its own **namespace** and **block pool**.

## Problem it Solves
A single NameNode is a bottleneck:
- All metadata in memory → limited by NameNode RAM
- Single namespace → naming conflicts between teams
- Single point of failure

## Architecture

```
┌────────────────────────────────────────────────────────┐
│                    DataNode Cluster                    │
│                                                       │
│  DataNode1    DataNode2    DataNode3    DataNode4      │
│  [BP-A][BP-B] [BP-A][BP-B] [BP-A][BP-B] [BP-A][BP-B]  │
└────────────────────────────────────────────────────────┘
        ↑                            ↑
  NameNode A                   NameNode B
  Namespace: /user, /data      Namespace: /warehouse, /tmp
  Block Pool: BP-A             Block Pool: BP-B
```

Each NameNode manages its own namespace independently. DataNodes register with ALL NameNodes and store blocks for all block pools.

## Configuration (core-site.xml + hdfs-site.xml)

```xml
<!-- core-site.xml — define logical cluster name -->
<property>
  <name>fs.defaultFS</name>
  <value>hdfs://mycluster</value>
</property>

<!-- hdfs-site.xml — define nameservices -->
<property>
  <name>dfs.nameservices</name>
  <value>ns1,ns2</value>
</property>

<!-- NameNode for ns1 -->
<property>
  <name>dfs.namenode.rpc-address.ns1</name>
  <value>namenode1:9000</value>
</property>
<property>
  <name>dfs.namenode.http-address.ns1</name>
  <value>namenode1:9870</value>
</property>

<!-- NameNode for ns2 -->
<property>
  <name>dfs.namenode.rpc-address.ns2</name>
  <value>namenode2:9000</value>
</property>
<property>
  <name>dfs.namenode.http-address.ns2</name>
  <value>namenode2:9870</value>
</property>
```

## ViewFs — Unified Namespace

With federation, clients use `hdfs://ns1/` and `hdfs://ns2/` prefixes. ViewFs creates a **virtual unified namespace**:

```xml
<!-- core-site.xml -->
<property>
  <name>fs.viewfs.mounttable.default.link./user</name>
  <value>hdfs://ns1/user</value>
</property>
<property>
  <name>fs.viewfs.mounttable.default.link./warehouse</name>
  <value>hdfs://ns2/warehouse</value>
</property>
```

Now clients can use `viewfs:///user/data` and it routes to the right NameNode automatically.

## Router-Based Federation (RBF) — Hadoop 3.x

RBF adds a **Router** layer that acts as a proxy, routing requests to the correct NameNode transparently:

```
Client → Router (transparent proxy) → NameNode A or B
```

- Clients see a single endpoint
- No client-side ViewFs configuration needed
- Supports cross-namespace operations

### Enable RBF

```xml
<!-- hdfs-site.xml -->
<property>
  <name>dfs.federation.router.store.driver.class</name>
  <value>org.apache.hadoop.hdfs.server.federation.store.driver.impl.StateStoreMySQLImpl</value>
</property>
<property>
  <name>dfs.federation.router.rpc-address</name>
  <value>router:8888</value>
</property>
```

```bash
# Start Router
hdfs --daemon start router

# Mount a namespace path to a sub-cluster
hdfs dfsrouteradmin -add /user ns1 /user
hdfs dfsrouteradmin -add /warehouse ns2 /warehouse

# List mount table
hdfs dfsrouteradmin -ls
```

## NameNode High Availability (HA)

HA is separate from Federation but commonly used together:

```
Active NameNode ←→ Standby NameNode
          ↓              ↓
      JournalNode Quorum (3+)
          ↓
      ZooKeeper (leader election)
```

Key config: `dfs.ha.namenodes.ns1 = nn1,nn2`

## Summary Table

| Feature | Federation | HA |
|---------|-----------|-----|
| Purpose | Scale metadata | Eliminate single point of failure |
| Multiple NameNodes | Yes (different namespaces) | Yes (same namespace) |
| DataNode sharing | Yes | Yes |
| Failover | No | Yes (automatic with ZK) |
| Use together? | Yes (recommended in production) | Yes |
