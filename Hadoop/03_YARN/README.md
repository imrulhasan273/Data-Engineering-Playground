# 03 — YARN (Yet Another Resource Negotiator)

## What is YARN?
YARN is Hadoop's resource management layer. It decouples resource management from data processing so multiple frameworks (MapReduce, Spark, Tez, Flink) can run on the same cluster.

## Architecture
```
ResourceManager (master)
├── Scheduler      — allocates CPU/memory to apps
└── ApplicationsManager — tracks running apps

NodeManager (on each worker)
├── Launches containers
└── Monitors resource usage

ApplicationMaster (per job)
└── Negotiates resources, coordinates task execution
```

## Scripts in This Module

| File | What It Tests |
|------|---------------|
| `01_yarn_operations.sh` | Submit jobs, view queues, kill jobs, resource reports |
