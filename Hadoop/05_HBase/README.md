# 05 — Apache HBase

## What is HBase?
HBase is a distributed, column-oriented NoSQL database built on top of HDFS. Modeled after Google Bigtable. Best for:
- Random read/write access to billions of rows
- Variable columns per row
- Real-time lookups

## Data Model
```
Table → RowKey → Column Families → Columns → Versioned Values

Row: "emp:001"
  cf:name      = "Alice"
  cf:salary    = "95000"
  cf:hire_date = "2020-01-15"
  info:country = "US"
```

## Connect
```bash
# HBase shell
docker exec -it hadoop-hbase hbase shell

# Python (install happybase)
pip install happybase
# Run after starting the HBase Thrift server (see 01_shell_operations.sh)
```

## Scripts

| File | What It Tests |
|------|---------------|
| `01_shell_operations.sh` | HBase shell commands |
| `02_python_happybase.py` | Python API via HappyBase (Thrift) |
