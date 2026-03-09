# 11 — Apache Oozie

## What is Oozie?
Apache Oozie is a workflow scheduler for Hadoop. It orchestrates sequences of MapReduce, Hive, Pig, Spark, Shell, and other actions into multi-step pipelines, with support for time-based and data-triggered scheduling.

## Three Levels of Oozie

```
Bundle      → groups multiple Coordinators ("all daily ETL jobs")
  └─ Coordinator → time-based or data-triggered scheduler ("run every hour")
       └─ Workflow  → DAG of actions ("MR → Hive → Shell")
```

## Files in This Module

| File | Description |
|------|-------------|
| `01_workflow.xml` | DAG workflow: Shell → MapReduce → Hive → Shell (sequence) |
| `02_coordinator.xml` | Hourly coordinator with data availability trigger |
| `03_bundle.xml` | Bundle grouping two coordinators together |
| `04_job.properties` | Job submission properties (parameters + paths) |
| `05_oozie_operations.sh` | Installation, deploy, submit, monitor, control |

## Quick Start

> Oozie runs **server-side on Linux**. All `oozie` CLI commands and `hdfs dfs` commands are run
> either inside the cluster (via `docker exec`) or on the Linux VPS where Hadoop is installed.
> Windows users: run these via **Git Bash**, **WSL2**, or `docker exec -it hadoop-namenode bash`.

### 1. Deploy workflow to HDFS

**Linux / Mac / Git Bash:**
```bash
# Upload workflow files
hdfs dfs -mkdir -p hdfs:///oozie/apps/wordcount/scripts
hdfs dfs -put 11_Oozie/01_workflow.xml  hdfs:///oozie/apps/wordcount/workflow.xml

# Create sample input
echo "Hello Oozie World" | hdfs dfs -put - hdfs:///data/input/sample.txt
```

**Windows (PowerShell — via docker exec):**
```powershell
# Copy files into NameNode container, then run hdfs commands inside
docker cp 11_Oozie\ hadoop-namenode:/tmp/oozie/
docker exec -it hadoop-namenode bash -c "
  hdfs dfs -mkdir -p hdfs:///oozie/apps/wordcount/scripts
  hdfs dfs -put /tmp/oozie/01_workflow.xml hdfs:///oozie/apps/wordcount/workflow.xml
  echo 'Hello Oozie World' | hdfs dfs -put - hdfs:///data/input/sample.txt
"
```

### 2. Submit and monitor

**Linux / Mac / Git Bash:**
```bash
# Submit workflow
oozie job -oozie http://localhost:11000/oozie -config 11_Oozie/04_job.properties -run

# Monitor (replace with actual job ID)
oozie job -oozie http://localhost:11000/oozie -info 0000000-...-W

# View logs
oozie job -oozie http://localhost:11000/oozie -log 0000000-...-W

# List all running jobs
oozie jobs -oozie http://localhost:11000/oozie -status RUNNING
```

**Windows (Git Bash — same commands):**
```bash
# Same as above — Git Bash handles these identically
oozie job -oozie http://localhost:11000/oozie -config 11_Oozie/04_job.properties -run
```

**Windows (PowerShell — check job status via REST API):**
```powershell
# Oozie exposes a REST API — use it from PowerShell
Invoke-WebRequest "http://localhost:11000/oozie/v1/jobs?jobtype=wf" | ConvertFrom-Json
```

### 3. Control jobs

```bash
# Linux / Mac / Git Bash / WSL2
oozie job -oozie http://localhost:11000/oozie -suspend <job-id>   # pause
oozie job -oozie http://localhost:11000/oozie -resume  <job-id>   # unpause
oozie job -oozie http://localhost:11000/oozie -kill     <job-id>  # kill
```

## Workflow Action Types

| Action | XML Tag | Description |
|--------|---------|-------------|
| MapReduce | `<map-reduce>` | Submit a MR job |
| Hive | `<hive>` | Execute a HiveQL script |
| Pig | `<pig>` | Run a Pig Latin script |
| Spark | `<spark>` | Submit a Spark job |
| Shell | `<shell>` | Run a shell command/script |
| Java | `<java>` | Run a Java main class |
| FS | `<fs>` | HDFS file operations (mkdir, delete, move) |
| SSH | `<ssh>` | Run command on remote host |
| Email | `<email>` | Send email notification |
| Sub-workflow | `<sub-workflow>` | Invoke another workflow |

## Workflow Structure

```xml
<workflow-app name="my-pipeline" xmlns="uri:oozie:workflow:0.5">
    <start to="action1"/>

    <action name="action1">
        <map-reduce>...</map-reduce>
        <ok    to="action2"/>
        <error to="fail"/>
    </action>

    <action name="action2">
        <hive>...</hive>
        <ok    to="end"/>
        <error to="fail"/>
    </action>

    <end  name="end"/>
    <kill name="fail">
        <message>${wf:errorMessage(wf:lastErrorNode())}</message>
    </kill>
</workflow-app>
```

## Key EL (Expression Language) Functions

```
Workflow:
  ${wf:id()}                  — job ID
  ${wf:lastErrorNode()}       — last failed action name
  ${wf:errorMessage(node)}    — error message from node

Coordinator:
  ${coord:current(0)}         — current data instance
  ${coord:current(-1)}        — previous data instance
  ${coord:hours(N)}           — frequency every N hours
  ${coord:days(N)}            — frequency every N days
  ${coord:dataIn('name')}     — resolved input path
  ${coord:dataOut('name')}    — resolved output path
  ${YEAR}/${MONTH}/${DAY}     — time substitution in URI templates
```
