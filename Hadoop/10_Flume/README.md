# 10 — Apache Flume

## What is Flume?
Apache Flume is a distributed, reliable service for collecting, aggregating, and moving large amounts of log/event data into HDFS (or Kafka, HBase, Elasticsearch).

## Core Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Flume Agent                       │
│                                                     │
│  ┌──────────┐    ┌───────────┐    ┌───────────┐     │
│  │  Source  │ ──►│  Channel  │ ──►│   Sink    │     │
│  └──────────┘    └───────────┘    └───────────┘     │
│                                                     │
│  Source   : collects events from external systems   │
│  Channel  : buffers/queues events                   │
│  Sink     : delivers events to destination          │
└─────────────────────────────────────────────────────┘
```

## Component Reference

| Component | Options |
|-----------|---------|
| **Sources** | `netcat`, `exec`, `taildir`, `spooldir`, `avro`, `kafka`, `http` |
| **Channels** | `memory` (fast, not durable), `file` (durable WAL), `kafka` (durable+replicated) |
| **Sinks** | `hdfs`, `hbase`, `kafka`, `elasticsearch`, `avro`, `logger`, `file_roll` |
| **Interceptors** | `timestamp`, `host`, `static`, `regex_filter`, `regex_extractor` |

## Files in This Module

| File | Description |
|------|-------------|
| `01_flume_basic.conf` | Netcat → Memory Channel → Logger (simplest agent for testing) |
| `02_flume_hdfs_sink.conf` | Taildir → File Channel → HDFS (production log collection pattern) |
| `03_flume_fanout.conf` | Exec → Memory → HDFS + Kafka fan-out (dual sink) |
| `04_flume_kafka_source.conf` | Kafka → File Channel → HDFS (Kafka landing pipeline) |
| `05_flume_operations.sh` | Installation, start/stop, testing, architecture reference |

## Topologies

```
Simple:     Source ──► Channel ──► Sink

Fan-out:    Source ──► Channel1 ──► Sink1 (HDFS)
                   └──► Channel2 ──► Sink2 (Kafka)

Fan-in:     Source1 ──►
                        Channel ──► Sink
            Source2 ──►

Multi-hop:  [Collector Agent] ──Avro──► [Aggregator Agent] ──► HDFS
            (runs on each app server)   (runs on dedicated node)
```

## Quick Start

### Install Flume on AlmaLinux 9

```bash
sudo dnf install -y java-11-openjdk
wget https://downloads.apache.org/flume/1.11.0/apache-flume-1.11.0-bin.tar.gz
tar -xzf apache-flume-1.11.0-bin.tar.gz
sudo mv apache-flume-1.11.0-bin /opt/flume
export PATH=$PATH:/opt/flume/bin
```

### Run the Basic Agent (test locally)

```bash
# Terminal 1: Start agent
flume-ng agent \
  --name agent1 \
  --conf-file 01_flume_basic.conf \
  --conf /opt/flume/conf \
  -Dflume.root.logger=INFO,console

# Terminal 2: Send test events
echo "Hello Flume" | nc localhost 44444
```

### Run the HDFS Agent

```bash
# Setup test log data
mkdir -p /var/log/app
echo "$(date) INFO Test event" >> /var/log/app/events.log

# Start agent
flume-ng agent \
  --name hdfs_agent \
  --conf-file 02_flume_hdfs_sink.conf \
  --conf /opt/flume/conf \
  -Dflume.root.logger=INFO,console

# Verify data arriving in HDFS
hdfs dfs -ls -R /flume/
```

## Key Concepts

### Channel Durability

| Channel | Durability | Performance | Use When |
|---------|-----------|-------------|----------|
| Memory | None (lost on crash) | Fastest | Dev/test, acceptable data loss |
| File | High (WAL on disk) | Medium | Production, must not lose events |
| Kafka | Very High (replicated) | High | Production, high throughput |

### Interceptors

```properties
# Add timestamp to every event header (required for HDFS time-based paths)
source.interceptors = ts
source.interceptors.ts.type = timestamp

# Add hostname header
source.interceptors = host
source.interceptors.host.type = host

# Filter out events matching a regex (drop DEBUG logs)
source.interceptors = filter
source.interceptors.filter.type          = regex_filter
source.interceptors.filter.regex         = .*DEBUG.*
source.interceptors.filter.excludeEvents = true

# Extract value from event body into header (for HDFS path routing)
source.interceptors = extractor
source.interceptors.extractor.type   = regex_extractor
source.interceptors.extractor.regex  = service=(\w+)
source.interceptors.extractor.serializers = s1
source.interceptors.extractor.serializers.s1.name = service_name
# Now use %{service_name} in hdfs.path
```

### HDFS Sink Rolling Strategy

```properties
# Roll by time (recommended — predictable file sizes)
hdfs.rollInterval = 300      # close file every 5 minutes

# Roll by size
hdfs.rollSize = 134217728    # close at 128 MB

# Roll by event count (set 0 to disable)
hdfs.rollCount = 0

# Close idle files (no events for N seconds)
hdfs.idleTimeout = 60
```
