#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 05_flume_operations.sh — Flume installation, management, and testing
# Run inside a container that has Flume installed, or adapt for your VPS
# ─────────────────────────────────────────────────────────────────────────────

echo "════════════════════════════════════════════"
echo "  Apache Flume Operations"
echo "════════════════════════════════════════════"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 1: Installation on AlmaLinux 9 / RHEL-based systems
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[1] Installation (AlmaLinux 9 / host system)"
cat << 'INSTALL'
# Install Java (required)
sudo dnf install -y java-11-openjdk

# Download Flume 1.11.0
FLUME_VER="1.11.0"
wget https://downloads.apache.org/flume/${FLUME_VER}/apache-flume-${FLUME_VER}-bin.tar.gz
tar -xzf apache-flume-${FLUME_VER}-bin.tar.gz
sudo mv apache-flume-${FLUME_VER}-bin /opt/flume

# Set environment variables
echo 'export FLUME_HOME=/opt/flume' >> ~/.bashrc
echo 'export PATH=$PATH:$FLUME_HOME/bin' >> ~/.bashrc
source ~/.bashrc

# Set JAVA_HOME in Flume config
echo "JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))" >> /opt/flume/conf/flume-env.sh

# Verify
flume-ng version
INSTALL

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 2: Start / Stop agents
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[2] Start / Stop Flume agents"

FLUME_HOME="${FLUME_HOME:-/opt/flume}"
CONF_DIR="$(dirname "$0")"  # directory of this script

echo ""
echo "  # Start basic agent (foreground, logs to console)"
echo "  flume-ng agent \\"
echo "    --name agent1 \\"
echo "    --conf-file ${CONF_DIR}/01_flume_basic.conf \\"
echo "    --conf \${FLUME_HOME}/conf \\"
echo "    -Dflume.root.logger=INFO,console"
echo ""
echo "  # Start HDFS agent (background)"
echo "  nohup flume-ng agent \\"
echo "    --name hdfs_agent \\"
echo "    --conf-file ${CONF_DIR}/02_flume_hdfs_sink.conf \\"
echo "    --conf \${FLUME_HOME}/conf \\"
echo "    -Dflume.root.logger=INFO,LOGFILE \\"
echo "    -Dflume.log.dir=/var/log/flume \\"
echo "    -Dflume.log.file=hdfs_agent.log &"
echo ""
echo "  # Check running agents"
echo "  ps aux | grep flume"
echo ""
echo "  # Stop agent"
echo "  kill \$(pgrep -f flume-ng)"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 3: Test the Netcat source agent
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[3] Test Netcat source (requires agent1 running from 01_flume_basic.conf)"
echo ""
echo "  # Terminal 1: start the agent"
echo "  flume-ng agent --name agent1 --conf-file 01_flume_basic.conf -Dflume.root.logger=INFO,console"
echo ""
echo "  # Terminal 2: send test events"
echo "  echo 'Hello Flume' | nc localhost 44444"
echo "  echo 'event 1' | nc localhost 44444"
echo "  echo 'event 2' | nc localhost 44444"

# If agent is running locally, send test events
if command -v nc &>/dev/null; then
    if nc -z localhost 44444 2>/dev/null; then
        echo ""
        echo "  [Agent is running! Sending test events...]"
        echo "Hello Flume $(date)" | nc -q 1 localhost 44444
        echo "Test event 1" | nc -q 1 localhost 44444
        echo "Test event 2" | nc -q 1 localhost 44444
        echo "  [Events sent — check agent1 console log]"
    else
        echo "  [Agent not running — start it first]"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 4: Test HDFS sink — send events and verify in HDFS
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[4] Test HDFS sink agent"
echo ""
echo "  # Setup test log file for Taildir source"
echo "  mkdir -p /var/log/app"
echo "  for i in \$(seq 1 20); do"
echo "    echo \"\$(date '+%Y-%m-%d %H:%M:%S') INFO Event number \$i\" >> /var/log/app/events.log"
echo "  done"
echo ""
echo "  # Watch HDFS for arriving files"
echo "  watch -n 5 'hdfs dfs -ls -R /flume/'"
echo ""
echo "  # Verify events arrived"
echo "  hdfs dfs -cat /flume/logs/events.log/\$(date +'%Y/%m/%d/%H')/events.*.log 2>/dev/null | head -5"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 5: Flume Agent architecture concepts
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[5] Flume Architecture Concepts"
echo ""
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │                   Flume Agent                            │"
echo "  │                                                          │"
echo "  │  ┌────────┐    ┌─────────┐    ┌──────────┐              │"
echo "  │  │ Source │ ─► │ Channel │ ─► │   Sink   │              │"
echo "  │  └────────┘    └─────────┘    └──────────┘              │"
echo "  │                                                          │"
echo "  │  Source: collects events from external systems           │"
echo "  │  Channel: buffers events (memory/file/Kafka)             │"
echo "  │  Sink: delivers events to destination                    │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""
echo "  Sources:"
echo "    netcat         — listen on TCP port"
echo "    exec           — run command, tail output"
echo "    taildir        — tail multiple files, position-aware"
echo "    spooldir       — watch directory, process new files"
echo "    avro           — receive from another Flume agent (Avro RPC)"
echo "    kafka          — consume from Kafka topic"
echo "    http           — receive HTTP POST events"
echo ""
echo "  Channels:"
echo "    memory         — fast, NOT durable (data lost on crash)"
echo "    file           — durable (WAL on local disk)"
echo "    kafka          — durable + replicated (Kafka as channel)"
echo ""
echo "  Sinks:"
echo "    hdfs           — write to HDFS (most common)"
echo "    hbase          — write to HBase"
echo "    kafka          — produce to Kafka topic"
echo "    elasticsearch  — index into Elasticsearch"
echo "    avro           — forward to next Flume agent"
echo "    logger         — log to Flume log (testing only)"
echo "    file_roll      — write to local files"
echo ""
echo "  Topologies:"
echo "    Simple:       Source → Channel → Sink"
echo "    Fan-out:      Source → [Channel1 → Sink1, Channel2 → Sink2]"
echo "    Fan-in:       [Source1, Source2] → Channel → Sink"
echo "    Multi-hop:    Agent1(Avro Sink) → Agent2(Avro Source → HDFS Sink)"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 6: Multi-hop (chained agents) example
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[6] Multi-hop topology (collector → aggregator pattern)"
echo ""
cat << 'MULTI_HOP'
# Agent 1 (collector on each app server) — sends to central aggregator
collector.sources  = log_src
collector.channels = avro_ch
collector.sinks    = avro_sink

collector.sources.log_src.type         = taildir
collector.sources.log_src.positionFile = /var/flume/position.json
collector.sources.log_src.filegroups   = g1
collector.sources.log_src.filegroups.g1 = /var/log/app/.*\.log
collector.sources.log_src.channels     = avro_ch

collector.channels.avro_ch.type              = memory
collector.channels.avro_ch.capacity          = 10000
collector.channels.avro_ch.transactionCapacity = 1000

collector.sinks.avro_sink.type     = avro
collector.sinks.avro_sink.hostname = aggregator-host
collector.sinks.avro_sink.port     = 41414
collector.sinks.avro_sink.channel  = avro_ch

# ─────────────────────────────────
# Agent 2 (aggregator) — receives from all collectors → HDFS
aggregator.sources  = avro_src
aggregator.channels = file_ch
aggregator.sinks    = hdfs_sink

aggregator.sources.avro_src.type     = avro
aggregator.sources.avro_src.bind     = 0.0.0.0
aggregator.sources.avro_src.port     = 41414
aggregator.sources.avro_src.channels = file_ch

aggregator.channels.file_ch.type            = file
aggregator.channels.file_ch.checkpointDir   = /var/flume/agg/checkpoint
aggregator.channels.file_ch.dataDirs        = /var/flume/agg/data

aggregator.sinks.hdfs_sink.type                 = hdfs
aggregator.sinks.hdfs_sink.hdfs.path            = hdfs://namenode:9000/collected/%Y/%m/%d/%H
aggregator.sinks.hdfs_sink.hdfs.fileType        = DataStream
aggregator.sinks.hdfs_sink.hdfs.rollInterval    = 300
aggregator.sinks.hdfs_sink.hdfs.useLocalTimeStamp = true
aggregator.sinks.hdfs_sink.channel              = file_ch
MULTI_HOP

echo -e "\n════════════════════════════════════════════"
echo "  Flume Operations — DONE"
echo "════════════════════════════════════════════"
