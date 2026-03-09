#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 05_oozie_operations.sh — Oozie CLI operations: submit, monitor, manage jobs
# Run inside Oozie container or on a host with oozie CLI installed
# ─────────────────────────────────────────────────────────────────────────────

OOZIE_URL="${OOZIE_URL:-http://localhost:11000/oozie}"
NAMENODE="${NAMENODE:-hdfs://namenode:9000}"

echo "════════════════════════════════════════════"
echo "  Apache Oozie Operations"
echo "  Oozie URL: ${OOZIE_URL}"
echo "════════════════════════════════════════════"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 1: Installation on AlmaLinux 9
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[1] Installation (AlmaLinux 9)"
cat << 'INSTALL'
# Install dependencies
sudo dnf install -y java-11-openjdk maven

# Download Oozie 5.x
OOZIE_VER="5.2.1"
wget https://archive.apache.org/dist/oozie/${OOZIE_VER}/oozie-${OOZIE_VER}.tar.gz
tar -xzf oozie-${OOZIE_VER}.tar.gz
cd oozie-${OOZIE_VER}

# Build with Hadoop 3 support
mvn clean package assembly:single -DskipTests \
  -Dhadoop.version=3.2.1 \
  -P hadoop-3

# Install
sudo cp distro/target/oozie-${OOZIE_VER}-distro.tar.gz /opt/
cd /opt
sudo tar -xzf oozie-${OOZIE_VER}-distro.tar.gz
sudo mv oozie-${OOZIE_VER} oozie
export OOZIE_HOME=/opt/oozie
export PATH=$PATH:$OOZIE_HOME/bin

# Configure oozie-site.xml (minimal)
cat > $OOZIE_HOME/conf/oozie-site.xml << 'XML'
<configuration>
  <property><name>oozie.service.HadoopAccessorService.hadoop.configurations</name>
            <value>*=/opt/hadoop/etc/hadoop</value></property>
  <property><name>oozie.db.schema.name</name><value>oozie</value></property>
</configuration>
XML

# Initialize Oozie DB (using Derby for demo; use MySQL/PostgreSQL in production)
oozie-setup.sh db create -run

# Upload Oozie share lib to HDFS
oozie-setup.sh sharelib create -fs hdfs://namenode:9000 -locallib $OOZIE_HOME/share/lib

# Start Oozie server
oozied.sh start

# Verify
oozie admin -oozie http://localhost:11000/oozie -status
INSTALL

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 2: Prepare and deploy a workflow to HDFS
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[2] Deploy workflow to HDFS"

WORKFLOW_DIR="$(dirname "$0")"

echo "  # Create app directory in HDFS"
hdfs dfs -mkdir -p ${NAMENODE}/oozie/apps/wordcount/scripts 2>/dev/null || \
  echo "  hdfs dfs -mkdir -p hdfs:///oozie/apps/wordcount/scripts"

echo "  # Upload workflow.xml"
hdfs dfs -put -f "${WORKFLOW_DIR}/01_workflow.xml" \
  ${NAMENODE}/oozie/apps/wordcount/workflow.xml 2>/dev/null || \
  echo "  hdfs dfs -put 01_workflow.xml hdfs:///oozie/apps/wordcount/"

echo "  # Create sample input data"
echo "Hello Oozie World" | hdfs dfs -put -f - ${NAMENODE}/data/input/sample.txt 2>/dev/null || \
  echo "  echo 'Hello Oozie World' | hdfs dfs -put - hdfs:///data/input/sample.txt"

echo "  # Upload HiveQL script"
cat << 'HQL' > /tmp/load_wordcount.hql 2>/dev/null
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE EXTERNAL TABLE IF NOT EXISTS ${DB_NAME}.wordcount (
    word  STRING,
    count INT
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
LOCATION '${INPUT}';
SELECT word, count FROM ${DB_NAME}.wordcount ORDER BY count DESC LIMIT 10;
HQL
hdfs dfs -put -f /tmp/load_wordcount.hql \
  ${NAMENODE}/oozie/apps/wordcount/scripts/load_wordcount.hql 2>/dev/null || \
  echo "  hdfs dfs -put load_wordcount.hql hdfs:///oozie/apps/wordcount/scripts/"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 3: Submit and run a workflow
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[3] Submit workflow job"
echo ""
echo "  oozie job -oozie ${OOZIE_URL} -config 04_job.properties -run"
echo ""

# If oozie CLI is available, actually run it
if command -v oozie &>/dev/null; then
    JOB_ID=$(oozie job -oozie "${OOZIE_URL}" \
      -config "${WORKFLOW_DIR}/04_job.properties" \
      -run 2>/dev/null | grep -oP 'job: \K\S+')
    if [ -n "${JOB_ID}" ]; then
        echo "  Submitted: ${JOB_ID}"
    fi
else
    echo "  [oozie CLI not available — install Oozie client first]"
    JOB_ID="0000000-240101000000000-oozie-oozi-W"  # sample for demo
fi

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 4: Monitor workflow jobs
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[4] Monitor jobs"
echo ""
echo "  # Get job status"
echo "  oozie job -oozie ${OOZIE_URL} -info ${JOB_ID}"
echo ""
echo "  # Get job logs"
echo "  oozie job -oozie ${OOZIE_URL} -log ${JOB_ID}"
echo ""
echo "  # List running jobs"
echo "  oozie jobs -oozie ${OOZIE_URL} -status RUNNING"
echo ""
echo "  # List all workflow jobs"
echo "  oozie jobs -oozie ${OOZIE_URL} -jobtype wf -len 20"
echo ""
echo "  # List coordinator jobs"
echo "  oozie jobs -oozie ${OOZIE_URL} -jobtype coordinator"

if command -v oozie &>/dev/null && [ -n "${JOB_ID}" ]; then
    echo ""
    echo "  Checking status of ${JOB_ID}..."
    oozie job -oozie "${OOZIE_URL}" -info "${JOB_ID}" 2>/dev/null || true
fi

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 5: Control workflow jobs
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[5] Control running jobs"
echo ""
echo "  # Suspend (pause) a running job"
echo "  oozie job -oozie ${OOZIE_URL} -suspend ${JOB_ID}"
echo ""
echo "  # Resume a suspended job"
echo "  oozie job -oozie ${OOZIE_URL} -resume ${JOB_ID}"
echo ""
echo "  # Kill a job"
echo "  oozie job -oozie ${OOZIE_URL} -kill ${JOB_ID}"
echo ""
echo "  # Rerun a failed workflow from a specific action"
echo "  oozie job -oozie ${OOZIE_URL} \\"
echo "    -rerun ${JOB_ID} \\"
echo "    -config 04_job.properties \\"
echo "    -Doozie.wf.rerun.failnodes=true"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 6: Submit and monitor a coordinator
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[6] Coordinator operations"
echo ""
echo "  # Upload coordinator.xml to HDFS"
echo "  hdfs dfs -put 02_coordinator.xml hdfs:///oozie/apps/wordcount/coordinator.xml"
echo ""
echo "  # Submit coordinator (use oozie.coord.application.path in properties)"
echo "  oozie job -oozie ${OOZIE_URL} -config 04_job.properties -run"
echo "  # (Set oozie.coord.application.path in 04_job.properties)"
echo ""

# Sample coordinator ID
COORD_ID="0000001-240101000000000-oozie-oozi-C"
echo "  # List coordinator actions (materialized runs)"
echo "  oozie job -oozie ${OOZIE_URL} -info ${COORD_ID} -len 10"
echo ""
echo "  # Rerun a specific coordinator action (e.g., action 5)"
echo "  oozie job -oozie ${OOZIE_URL} \\"
echo "    -coordinator ${COORD_ID} \\"
echo "    -rerun 5"
echo ""
echo "  # Change coordinator end time"
echo "  oozie job -oozie ${OOZIE_URL} \\"
echo "    -change ${COORD_ID} \\"
echo "    -value endtime=2025-12-31T00:00Z"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 7: EL (Expression Language) functions reference
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[7] EL (Expression Language) cheatsheet"
echo ""
echo "  Workflow EL:"
echo "    \${wf:id()}                    — current workflow job ID"
echo "    \${wf:name()}                  — workflow application name"
echo "    \${wf:status()}                — RUNNING, SUCCEEDED, FAILED, etc."
echo "    \${wf:lastErrorNode()}         — name of failed action"
echo "    \${wf:errorCode(action_name)}  — error code of named action"
echo "    \${wf:errorMessage(node_name)} — error message"
echo "    \${wf:actionData(action_name)} — captured output from action"
echo ""
echo "  Coordinator EL:"
echo "    \${coord:current(0)}           — current nominal time data instance"
echo "    \${coord:current(-1)}          — previous hour/day instance"
echo "    \${coord:latest(0)}            — latest available data instance"
echo "    \${coord:hours(1)}             — frequency: every 1 hour"
echo "    \${coord:days(1)}              — frequency: every 1 day"
echo "    \${coord:months(1)}            — frequency: every 1 month"
echo "    \${coord:dataIn('name')}       — resolved path of input dataset"
echo "    \${coord:dataOut('name')}      — resolved path of output dataset"
echo "    \${YEAR} \${MONTH} \${DAY} \${HOUR} — time components in URI templates"

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 8: Oozie admin commands
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[8] Admin commands"
echo ""
echo "  # Check Oozie server status"
echo "  oozie admin -oozie ${OOZIE_URL} -status"
echo ""
echo "  # List share lib versions"
echo "  oozie admin -oozie ${OOZIE_URL} -shareliblist"
echo ""
echo "  # Update share lib (after uploading new jars)"
echo "  oozie admin -oozie ${OOZIE_URL} -sharelibupdate"
echo ""
echo "  # Start/stop Oozie server"
echo "  oozied.sh start"
echo "  oozied.sh stop"

echo -e "\n════════════════════════════════════════════"
echo "  Oozie Operations — DONE"
echo "════════════════════════════════════════════"
