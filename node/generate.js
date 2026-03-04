const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, 
        AlignmentType, HeadingLevel, BorderStyle, WidthType, ShadingType,
        PageBreak, Header, Footer, PageNumber, TabStopType, TabStopPosition,
        convertInchesToTwip } = require('docx');
const fs = require('fs');

// Phase colors matching the original PDF
const COLORS = {
    PHASE1: "2E75B6", // Dark Teal/Blue
    PHASE2: "538135", // Green
    PHASE3: "BF8F00", // Gold/Orange
    PHASE4: "C00000", // Red/Maroon
    PHASE5: "7030A0", // Purple
    PHASE6: "538135", // Green
    PHASE7: "C55A11", // Orange
    PHASE8: "2F5496", // Dark Blue
    TITLE_BLUE: "1F4E79",
    SUBTITLE_TEAL: "2E75B6",
};

// Helper function to create phase banner header
function createPhaseBanner(phaseNum, title, duration, color) {
    return new Table({
        width: { size: 9360, type: WidthType.DXA },
        columnWidths: [9360],
        rows: [
            new TableRow({
                children: [
                    new TableCell({
                        shading: { fill: color, type: ShadingType.CLEAR },
                        margins: { top: 100, bottom: 100, left: 150, right: 150 },
                        children: [
                            new Paragraph({
                                children: [
                                    new TextRun({ text: `PHASE ${phaseNum}`, bold: true, size: 20, color: "FFFFFF", font: "Arial" }),
                                ],
                                spacing: { after: 40 },
                            }),
                            new Paragraph({
                                children: [
                                    new TextRun({ text: title, bold: true, size: 28, color: "FFFFFF", font: "Arial" }),
                                    new TextRun({ text: `  ${duration}`, italics: true, size: 22, color: "FFFFFF", font: "Arial" }),
                                ],
                            }),
                        ],
                    }),
                ],
            }),
        ],
    });
}

// Helper function to create chapter header (colored text)
function createChapterHeader(chapterNum, title, color) {
    return new Paragraph({
        children: [new TextRun({ text: `${chapterNum} ${title}`, bold: true, size: 26, color: color, font: "Arial" })],
        spacing: { before: 300, after: 200 },
    });
}

// Helper function to create subheader (bold black)
function createSubHeader(title) {
    return new Paragraph({
        children: [new TextRun({ text: title, bold: true, size: 22, font: "Arial" })],
        spacing: { before: 200, after: 100 },
    });
}

// Helper for bullet points
function createBullet(text) {
    return new Paragraph({
        children: [new TextRun({ text: `•  ${text}`, size: 22, font: "Arial" })],
        spacing: { after: 60 },
        indent: { left: 360 },
    });
}

// Helper for bold-start bullet points
function createBulletBold(boldPart, normalPart) {
    return new Paragraph({
        children: [
            new TextRun({ text: `•  `, size: 22, font: "Arial" }),
            new TextRun({ text: boldPart, bold: true, size: 22, font: "Arial" }),
            new TextRun({ text: normalPart, size: 22, font: "Arial" }),
        ],
        spacing: { after: 60 },
        indent: { left: 360 },
    });
}

// TOC entry with dotted leader
function createTOCEntry(text, pageNum, indent = 0) {
    return new Paragraph({
        children: [
            new TextRun({ text: text, size: 22, font: "Arial" }),
        ],
        tabStops: [
            { type: TabStopType.RIGHT, position: 9000, leader: "dot" },
        ],
        indent: { left: indent },
        spacing: { after: 60 },
        children: [
            new TextRun({ text: text, size: 22, font: "Arial" }),
            new TextRun({ text: "\t", size: 22 }),
            new TextRun({ text: pageNum, size: 22, font: "Arial" }),
        ],
    });
}

// Create the document
const doc = new Document({
    styles: {
        default: {
            document: {
                run: { font: "Arial", size: 22 },
            },
        },
    },
    sections: [
        {
            properties: {
                page: {
                    size: { width: 12240, height: 15840 },
                    margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
                },
            },
            headers: {
                default: new Header({
                    children: [
                        new Paragraph({
                            children: [new TextRun({ text: "Data Engineering Complete Syllabus 2025", italics: true, size: 20, color: "666666", font: "Arial" })],
                            alignment: AlignmentType.RIGHT,
                        }),
                    ],
                }),
            },
            footers: {
                default: new Footer({
                    children: [
                        new Paragraph({
                            children: [
                                new TextRun({ text: "Page ", size: 20, font: "Arial" }),
                                new TextRun({ children: [PageNumber.CURRENT], size: 20 }),
                            ],
                            alignment: AlignmentType.CENTER,
                        }),
                    ],
                }),
            },
            children: [
                // ========== TITLE PAGE ==========
                new Paragraph({ spacing: { after: 1200 } }),
                new Paragraph({
                    children: [new TextRun({ text: "DATA ENGINEERING", bold: true, size: 56, color: COLORS.TITLE_BLUE, font: "Arial" })],
                    alignment: AlignmentType.CENTER,
                    spacing: { after: 120 },
                }),
                new Paragraph({
                    children: [new TextRun({ text: "Complete Learning Syllabus", bold: true, size: 36, color: COLORS.SUBTITLE_TEAL, font: "Arial" })],
                    alignment: AlignmentType.CENTER,
                    spacing: { after: 200 },
                }),
                new Paragraph({
                    children: [new TextRun({ text: "────────────────────────────────────────", size: 24, color: COLORS.TITLE_BLUE, font: "Arial" })],
                    alignment: AlignmentType.CENTER,
                    spacing: { after: 200 },
                }),
                new Paragraph({
                    children: [new TextRun({ text: "From Foundations to Production-Grade Systems", italics: true, size: 24, font: "Arial" })],
                    alignment: AlignmentType.CENTER,
                    spacing: { after: 80 },
                }),
                new Paragraph({
                    children: [new TextRun({ text: "30+ Technologies • 8 Structured Phases • 8–12 Months", size: 22, font: "Arial" })],
                    alignment: AlignmentType.CENTER,
                    spacing: { after: 1600 },
                }),
                new Paragraph({
                    children: [new TextRun({ text: "Md. Imrul Hasan", bold: true, size: 28, font: "Arial" })],
                    alignment: AlignmentType.CENTER,
                    spacing: { after: 80 },
                }),
                new Paragraph({
                    children: [new TextRun({ text: "Data Architect", size: 24, color: COLORS.SUBTITLE_TEAL, font: "Arial" })],
                    alignment: AlignmentType.CENTER,
                    spacing: { after: 60 },
                }),
                new Paragraph({
                    children: [new TextRun({ text: "3x Microsoft Certified | Oracle Certified", italics: true, size: 20, color: "666666", font: "Arial" })],
                    alignment: AlignmentType.CENTER,
                    spacing: { after: 400 },
                }),
                new Paragraph({
                    children: [new TextRun({ text: "2025 Edition", bold: true, size: 24, color: COLORS.SUBTITLE_TEAL, font: "Arial" })],
                    alignment: AlignmentType.CENTER,
                }),
                
                new Paragraph({ children: [new PageBreak()] }),
                
                // ========== TABLE OF CONTENTS ==========
                new Paragraph({
                    children: [new TextRun({ text: "Table of Contents", bold: true, size: 32, color: COLORS.TITLE_BLUE, font: "Arial" })],
                    spacing: { after: 300 },
                }),
                
                createTOCEntry("1.1 Computer Science Fundamentals", "6"),
                createTOCEntry("Data Structures", "6", 360),
                createTOCEntry("Algorithms", "6", 360),
                createTOCEntry("Operating Systems Concepts", "6", 360),
                createTOCEntry("1.2 Linux & Command Line Mastery", "6"),
                createTOCEntry("1.3 Networking Fundamentals", "7"),
                createTOCEntry("1.4 Version Control – Git", "7"),
                createTOCEntry("1.5 Python Deep Dive", "7"),
                createTOCEntry("1.6 Scala Fundamentals", "8"),
                createTOCEntry("1.7 Java Basics (for JVM Ecosystem)", "8"),
                createTOCEntry("2.1 RDBMS Concepts & Theory", "9"),
                createTOCEntry("2.2 Advanced SQL", "9"),
                createTOCEntry("2.3 Query Performance & Optimization", "9"),
                createTOCEntry("2.4 PostgreSQL (Primary RDBMS)", "10"),
                createTOCEntry("2.5 MySQL", "10"),
                createTOCEntry("3.1 Hadoop Architecture & History", "11"),
                createTOCEntry("3.2 HDFS (Hadoop Distributed File System)", "11"),
                createTOCEntry("3.3 MapReduce", "11"),
                createTOCEntry("3.4 YARN (Yet Another Resource Negotiator)", "12"),
                createTOCEntry("3.5 Hive", "12"),
                createTOCEntry("3.6 Pig", "12"),
                createTOCEntry("3.7 HBase", "12"),
                createTOCEntry("3.8 Sqoop", "12"),
                createTOCEntry("3.9 Flume", "13"),
                createTOCEntry("3.10 Oozie", "13"),
                createTOCEntry("3.11 Hadoop Security", "13"),
                createTOCEntry("3.12 ZooKeeper", "13"),
                createTOCEntry("4.1 Apache Spark – Core Architecture", "14"),
                createTOCEntry("4.2 Spark Performance Tuning", "14"),
                createTOCEntry("4.3 PySpark", "14"),
                createTOCEntry("4.4 Spark SQL & Catalyst", "15"),
                createTOCEntry("4.5 Spark Structured Streaming", "15"),
                createTOCEntry("4.6 Spark MLlib (Overview)", "15"),
                createTOCEntry("4.7 Apache Flink", "15"),
                createTOCEntry("4.8 Apache Beam", "16"),
                createTOCEntry("4.9 Presto / Trino", "16"),
                createTOCEntry("5.1 Apache Kafka – Core", "17"),
                createTOCEntry("5.2 Kafka Ecosystem", "17"),
                createTOCEntry("5.3 Debezium – Change Data Capture (CDC)", "17"),
                createTOCEntry("5.4 Apache NiFi", "18"),
                createTOCEntry("5.5 Cloud Streaming Services", "18"),
                createTOCEntry("5.6 Event-Driven Architecture Patterns", "18"),
                createTOCEntry("6.1 Cron & Systemd Timers", "20"),
                createTOCEntry("6.2 Apache Airflow (Deep Dive)", "20"),
                createTOCEntry("6.3 Luigi", "21"),
                createTOCEntry("6.4 Prefect", "21"),
                createTOCEntry("6.5 Dagster", "21"),
                createTOCEntry("6.6 Mage.ai", "21"),
                createTOCEntry("7.1 MongoDB", "22"),
                createTOCEntry("7.2 Apache Cassandra", "22"),
                createTOCEntry("7.3 Redis", "22"),
                createTOCEntry("7.4 Neo4j", "22"),
                createTOCEntry("7.5 Elasticsearch", "22"),
                createTOCEntry("7.6 Data Warehousing Concepts", "23"),
                createTOCEntry("7.7 Data Modeling Methodologies", "23"),
                createTOCEntry("7.8 Google BigQuery", "23"),
                createTOCEntry("7.9 Snowflake", "24"),
                createTOCEntry("7.10 Amazon Redshift", "24"),
                createTOCEntry("7.11 ClickHouse & Druid", "24"),
                createTOCEntry("7.12 Open Table Formats (Data Lakehouse)", "24"),
                createTOCEntry("8.1 Google Cloud Platform (GCP)", "26"),
                createTOCEntry("8.2 Amazon Web Services (AWS)", "26"),
                createTOCEntry("8.3 Microsoft Azure", "26"),
                createTOCEntry("8.4 Infrastructure as Code (IaC)", "27"),
                createTOCEntry("8.5 Docker & Kubernetes", "27"),
                createTOCEntry("8.6 Data Quality Tools", "27"),
                createTOCEntry("8.7 Data Governance & Cataloging", "27"),
                createTOCEntry("8.8 dbt (Data Build Tool)", "28"),
                createTOCEntry("8.9 CI/CD for Data Pipelines", "28"),
                createTOCEntry("8.10 Data Architecture Patterns", "28"),
                createTOCEntry("8.11 MLOps Fundamentals", "28"),
                createTOCEntry("8.12 Capstone Projects", "29"),
                createTOCEntry("Additional Resources & Learning Tips", "30"),

                new Paragraph({ children: [new PageBreak()] }),

                // ========== PHASE 1 ==========
                createPhaseBanner("1", "Foundations & Prerequisites", "(8–12 weeks)", COLORS.PHASE1),
                new Paragraph({ spacing: { after: 300 } }),

                // 1.1 Computer Science Fundamentals
                createChapterHeader("1.1", "Computer Science Fundamentals", COLORS.PHASE1),
                
                createSubHeader("Data Structures"),
                createBullet("Arrays, Linked Lists, Stacks, Queues"),
                createBullet("Hash Tables (hash functions, collision handling, load factor)"),
                createBullet("Trees (Binary, BST, B-Tree, B+ Tree, Trie)"),
                createBullet("Graphs (adjacency list/matrix, BFS, DFS, topological sort)"),
                createBullet("Heaps & Priority Queues"),

                createSubHeader("Algorithms"),
                createBullet("Sorting (QuickSort, MergeSort, HeapSort, Radix Sort)"),
                createBullet("Searching (Binary Search, linear scan, interpolation)"),
                createBullet("Big-O notation (time & space complexity analysis)"),
                createBullet("Greedy algorithms, Dynamic Programming basics"),

                createSubHeader("Operating Systems Concepts"),
                createBullet("Processes vs Threads, context switching"),
                createBullet("Memory management (virtual memory, paging, caching)"),
                createBullet("File systems (inodes, journaling, block storage)"),
                createBullet("Concurrency (mutex, semaphore, deadlock, race conditions)"),
                createBullet("I/O models (blocking, non-blocking, async, multiplexing)"),

                // 1.2 Linux & Command Line Mastery
                createChapterHeader("1.2", "Linux & Command Line Mastery", COLORS.PHASE1),
                
                createSubHeader("Linux Fundamentals"),
                createBullet("File system hierarchy (/, /etc, /var, /home, /opt, /tmp)"),
                createBullet("File permissions (chmod, chown, chgrp, umask, ACLs)"),
                createBullet("Package management (apt, yum/dnf, snap)"),
                createBullet("Process management (ps, top, htop, kill, nice, nohup)"),
                createBullet("Systemd services (systemctl, journalctl, unit files)"),

                createSubHeader("Shell Scripting (Bash)"),
                createBullet("Variables, arrays, conditionals (if/elif/else, case)"),
                createBullet("Loops (for, while, until), functions, exit codes"),
                createBullet("Text processing: grep, sed, awk, cut, sort, uniq, tr, wc"),
                createBullet("Piping (|), redirection (>, >>, 2>&1, tee)"),
                createBullet("Regular expressions (basic & extended)"),
                createBullet("Cron jobs & scheduling (crontab -e, cron syntax)"),

                createSubHeader("Essential CLI Tools"),
                createBullet("curl, wget, jq (JSON processing)"),
                createBullet("xargs, find, locate"),
                createBullet("ssh, scp, rsync"),
                createBullet("tar, gzip, zstd, zip/unzip"),

                // 1.3 Networking Fundamentals
                createChapterHeader("1.3", "Networking Fundamentals", COLORS.PHASE1),
                createBullet("OSI model & TCP/IP stack"),
                createBullet("HTTP/HTTPS (methods, status codes, headers, cookies, TLS/SSL)"),
                createBullet("REST APIs (verbs, resources, status codes, pagination)"),
                createBullet("DNS resolution, CDNs, load balancers (L4 vs L7)"),
                createBullet("Firewalls (iptables/nftables, security groups)"),
                createBullet("VPN, SSH tunneling, port forwarding"),

                // 1.4 Version Control – Git
                createChapterHeader("1.4", "Version Control – Git", COLORS.PHASE1),
                createBullet("Core concepts: commits, staging, branches, tags"),
                createBullet("Branching strategies (GitFlow, trunk-based, GitHub Flow)"),
                createBullet("Merging vs Rebasing (when to use each)"),
                createBullet("Pull Requests / Merge Requests, code review best practices"),
                createBullet("CI/CD basics (GitHub Actions, GitLab CI overview)"),
                createBullet("Pre-commit hooks, .gitignore, Git LFS"),

                new Paragraph({ children: [new PageBreak()] }),

                // 1.5 Python Deep Dive
                createChapterHeader("1.5", "Python Deep Dive", COLORS.PHASE1),
                
                createSubHeader("Core Python"),
                createBullet("Data types, collections (list, dict, set, tuple, deque)"),
                createBullet("Control flow, functions, comprehensions, lambda"),
                createBullet("File I/O (text, CSV, JSON, binary)"),
                createBullet("Exception handling (try/except/finally, custom exceptions)"),

                createSubHeader("Intermediate Python"),
                createBullet("OOP (classes, inheritance, polymorphism, abstract classes)"),
                createBullet("Decorators, generators, iterators, context managers"),
                createBullet("Type hints (typing module, mypy)"),
                createBullet("Modules, packages, virtual environments (venv, poetry)"),
                createBullet("Logging (logging module, handlers, formatters)"),

                createSubHeader("Data Engineering Python"),
                createBullet("Pandas (DataFrame, Series, groupby, merge, pivot, window functions)"),
                createBullet("NumPy (arrays, vectorization, broadcasting)"),
                createBullet("Requests & httpx (REST API consumption)"),
                createBullet("SQLAlchemy (ORM, Core, engine, sessions, migrations)"),
                createBullet("argparse / click (CLI tools)"),
                createBullet("Multiprocessing, threading, asyncio (concurrent data processing)"),
                createBullet("pytest (fixtures, parametrize, mocking, conftest)"),

                // 1.6 Scala Fundamentals
                createChapterHeader("1.6", "Scala Fundamentals", COLORS.PHASE1),
                createBullet("val/var, type inference, functions, case classes"),
                createBullet("Collections API (List, Map, Set, Seq, Option, Either)"),
                createBullet("Pattern matching, for-comprehensions"),
                createBullet("Traits, implicits, type classes"),
                createBullet("SBT build tool (build.sbt, dependencies, tasks)"),
                createBullet("Functional programming patterns for data processing"),

                // 1.7 Java Basics
                createChapterHeader("1.7", "Java Basics (for JVM Ecosystem)", COLORS.PHASE1),
                createBullet("JVM architecture (ClassLoader, heap, stack, GC)"),
                createBullet("Core syntax, OOP, generics, collections framework"),
                createBullet("Maven / Gradle (dependency management, build lifecycle)"),
                createBullet("JVM tuning (-Xmx, -Xms, GC algorithms, JMX monitoring)"),

                new Paragraph({ children: [new PageBreak()] }),

                // ========== PHASE 2 ==========
                createPhaseBanner("2", "Database Systems & SQL Mastery", "(6–8 weeks)", COLORS.PHASE2),
                new Paragraph({ spacing: { after: 300 } }),

                // 2.1 RDBMS Concepts & Theory
                createChapterHeader("2.1", "RDBMS Concepts & Theory", COLORS.PHASE2),
                createBullet("Database architecture (storage engine, query engine, buffer pool)"),
                createBullet("ACID properties (Atomicity, Consistency, Isolation, Durability)"),
                createBullet("CAP theorem (Consistency, Availability, Partition tolerance)"),
                createBullet("OLTP vs OLAP (transactional vs analytical workloads)"),
                createBullet("Row-store vs Column-store (trade-offs, use cases)"),
                createBullet("Normalization (1NF, 2NF, 3NF, BCNF) & denormalization"),
                createBullet("ER modeling (entities, relationships, cardinality)"),

                // 2.2 Advanced SQL
                createChapterHeader("2.2", "Advanced SQL", COLORS.PHASE2),
                
                createSubHeader("Core SQL"),
                createBullet("DDL (CREATE, ALTER, DROP, TRUNCATE) & DML (INSERT, UPDATE, DELETE, MERGE)"),
                createBullet("JOINs (INNER, LEFT, RIGHT, FULL, CROSS, SELF, LATERAL)"),
                createBullet("Subqueries (scalar, correlated, EXISTS, IN)"),
                createBullet("Set operations (UNION, INTERSECT, EXCEPT / MINUS)"),

                createSubHeader("Window Functions"),
                createBullet("ROW_NUMBER(), RANK(), DENSE_RANK(), NTILE()"),
                createBullet("Aggregate windows (SUM, AVG, COUNT with PARTITION BY / ORDER BY)"),
                createBullet("LAG(), LEAD(), FIRST_VALUE(), LAST_VALUE(), NTH_VALUE()"),
                createBullet("Frame specification (ROWS BETWEEN, RANGE BETWEEN)"),

                createSubHeader("Advanced Constructs"),
                createBullet("CTEs (Common Table Expressions) & Recursive CTEs"),
                createBullet("Pivot / Unpivot (CROSS APPLY, LATERAL, conditional aggregation)"),
                createBullet("JSON functions (JSON_EXTRACT, JSON_ARRAY_ELEMENTS, ->, ->>)"),
                createBullet("Regular expressions in SQL (REGEXP, SIMILAR TO)"),
                createBullet("Date/time functions & temporal queries"),
                createBullet("CASE / COALESCE / NULLIF / GREATEST / LEAST"),

                // 2.3 Query Performance & Optimization
                createChapterHeader("2.3", "Query Performance & Optimization", COLORS.PHASE2),
                createBullet("EXPLAIN / ANALYZE (reading execution plans, cost estimation)"),
                createBullet("Index types: B-Tree, Hash, GiST, GIN, BRIN, partial, composite, covering"),
                createBullet("Query optimization (predicate pushdown, join reordering, statistics)"),
                createBullet("Table partitioning (Range, List, Hash partitioning)"),
                createBullet("Materialized views (refresh strategies, query rewriting)"),
                createBullet("Stored procedures, triggers, user-defined functions"),
                createBullet("VACUUM / ANALYZE (dead tuple cleanup, statistics updates)"),

                new Paragraph({ children: [new PageBreak()] }),

                // 2.4 PostgreSQL
                createChapterHeader("2.4", "PostgreSQL (Primary RDBMS)", COLORS.PHASE2),
                createBullet("Installation, configuration (postgresql.conf, pg_hba.conf)"),
                createBullet("psql CLI, pgAdmin, DBeaver"),
                createBullet("Advanced data types: JSONB, ARRAY, UUID, HSTORE, composite, range"),
                createBullet("Extensions (pg_stat_statements, PostGIS, pg_trgm, pg_cron)"),
                createBullet("Full-text search (tsvector, tsquery, GIN indexes)"),
                createBullet("Replication (streaming, logical replication, pg_basebackup)"),
                createBullet("Backup/restore (pg_dump, pg_restore, WAL archiving, PITR)"),
                createBullet("Connection pooling (PgBouncer, pgpool-II)"),

                // 2.5 MySQL
                createChapterHeader("2.5", "MySQL", COLORS.PHASE2),
                createBullet("InnoDB vs MyISAM (ACID, locking, full-text, foreign keys)"),
                createBullet("MySQL syntax differences from PostgreSQL"),
                createBullet("Binary log (row-based, statement-based, mixed replication)"),
                createBullet("Performance tuning (slow query log, query cache, buffer pool)"),

                new Paragraph({ children: [new PageBreak()] }),

                // ========== PHASE 3 ==========
                createPhaseBanner("3", "Hadoop Ecosystem & Big Data", "(8–10 weeks)", COLORS.PHASE3),
                new Paragraph({ spacing: { after: 300 } }),

                // 3.1 Hadoop Architecture & History
                createChapterHeader("3.1", "Hadoop Architecture & History", COLORS.PHASE3),
                createBullet("Origin: Google GFS, MapReduce, Bigtable papers"),
                createBullet("Distributions: Cloudera (CDP), Hortonworks, AWS EMR, GCP Dataproc"),
                createBullet("Cluster architecture, daemons, configuration files"),
                createBullet("Hadoop 2.x vs 3.x (YARN, erasure coding, timeline service)"),

                // 3.2 HDFS
                createChapterHeader("3.2", "HDFS (Hadoop Distributed File System)", COLORS.PHASE3),
                
                createSubHeader("Architecture"),
                createBullet("NameNode, DataNode, Secondary NameNode (checkpoint)"),
                createBullet("Block storage (128MB default, replication factor 3)"),
                createBullet("Write path (pipeline replication) & Read path"),
                createBullet("Federation (multiple NameNodes) & High Availability (Active/Standby + ZooKeeper)"),
                createBullet("Rack awareness, data locality"),

                createSubHeader("Operations"),
                createBullet("CLI commands: hdfs dfs -ls, -put, -get, -cat, -mkdir, -rm, -chmod, -chown"),
                createBullet("WebHDFS REST API, HttpFS"),
                createBullet("Snapshots, quotas, safe mode"),

                createSubHeader("File Formats & Compression"),
                createBulletBold("Text/CSV:", " simple but no schema, no compression optimization"),
                createBulletBold("SequenceFile:", " binary key-value pairs, splittable"),
                createBulletBold("Avro:", " row-based, schema evolution, compact binary, Kafka-optimized"),
                createBulletBold("Parquet:", " columnar, excellent compression, predicate pushdown, analytics-optimized"),
                createBulletBold("ORC:", " columnar, Hive ecosystem, ACID support, lightweight indexing"),
                createBulletBold("Compression codecs:", " Snappy (fast), Gzip (high ratio), LZO (splittable), Zstandard (best balance)"),
                createBullet("Splittable vs non-splittable compression (critical for MapReduce)"),
                createBullet("Erasure coding (space-efficient alternative to replication)"),

                // 3.3 MapReduce
                createChapterHeader("3.3", "MapReduce", COLORS.PHASE3),
                createBullet("Paradigm: Map → Shuffle & Sort → Reduce"),
                createBullet("InputFormat, InputSplit, RecordReader"),
                createBullet("Mapper, Combiner (local reducer), Partitioner"),
                createBullet("Reducer, OutputFormat"),
                createBullet("Counters, Distributed Cache"),
                createBullet("Java & Python (Hadoop Streaming) implementations"),
                createBullet("Design patterns: filtering, summarization, joins (map-side, reduce-side, replicated)"),
                createBullet("Chaining jobs, job sequencing"),

                new Paragraph({ children: [new PageBreak()] }),

                // 3.4 YARN
                createChapterHeader("3.4", "YARN (Yet Another Resource Negotiator)", COLORS.PHASE3),
                createBullet("ResourceManager (scheduler + application manager)"),
                createBullet("NodeManager, ApplicationMaster, Containers"),
                createBullet("Schedulers: FIFO, Capacity Scheduler, Fair Scheduler"),
                createBullet("Queue management, resource allocation, preemption"),
                createBullet("Application lifecycle, CLI (yarn application), YARN UI"),

                // 3.5 Hive
                createChapterHeader("3.5", "Hive", COLORS.PHASE3),
                createBullet("Architecture: Metastore, Driver, Compiler, Optimizer, Executor"),
                createBullet("HiveQL (SQL-like syntax for batch processing)"),
                createBullet("Managed vs External tables"),
                createBullet("Partitioning (static, dynamic, multi-level) & Bucketing"),
                createBullet("File formats & SerDe (JSON, CSV, RegEx, Avro, ORC, Parquet)"),
                createBullet("User-Defined Functions (UDF, UDAF, UDTF)"),
                createBullet("Execution engines: Hive on Tez, Hive on Spark"),
                createBullet("LLAP (Live Long and Process) – interactive queries"),
                createBullet("Hive Metastore as universal metadata catalog"),

                // 3.6 Pig
                createChapterHeader("3.6", "Pig", COLORS.PHASE3),
                createBullet("Pig Latin: LOAD, STORE, FILTER, GROUP, FOREACH, JOIN, ORDER, DISTINCT"),
                createBullet("Execution modes (local, MapReduce, Tez)"),
                createBullet("UDFs in Java/Python"),

                // 3.7 HBase
                createChapterHeader("3.7", "HBase", COLORS.PHASE3),
                createBullet("Architecture: RegionServer, HMaster, ZooKeeper coordination"),
                createBullet("Column-family data model (row key, column families, qualifiers, timestamps)"),
                createBullet("HBase Shell commands (create, put, get, scan, delete)"),
                createBullet("Row key design (avoid hotspotting – salting, hashing, reverse timestamps)"),
                createBullet("Filters (SingleColumnValueFilter, PrefixFilter, RowFilter)"),
                createBullet("Integration: Hive-HBase, Spark-HBase, Phoenix SQL layer"),
                createBullet("Compactions (minor vs major), region splits, pre-splitting"),

                // 3.8 Sqoop
                createChapterHeader("3.8", "Sqoop", COLORS.PHASE3),
                createBullet("Import (RDBMS → HDFS/Hive/HBase)"),
                createBullet("Export (HDFS → RDBMS)"),
                createBullet("Incremental imports (append, lastmodified)"),
                createBullet("Connectors (MySQL, PostgreSQL, Oracle, SQL Server)"),
                createBullet("Parallel imports (--num-mappers), direct mode"),
                createBullet("File format options (text, Avro, Parquet, SequenceFile)"),

                new Paragraph({ children: [new PageBreak()] }),

                // 3.9 Flume
                createChapterHeader("3.9", "Flume", COLORS.PHASE3),
                createBullet("Agent architecture: Source → Channel → Sink"),
                createBullet("Sources: Avro, Exec, Spooling Directory, Taildir, Kafka"),
                createBullet("Channels: Memory, File, Kafka"),
                createBullet("Sinks: HDFS, HBase, Kafka, Elasticsearch"),
                createBullet("Multi-hop flows, fan-in, fan-out topologies"),
                createBullet("Interceptors (timestamp, host, regex filtering)"),

                // 3.10 Oozie
                createChapterHeader("3.10", "Oozie", COLORS.PHASE3),
                createBullet("Workflow (DAG of actions – MapReduce, Pig, Hive, Shell, Spark)"),
                createBullet("Coordinator (time-based & data-based scheduling)"),
                createBullet("Bundle (collection of coordinators)"),
                createBullet("workflow.xml structure, parameterization (EL expressions)"),

                // 3.11 Hadoop Security
                createChapterHeader("3.11", "Hadoop Security", COLORS.PHASE3),
                createBullet("Kerberos: KDC, principals, keytabs, kinit, ticket-based authentication"),
                createBullet("Apache Ranger: fine-grained access control, policies, auditing"),
                createBullet("Apache Knox: gateway / perimeter security, REST API proxy"),
                createBullet("HDFS Encryption: Transparent Data Encryption (TDE), KMS"),
                createBullet("Wire Encryption: SSL/TLS for RPC and HTTP"),

                // 3.12 ZooKeeper
                createChapterHeader("3.12", "ZooKeeper", COLORS.PHASE3),
                createBullet("Coordination service for distributed systems"),
                createBullet("Znodes (ephemeral, persistent, sequential)"),
                createBullet("Leader election, configuration management, distributed locking"),
                createBullet("CLI: create, get, set, ls, stat, delete"),

                new Paragraph({ children: [new PageBreak()] }),

                // ========== PHASE 4 ==========
                createPhaseBanner("4", "Data Processing & Compute Engines", "(8–10 weeks)", COLORS.PHASE4),
                new Paragraph({ spacing: { after: 300 } }),

                // 4.1 Apache Spark
                createChapterHeader("4.1", "Apache Spark – Core Architecture", COLORS.PHASE4),
                createBullet("Driver Program, Executors, Cluster Manager"),
                createBullet("Cluster modes: Standalone, YARN, Mesos, Kubernetes"),
                createBullet("Deploy modes: Client vs Cluster (when to use each)"),

                createSubHeader("RDD (Resilient Distributed Datasets)"),
                createBullet("Immutability, partitioning, lineage (DAG)"),
                createBullet("Transformations: map, flatMap, filter, reduceByKey, groupByKey, join, union"),
                createBullet("Actions: collect, count, take, saveAsTextFile, foreach"),
                createBullet("Narrow vs Wide transformations (shuffle boundary)"),

                createSubHeader("Execution Model"),
                createBullet("DAG: Jobs → Stages → Tasks"),
                createBullet("Spark UI (stages, tasks, storage, SQL tab, event timeline)"),
                createBullet("Persistence & caching (MEMORY_ONLY, MEMORY_AND_DISK, DISK_ONLY, OFF_HEAP)"),
                createBullet("Broadcast variables & Accumulators"),
                createBullet("Serialization: Java vs Kryo (performance implications)"),

                // 4.2 Spark Performance Tuning
                createChapterHeader("4.2", "Spark Performance Tuning", COLORS.PHASE4),
                createBulletBold("Data Skew:", " salting, repartitioning, broadcast joins for skewed keys"),
                createBulletBold("Shuffle Optimization:", " spark.sql.shuffle.partitions, coalesce vs repartition"),
                createBulletBold("Memory Management:", " executor/driver memory, off-heap, unified memory model"),
                createBulletBold("Executor Tuning:", " cores per executor, number of executors, dynamic allocation"),
                createBulletBold("Broadcast Joins:", " broadcast threshold, explicit broadcast hint"),
                createBulletBold("AQE:", " Adaptive Query Execution (coalesce shuffle partitions, skew join optimization)"),
                createBullet("Spill to disk analysis, speculation mode"),

                // 4.3 PySpark
                createChapterHeader("4.3", "PySpark", COLORS.PHASE4),
                
                createSubHeader("DataFrame API"),
                createBullet("SparkSession creation and configuration"),
                createBullet("Operations: select, filter/where, withColumn, agg, groupBy, join, orderBy"),
                createBullet("Column operations: col(), lit(), when(), cast(), alias(), isNull()"),
                createBullet("SQL mode: registerTempView, spark.sql()"),

                createSubHeader("UDFs & Pandas Integration"),
                createBullet("@udf decorator, pandas_udf (Scalar, Grouped Map, Grouped Agg)"),
                createBullet("toPandas(), createDataFrame from Pandas, Apache Arrow optimization"),

                new Paragraph({ children: [new PageBreak()] }),

                createSubHeader("Data I/O"),
                createBullet("Reading/Writing: CSV, JSON, Parquet, ORC, Avro, JDBC, Delta, Hudi, Iceberg"),
                createBullet("Schema enforcement: StructType, StructField, data types"),
                createBullet("Complex types: ArrayType, MapType, StructType, explode, posexplode, flatten"),

                // 4.4 Spark SQL & Catalyst
                createChapterHeader("4.4", "Spark SQL & Catalyst", COLORS.PHASE4),
                createBullet("Catalyst optimizer: Logical Plan → Optimized Plan → Physical Plan"),
                createBullet("Cost-Based Optimization (CBO), statistics collection"),
                createBullet("Tungsten engine: code generation, memory management"),
                createBullet("Window functions (identical to SQL – OVER, PARTITION BY, ORDER BY)"),
                createBullet("Hive Metastore integration (external catalog)"),
                createBullet("Data sources API V2 (custom connectors)"),
                createBullet("Temporary vs Global Temporary Views"),

                // 4.5 Spark Structured Streaming
                createChapterHeader("4.5", "Spark Structured Streaming", COLORS.PHASE4),
                createBullet("Micro-batch processing vs Continuous processing (experimental)"),
                createBullet("Input Sources: Kafka, File (CSV/JSON/Parquet), Socket, Rate"),
                createBullet("Output Sinks: Kafka, File, Console, Memory, Foreach/ForeachBatch"),
                createBullet("Output Modes: Append, Complete, Update"),
                createBullet("Watermarking (late data handling, event-time processing)"),
                createBullet("Stateful operations: windowed aggregations, mapGroupsWithState, flatMapGroupsWithState"),
                createBullet("Checkpointing (exactly-once semantics, recovery)"),
                createBullet("Stream-stream joins & stream-static joins"),

                // 4.6 Spark MLlib
                createChapterHeader("4.6", "Spark MLlib (Overview)", COLORS.PHASE4),
                createBullet("MLlib vs ML package (RDD-based vs DataFrame-based)"),
                createBullet("Pipeline API: Transformer, Estimator, Pipeline, PipelineModel"),
                createBullet("Feature engineering: VectorAssembler, StringIndexer, OneHotEncoder, StandardScaler"),
                createBullet("Algorithms: Linear/Logistic Regression, Random Forest, GBT, K-Means"),
                createBullet("Model evaluation, hyperparameter tuning (CrossValidator, ParamGridBuilder)"),

                // 4.7 Apache Flink
                createChapterHeader("4.7", "Apache Flink", COLORS.PHASE4),
                createBullet("Architecture: JobManager, TaskManager, slots, parallelism"),
                createBullet("DataStream API (event-driven processing)"),
                createBullet("Time semantics: event time, processing time, ingestion time"),
                createBullet("Windowing: Tumbling, Sliding, Session, Global windows"),
                createBullet("State management: keyed state, operator state, state backends (RocksDB, HashMap)"),
                createBullet("Checkpointing & Savepoints (exactly-once semantics)"),
                createBullet("Flink SQL / Table API (stream & batch SQL)"),
                createBullet("CDC connectors, temporal joins"),
                createBullet("Flink vs Spark Streaming: true streaming vs micro-batch, latency, state management"),

                new Paragraph({ children: [new PageBreak()] }),

                // 4.8 Apache Beam
                createChapterHeader("4.8", "Apache Beam", COLORS.PHASE4),
                createBullet("Unified model: Pipeline, PCollection, PTransform"),
                createBullet("Runners: DirectRunner, DataflowRunner, FlinkRunner, SparkRunner"),
                createBullet("ParDo / DoFn (parallel processing)"),
                createBullet("GroupByKey, CoGroupByKey, Combine"),
                createBullet("Windowing: Fixed, Sliding, Session, Global"),
                createBullet("Triggers & accumulation modes"),
                createBullet("Side inputs / Side outputs"),

                // 4.9 Presto / Trino
                createChapterHeader("4.9", "Presto / Trino", COLORS.PHASE4),
                createBullet("Architecture: Coordinator, Workers, Connectors"),
                createBullet("SQL federation across heterogeneous sources (Hive, Cassandra, MySQL, Kafka, S3)"),
                createBullet("Memory management, query scheduling"),
                createBullet("Presto vs Trino: fork history, community, enterprise offerings"),

                new Paragraph({ children: [new PageBreak()] }),

                // ========== PHASE 5 ==========
                createPhaseBanner("5", "Data Integration, Streaming & CDC", "(6–8 weeks)", COLORS.PHASE5),
                new Paragraph({ spacing: { after: 300 } }),

                // 5.1 Apache Kafka – Core
                createChapterHeader("5.1", "Apache Kafka – Core", COLORS.PHASE5),
                
                createSubHeader("Architecture"),
                createBullet("Brokers, Topics, Partitions, Offsets"),
                createBullet("Producers, Consumers, Consumer Groups"),
                createBullet("ZooKeeper (legacy) vs KRaft mode (metadata quorum)"),

                createSubHeader("Producers"),
                createBullet("Partitioning strategy (key-based, round-robin, custom)"),
                createBullet("Acknowledgments: acks=0, acks=1, acks=all"),
                createBullet("Idempotent producer (exactly-once per partition)"),
                createBullet("Batching (batch.size, linger.ms), compression (snappy, lz4, zstd)"),

                createSubHeader("Consumers"),
                createBullet("Consumer groups, partition assignment (Range, RoundRobin, Sticky, Cooperative)"),
                createBullet("Offset management: auto-commit vs manual commit"),
                createBullet("Consumer rebalancing protocols"),

                createSubHeader("Delivery & Storage"),
                createBullet("Delivery semantics: at-most-once, at-least-once, exactly-once (EOS)"),
                createBullet("Log segments, retention (time-based, size-based), compaction"),
                createBullet("ISR (In-Sync Replicas), leader election, min.insync.replicas"),

                // 5.2 Kafka Ecosystem
                createChapterHeader("5.2", "Kafka Ecosystem", COLORS.PHASE5),
                createBulletBold("Kafka Connect:", " source & sink connectors, distributed mode, Single Message Transforms (SMT)"),
                createBullet("Key connectors: JDBC, S3, Elasticsearch, MongoDB, BigQuery, Debezium"),
                createBulletBold("Schema Registry:", " Avro, Protobuf, JSON Schema; compatibility modes (BACKWARD/FORWARD/FULL)"),
                createBulletBold("Kafka Streams:", " KTable, KStream, joins, windowing, interactive queries"),
                createBulletBold("ksqlDB:", " streaming SQL, materialized views, push/pull queries"),
                createBullet("REST Proxy, MirrorMaker 2 (cross-cluster replication)"),

                createSubHeader("Kafka Operations"),
                createBullet("CLI: kafka-topics.sh, kafka-console-producer/consumer.sh, kafka-consumer-groups.sh"),
                createBullet("Lag monitoring, offset reset strategies"),
                createBullet("Monitoring: JMX metrics, Kafka Exporter, Prometheus + Grafana dashboards"),
                createBullet("Performance tuning: batch.size, linger.ms, compression.type, num.partitions"),

                // 5.3 Debezium
                createChapterHeader("5.3", "Debezium – Change Data Capture (CDC)", COLORS.PHASE5),
                createBullet("Log-based CDC vs query-based CDC (advantages of log-based)"),
                createBullet("Architecture: Kafka Connect-based, reads database transaction logs"),
                createBullet("Supported databases: MySQL (binlog), PostgreSQL (WAL/pgoutput), MongoDB (oplog), Oracle (LogMiner), SQL Server"),
                createBullet("Event structure: before/after state, operation type (c/r/u/d)"),
                createBullet("Snapshot modes: initial, schema_only, never, when_needed"),
                createBullet("Transforms: SMTs, ExtractNewRecordState, outbox pattern"),
                createBullet("Schema evolution (DDL changes, schema history topic)"),
                createBullet("Debezium Server (standalone mode without Kafka Connect)"),

                new Paragraph({ children: [new PageBreak()] }),

                // 5.4 Apache NiFi
                createChapterHeader("5.4", "Apache NiFi", COLORS.PHASE5),
                createBullet("Concepts: FlowFile, Processor, Connection, Process Group, Controller Service"),
                createBullet("Drag-and-drop UI, templates, versioning (NiFi Registry)"),
                createBullet("Key processors: GetFile, PutFile, ConvertRecord, ExecuteSQL, PutKafka, PutHDFS, InvokeHTTP"),
                createBullet("Data provenance (full lineage tracking)"),
                createBullet("Back pressure (queue tuning, flow control)"),
                createBullet("Clustering (zero-leader architecture)"),
                createBullet("MiNiFi (lightweight edge agent)"),

                // 5.5 Cloud Streaming Services
                createChapterHeader("5.5", "Cloud Streaming Services", COLORS.PHASE5),
                
                createSubHeader("AWS Kinesis"),
                createBullet("Data Streams (shards, partition keys, retention 24h–365 days)"),
                createBullet("Data Firehose (near-real-time delivery to S3/Redshift/Elasticsearch)"),
                createBullet("Data Analytics (SQL and Flink on streaming data)"),
                createBullet("KCL (Kinesis Client Library), checkpointing"),

                createSubHeader("GCP Pub/Sub"),
                createBullet("Topics, Subscriptions (Pull/Push), global distribution"),
                createBullet("Message ordering (ordering keys), dead-letter topics"),
                createBullet("Pub/Sub Lite (zonal, lower-cost)"),
                createBullet("Dataflow integration"),

                createSubHeader("Apache Pulsar"),
                createBullet("Brokers, BookKeeper, ZooKeeper; multi-tenancy"),
                createBullet("Tiered storage (S3/GCS/Azure Blob)"),
                createBullet("Pulsar Functions, Pulsar IO (connectors)"),
                createBullet("Pulsar vs Kafka: segmented architecture, geo-replication, multi-tenancy"),

                // 5.6 Event-Driven Architecture Patterns
                createChapterHeader("5.6", "Event-Driven Architecture Patterns", COLORS.PHASE5),
                createBullet("Event sourcing (append-only event log as source of truth)"),
                createBullet("CQRS (Command Query Responsibility Segregation)"),
                createBullet("Saga pattern (choreography vs orchestration)"),
                createBullet("Schema evolution strategies (backward/forward compatible)"),
                createBullet("Idempotency patterns, transactional outbox"),

                new Paragraph({ children: [new PageBreak()] }),

                // ========== PHASE 6 ==========
                createPhaseBanner("6", "Workflow Orchestration & Scheduling", "(4–6 weeks)", COLORS.PHASE6),
                new Paragraph({ spacing: { after: 300 } }),

                // 6.1 Cron & Systemd Timers
                createChapterHeader("6.1", "Cron & Systemd Timers", COLORS.PHASE6),
                createBullet("Cron syntax (minute, hour, day, month, weekday)"),
                createBullet("crontab management (crontab -e/-l, user vs system)"),
                createBullet("Best practices: logging, error notifications, lock files (flock)"),
                createBullet("Systemd timers (.timer/.service units, calendar events)"),

                // 6.2 Apache Airflow (Deep Dive)
                createChapterHeader("6.2", "Apache Airflow (Deep Dive)", COLORS.PHASE6),
                
                createSubHeader("Architecture"),
                createBullet("Components: Webserver, Scheduler, Executor, Metadata DB, Workers"),
                createBullet("Executors: SequentialExecutor, LocalExecutor, CeleryExecutor, KubernetesExecutor"),

                createSubHeader("DAG Development"),
                createBullet("DAG definition: dag_id, schedule_interval, start_date, catchup, tags"),
                createBullet("Operators: BashOperator, PythonOperator, PostgresOperator, SparkSubmitOperator"),
                createBullet("Cloud operators: S3ToGCSOperator, BigQueryInsertJobOperator, DataprocSubmitJobOperator"),
                createBullet("Sensors: FileSensor, S3KeySensor, ExternalTaskSensor, HttpSensor, SqlSensor"),

                createSubHeader("TaskFlow API"),
                createBullet("@task decorator, automatic XCom passing"),
                createBullet("Dynamic task mapping (expand, partial)"),
                createBullet("XCom: cross-task communication (push/pull, size limits)"),

                createSubHeader("Advanced Features"),
                createBullet("Connections / Hooks (database & cloud connections, custom hooks)"),
                createBullet("Variables & Pools (global config, concurrency control)"),
                createBullet("Branching (BranchPythonOperator, conditional execution)"),
                createBullet("Trigger rules: all_success, all_failed, one_success, none_failed, all_done"),
                createBullet("SubDAGs vs TaskGroups (prefer TaskGroups)"),
                createBullet("Dynamic DAG generation (factory functions, config-driven)"),

                createSubHeader("Operations"),
                createBullet("CLI: trigger, backfill, test, list_dags, clear, pause/unpause"),
                createBullet("UI: Tree view, Graph view, Gantt chart, task logs"),
                createBullet("Deployment: Docker Compose, Helm on K8s, MWAA (AWS), Cloud Composer (GCP)"),
                createBullet("Monitoring: StatsD, Prometheus, SLA alerting"),
                createBullet("Best practices: idempotent tasks, no side effects in DAG files, atomicity, testing"),
                createBullet("Security: RBAC, LDAP/OAuth integration, Fernet key encryption"),

                new Paragraph({ children: [new PageBreak()] }),

                // 6.3 Luigi
                createChapterHeader("6.3", "Luigi", COLORS.PHASE6),
                createBullet("Concepts: Task, Target, Parameter, Worker, Central Scheduler"),
                createBullet("Task dependencies (requires(), output())"),
                createBullet("Targets: LocalTarget, S3Target, HDFSTarget"),
                createBullet("Parameters: IntParameter, DateParameter, ListParameter"),
                createBullet("Luigi daemon (central scheduler UI, task visualization)"),
                createBullet("Luigi vs Airflow: simple dependency resolution vs full orchestration"),

                // 6.4 Prefect
                createChapterHeader("6.4", "Prefect", COLORS.PHASE6),
                createBullet("Concepts: Flows, Tasks, Flow Runs, Deployments, Work Pools"),
                createBullet("Prefect 2.x/3.x (@flow/@task decorators, Pythonic API)"),
                createBullet("State handling: Pending, Running, Completed, Failed, Retrying, Cancelled"),
                createBullet("Retries, caching, scheduling (Cron, Interval, RRule)"),
                createBullet("Prefect UI (flow run tracking, deployment management)"),
                createBullet("Prefect Cloud vs Server (managed vs self-hosted)"),
                createBullet("Infrastructure blocks (Docker, K8s, Process, ECS)"),
                createBullet("Prefect vs Airflow: Pythonic, no DAG constraints, dynamic pipelines"),

                // 6.5 Dagster
                createChapterHeader("6.5", "Dagster", COLORS.PHASE6),
                createBullet("Concepts: Assets, Ops, Jobs, Graphs, Resources, IO Managers"),
                createBullet("Software-Defined Assets (declarative pipeline definition)"),
                createBullet("Dagster UI / Dagit (asset lineage, run monitoring, launchpad)"),
                createBullet("Partitions & Backfills (time-based, incremental processing)"),
                createBullet("Schedules & Sensors (time-based, event-driven triggers)"),
                createBullet("Resources (dependency injection), IO Managers (S3, BigQuery, Snowflake)"),
                createBullet("Testing: unit testing ops/assets, in-memory IO managers"),
                createBullet("Dagster vs Airflow: asset-centric vs task-centric, type system, testability"),

                // 6.6 Mage.ai
                createChapterHeader("6.6", "Mage.ai", COLORS.PHASE6),
                createBullet("Concepts: Blocks (Loader, Transformer, Exporter), Pipelines, Triggers"),
                createBullet("Interactive notebook-style block development"),
                createBullet("Pipeline types: standard, streaming, integration"),
                createBullet("Templates, reusability, built-in testing"),
                createBullet("Mage vs Airflow: notebook-first, faster iteration, built-in testing"),

                new Paragraph({ children: [new PageBreak()] }),

                // ========== PHASE 7 ==========
                createPhaseBanner("7", "NoSQL, Data Warehousing & Modeling", "(8–10 weeks)", COLORS.PHASE7),
                new Paragraph({ spacing: { after: 300 } }),

                // 7.1 MongoDB
                createChapterHeader("7.1", "MongoDB", COLORS.PHASE7),
                createBullet("Data model: collections, documents, BSON format"),
                createBullet("Architecture: mongod, mongos, config servers"),
                createBullet("CRUD: insertOne, find, updateOne, deleteOne, bulkWrite"),
                createBullet("Aggregation framework: $match, $group, $project, $unwind, $lookup, $sort, $limit, $facet"),
                createBullet("Indexing: single field, compound, multikey, text, geospatial, TTL, wildcard"),
                createBullet("Replication: Replica Sets, primary/secondary, read preferences"),
                createBullet("Sharding: shard key selection (ranged vs hashed), balancer, chunks"),
                createBullet("Schema design patterns: embedding vs referencing, denormalization, bucket pattern"),
                createBullet("Change Streams (real-time data change notifications)"),
                createBullet("MongoDB Atlas (managed cloud, Atlas Search, Data Federation)"),

                // 7.2 Apache Cassandra
                createChapterHeader("7.2", "Apache Cassandra", COLORS.PHASE7),
                createBullet("Architecture: peer-to-peer, gossip protocol, consistent hashing, vnodes"),
                createBullet("Data model: keyspace, table, partition key, clustering key, static columns"),
                createBullet("CQL: SELECT, INSERT, UPDATE, DELETE, TTL, BATCH"),
                createBullet("Write path: commit log → memtable → SSTable flush → compaction"),
                createBullet("Read path: memtable + SSTables, bloom filters, key/row cache"),
                createBullet("Consistency levels: ONE, QUORUM, ALL, LOCAL_QUORUM"),
                createBullet("Data modeling: query-first design, denormalization, materialized views"),
                createBullet("Anti-patterns: secondary indexes on high-cardinality, large partitions"),

                // 7.3 Redis
                createChapterHeader("7.3", "Redis", COLORS.PHASE7),
                createBullet("Data structures: String, List, Set, Sorted Set, Hash, Stream, HyperLogLog, Bitmap"),
                createBullet("Persistence: RDB snapshots, AOF, hybrid"),
                createBullet("Pub/Sub, Redis Streams (consumer groups)"),
                createBullet("Redis Cluster (sharding, replication, automatic failover)"),
                createBullet("Caching patterns: cache-aside, write-through, write-behind, TTL strategies"),
                createBullet("Use cases: caching, session storage, rate limiting, real-time leaderboards"),

                // 7.4 Neo4j
                createChapterHeader("7.4", "Neo4j", COLORS.PHASE7),
                createBullet("Graph model: nodes, relationships, properties, labels"),
                createBullet("Cypher query language: MATCH, CREATE, MERGE, WHERE, RETURN"),
                createBullet("Graph algorithms: shortest path, PageRank, community detection"),
                createBullet("Use cases: knowledge graphs, data lineage, recommendation engines, fraud detection"),

                // 7.5 Elasticsearch
                createChapterHeader("7.5", "Elasticsearch", COLORS.PHASE7),
                createBullet("Architecture: index, shard, replica, cluster, node"),
                createBullet("Mappings, data types (keyword, text, nested, geo_point)"),
                createBullet("Querying: match, term, bool, range, aggregations, full-text search"),
                createBullet("ELK Stack (Elasticsearch + Logstash + Kibana)"),
                createBullet("Use cases: log analysis, search, metrics aggregation"),

                new Paragraph({ children: [new PageBreak()] }),

                // 7.6 Data Warehousing Concepts
                createChapterHeader("7.6", "Data Warehousing Concepts", COLORS.PHASE7),
                
                createSubHeader("Architecture Paradigms"),
                createBullet("Data Warehouse vs Data Lake vs Data Lakehouse"),
                createBullet("ETL vs ELT (when to use each)"),
                createBullet("Batch vs Real-time vs Lambda vs Kappa architecture"),

                createSubHeader("Dimensional Modeling"),
                createBullet("Star Schema (fact tables, dimension tables, measures, foreign keys)"),
                createBullet("Snowflake Schema (normalized dimensions)"),
                createBullet("Galaxy Schema (multiple fact tables sharing dimensions)"),

                createSubHeader("Slowly Changing Dimensions (SCD)"),
                createBullet("Type 0 (fixed), Type 1 (overwrite), Type 2 (history tracking)"),
                createBullet("Type 3 (previous value column), Type 4 (mini-dimension), Type 6 (hybrid)"),

                createSubHeader("Dimension & Fact Types"),
                createBullet("Surrogate keys vs natural keys, junk dimensions, degenerate dimensions"),
                createBullet("Role-playing dimensions, conformed dimensions"),
                createBullet("Fact types: Transaction, Periodic Snapshot, Accumulating Snapshot, Factless"),
                createBullet("Data marts (subject-area-specific subsets)"),

                // 7.7 Data Modeling Methodologies
                createChapterHeader("7.7", "Data Modeling Methodologies", COLORS.PHASE7),
                createBullet("Kimball: bottom-up, dimensional modeling, Bus Architecture, Conformed Dimensions"),
                createBullet("Inmon: top-down, enterprise data warehouse, 3NF normalized"),
                createBullet("Data Vault 2.0: Hubs (business keys), Links (relationships), Satellites (descriptive data)"),
                createBullet("Data Vault advantages: auditability, agility, historical tracking, parallel loading"),
                createBullet("One Big Table (OBT): denormalized single table for analytics (trade-offs)"),
                createBullet("Activity Schema: event-based modeling for analytics"),
                createBullet("Anchor Modeling: highly normalized, temporal data modeling"),

                // 7.8 Google BigQuery
                createChapterHeader("7.8", "Google BigQuery", COLORS.PHASE7),
                createBullet("Architecture: Dremel (compute) + Colossus (storage) + Borg + Jupiter (network)"),
                createBullet("Standard SQL with nested/repeated fields (UNNEST, STRUCT, ARRAY)"),
                createBullet("Partitioning: ingestion time, column-based (date/timestamp/integer)"),
                createBullet("Clustering (multi-column, automatic re-clustering)"),
                createBullet("BigQuery ML (CREATE MODEL for ML directly in SQL)"),
                createBullet("BigQuery Storage API (fast bulk reads for Spark/Pandas)"),
                createBullet("Materialized views, scheduled queries, BI Engine caching"),
                createBullet("Cost optimization: on-demand vs flat-rate, slot reservations"),
                createBullet("BigQuery Data Transfer Service"),

                new Paragraph({ children: [new PageBreak()] }),

                // 7.9 Snowflake
                createChapterHeader("7.9", "Snowflake", COLORS.PHASE7),
                createBullet("Architecture: Storage / Compute (Virtual Warehouses) / Cloud Services"),
                createBullet("Virtual warehouses: auto-scaling, auto-suspend, size selection"),
                createBullet("Time Travel (query historical data up to 90 days), UNDROP"),
                createBullet("Zero-copy cloning (instant cloning for dev/test)"),
                createBullet("Snowpipe (continuous loading from S3/GCS/Azure Blob)"),
                createBullet("Streams & Tasks (CDC on Snowflake tables, task scheduling)"),
                createBullet("Secure Data Sharing (exchange without copying)"),
                createBullet("Stages (internal, external), file formats"),
                createBullet("Dynamic Tables (materialized incremental transformations)"),

                // 7.10 Amazon Redshift
                createChapterHeader("7.10", "Amazon Redshift", COLORS.PHASE7),
                createBullet("Architecture: Leader node, Compute nodes, slices"),
                createBullet("Distribution styles: EVEN, KEY, ALL, AUTO"),
                createBullet("Sort keys: compound vs interleaved"),
                createBullet("Redshift Spectrum (query S3 data directly)"),
                createBullet("Redshift Serverless (on-demand, pay-per-query)"),
                createBullet("Concurrency Scaling, COPY command (bulk loading from S3)"),

                // 7.11 ClickHouse & Druid
                createChapterHeader("7.11", "ClickHouse & Druid", COLORS.PHASE7),
                
                createSubHeader("ClickHouse"),
                createBullet("Column-oriented storage (MergeTree engine family)"),
                createBullet("Real-time analytics (sub-second query performance)"),
                createBullet("MaterializedView, AggregatingMergeTree (pre-aggregation)"),
                createBullet("Distributed tables (cross-shard queries)"),

                createSubHeader("Apache Druid"),
                createBullet("Real-time OLAP (segment-based architecture, roll-up)"),
                createBullet("Ingestion: batch (Hadoop/S3), streaming (Kafka)"),
                createBullet("Use cases: time-series analytics, dashboards, ad-tech, monitoring"),

                // 7.12 Open Table Formats
                createChapterHeader("7.12", "Open Table Formats (Data Lakehouse)", COLORS.PHASE7),
                createBullet("Delta Lake: ACID transactions, time travel, schema evolution, Z-ordering"),
                createBullet("Apache Iceberg: hidden partitioning, partition evolution, snapshot isolation"),
                createBullet("Apache Hudi: Copy-on-Write vs Merge-on-Read, incremental processing, CDC support"),
                createBullet("Comparison: Delta vs Iceberg vs Hudi (ecosystem, community, features)"),
                createBullet("Enabling Data Lakehouse architecture on cloud storage"),

                new Paragraph({ children: [new PageBreak()] }),

                // ========== PHASE 8 ==========
                createPhaseBanner("8", "Cloud Platforms, DataOps, Governance & MLOps", "(8–12 weeks)", COLORS.PHASE8),
                new Paragraph({ spacing: { after: 300 } }),

                // 8.1 Google Cloud Platform (GCP)
                createChapterHeader("8.1", "Google Cloud Platform (GCP)", COLORS.PHASE8),
                createBulletBold("Cloud Storage (GCS):", " buckets, object lifecycle, storage classes, gsutil CLI"),
                createBulletBold("BigQuery:", " covered in Phase 7"),
                createBulletBold("Cloud Dataproc:", " managed Spark/Hadoop, autoscaling, initialization actions"),
                createBulletBold("Cloud Dataflow:", " managed Apache Beam, streaming/batch, auto-scaling, templates"),
                createBulletBold("Cloud Pub/Sub:", " covered in Phase 5"),
                createBulletBold("Dataplex:", " data mesh management, data zones, discovery, quality rules"),
                createBulletBold("Cloud Composer:", " managed Airflow on GKE"),
                createBulletBold("Cloud Data Fusion:", " visual ETL/ELT, code-free pipeline builder (CDAP-based)"),
                createBulletBold("Datastream:", " serverless CDC from MySQL/PostgreSQL/Oracle to BigQuery/GCS"),
                createBulletBold("Cloud Functions / Cloud Run:", " serverless compute for event-driven processing"),
                createBulletBold("Vertex AI:", " managed ML platform, feature store, model deployment"),
                createBullet("IAM: service accounts, roles, permissions, organization policies"),

                // 8.2 Amazon Web Services (AWS)
                createChapterHeader("8.2", "Amazon Web Services (AWS)", COLORS.PHASE8),
                createBulletBold("S3:", " buckets, storage classes, lifecycle policies, S3 Select, Event Notifications"),
                createBulletBold("AWS Glue:", " serverless ETL, Crawlers, Data Catalog, Spark jobs, Glue Studio"),
                createBulletBold("EMR:", " managed Spark/Hadoop/Flink/Hive, EMR on EKS, EMR Serverless"),
                createBulletBold("Kinesis:", " covered in Phase 5"),
                createBulletBold("Redshift:", " covered in Phase 7"),
                createBulletBold("Lambda:", " serverless functions, event-driven processing, Step Functions"),
                createBulletBold("Athena:", " serverless Presto/Trino on S3, pay-per-query"),
                createBulletBold("Lake Formation:", " data lake setup, fine-grained access control, governed tables"),
                createBulletBold("DynamoDB:", " serverless NoSQL, streams for CDC, global tables"),
                createBulletBold("MSK:", " managed Apache Kafka"),
                createBulletBold("SageMaker:", " ML model training, deployment, feature store"),

                // 8.3 Microsoft Azure
                createChapterHeader("8.3", "Microsoft Azure", COLORS.PHASE8),
                createBulletBold("ADLS Gen2:", " hierarchical namespace, data lake storage (Blob + HNS)"),
                createBulletBold("Azure Data Factory:", " visual ETL/ELT, copy activity, data flows, pipelines"),
                createBulletBold("Synapse Analytics:", " dedicated SQL pools, Spark pools, serverless SQL"),
                createBulletBold("Azure Databricks:", " managed Spark, Unity Catalog, Delta Lake integration"),
                createBulletBold("Event Hubs:", " managed Kafka-compatible event streaming"),
                createBulletBold("Stream Analytics:", " real-time stream processing with SQL"),
                createBulletBold("Cosmos DB:", " multi-model globally-distributed NoSQL"),
                createBulletBold("Microsoft Purview:", " data governance, cataloging, lineage"),

                new Paragraph({ children: [new PageBreak()] }),

                // 8.4 Infrastructure as Code (IaC)
                createChapterHeader("8.4", "Infrastructure as Code (IaC)", COLORS.PHASE8),
                createBullet("Terraform: providers (AWS/GCP/Azure), resources, state management, modules"),
                createBullet("Terraform for data infra: BigQuery datasets, S3 buckets, EMR clusters, Kafka topics"),
                createBullet("Pulumi: IaC in Python/TypeScript/Go"),
                createBullet("CloudFormation (AWS) / Deployment Manager (GCP)"),
                createBullet("Ansible: configuration management, playbooks for server setup"),

                // 8.5 Docker & Kubernetes
                createChapterHeader("8.5", "Docker & Kubernetes", COLORS.PHASE8),
                
                createSubHeader("Docker"),
                createBullet("Dockerfile, images, containers, volumes, networks, docker-compose"),
                createBullet("Docker for data engineering: containerized Spark, Airflow, Kafka development"),
                createBullet("Multi-stage builds, image optimization"),

                createSubHeader("Kubernetes"),
                createBullet("Pods, Deployments, Services, ConfigMaps, Secrets, Namespaces"),
                createBullet("Kubernetes for data: SparkOnK8s, Airflow KubernetesExecutor, Strimzi (Kafka on K8s)"),
                createBullet("Helm charts (Airflow Helm, Spark operator)"),
                createBullet("Container registries: Docker Hub, GCR, ECR, ACR"),

                // 8.6 Data Quality Tools
                createChapterHeader("8.6", "Data Quality Tools", COLORS.PHASE8),
                createBullet("Great Expectations: expectations, validation, data docs, checkpoints, profiling"),
                createBullet("Soda: SodaCL checks, Soda Cloud, Soda Core, Airflow integration"),
                createBullet("AWS Deequ: constraint verification, anomaly detection on Spark DataFrames"),
                createBullet("dbt Tests: schema tests (unique, not_null, accepted_values, relationships), custom tests"),
                createBullet("Monte Carlo / Elementary: data observability, anomaly detection, freshness monitoring"),
                createBullet("Data quality dimensions: accuracy, completeness, consistency, timeliness, uniqueness, validity"),

                // 8.7 Data Governance & Cataloging
                createChapterHeader("8.7", "Data Governance & Cataloging", COLORS.PHASE8),
                
                createSubHeader("Governance Pillars"),
                createBullet("Ownership, stewardship, policies, standards, compliance"),

                createSubHeader("Data Cataloging"),
                createBullet("Apache Atlas, Amundsen, DataHub, OpenMetadata"),
                createBullet("Data lineage: tracking data flow, impact analysis"),

                createSubHeader("Dataplex (GCP)"),
                createBullet("Data mesh-style governance, data quality rules, data zones"),

                createSubHeader("Privacy & Compliance"),
                createBullet("PII handling: masking, tokenization, anonymization, pseudonymization"),
                createBullet("Regulations: GDPR, CCPA, HIPAA compliance requirements"),
                createBullet("Data contracts: schema agreements between producers & consumers"),
                createBullet("Access control: RBAC, ABAC, column-level, row-level security"),

                new Paragraph({ children: [new PageBreak()] }),

                // 8.8 dbt (Data Build Tool)
                createChapterHeader("8.8", "dbt (Data Build Tool)", COLORS.PHASE8),
                
                createSubHeader("Core Concepts"),
                createBullet("Models (SQL SELECT), refs, sources, seeds, snapshots"),
                createBullet("Project structure: models/, macros/, seeds/, tests/, snapshots/"),
                createBullet("Materializations: view, table, incremental, ephemeral"),

                createSubHeader("Advanced"),
                createBullet("Jinja templating: macros, control structures, ref(), source()"),
                createBullet("Testing: schema tests, data tests, custom generic tests"),
                createBullet("Documentation: doc blocks, generated documentation site"),
                createBullet("Packages: dbt-utils, dbt-expectations, packages.yml"),
                createBullet("dbt Cloud vs dbt Core (managed IDE vs CLI)"),
                createBullet("Orchestration integration: dbt with Airflow / Dagster / Prefect"),

                // 8.9 CI/CD for Data Pipelines
                createChapterHeader("8.9", "CI/CD for Data Pipelines", COLORS.PHASE8),
                createBullet("Version control: DAGs, SQL, schemas, configs in Git"),
                createBullet("Testing strategies: unit tests (dbt/pytest), integration tests, data validation"),
                createBullet("CI/CD tools: GitHub Actions, GitLab CI, Jenkins, CircleCI"),
                createBullet("Environment management: dev, staging, production data environments"),
                createBullet("Blue-green deployments for data pipelines"),
                createBullet("Schema migration tools: Flyway, Alembic, Liquibase"),
                createBullet("Feature flags for gradual rollout of pipeline changes"),
                createBullet("Monitoring & alerting: Prometheus, Grafana, PagerDuty, Datadog"),

                // 8.10 Data Architecture Patterns
                createChapterHeader("8.10", "Data Architecture Patterns", COLORS.PHASE8),
                createBullet("Data Mesh: domain-oriented ownership, data as a product, self-serve platform, federated governance"),
                createBullet("Data Lakehouse: combining data lake + warehouse, open table formats"),
                createBullet("Medallion Architecture: Bronze (raw) → Silver (cleansed) → Gold (aggregated)"),
                createBullet("Lambda Architecture: batch + speed layers, serving layer"),
                createBullet("Kappa Architecture: streaming-only (simplification of Lambda)"),
                createBullet("Event-Driven Architecture: events as first-class citizens"),
                createBullet("Reverse ETL: syncing warehouse data back to operational systems (Census, Hightouch)"),

                // 8.11 MLOps Fundamentals
                createChapterHeader("8.11", "MLOps Fundamentals (for Data Engineers)", COLORS.PHASE8),
                createBullet("ML pipeline stages: data collection, feature engineering, training, validation, deployment, monitoring"),
                createBullet("Feature Stores: Feast, Tecton, Vertex AI Feature Store, Hopsworks"),
                createBullet("Experiment Tracking: MLflow, Weights & Biases, Neptune.ai"),
                createBullet("Model Registries: MLflow Model Registry, SageMaker Model Registry"),
                createBullet("Model Serving: TensorFlow Serving, Seldon Core, BentoML, KServe"),
                createBullet("Data Versioning: DVC (Data Version Control), LakeFS"),
                createBullet("Data engineers build the infrastructure and pipelines that support ML workflows"),

                new Paragraph({ children: [new PageBreak()] }),

                // 8.12 Capstone Projects
                createChapterHeader("8.12", "Capstone Projects", COLORS.PHASE8),
                createBulletBold("Project 1:", " End-to-end batch pipeline (CSV/API → Spark → BigQuery, orchestrated by Airflow, Great Expectations quality checks)"),
                createBulletBold("Project 2:", " Real-time streaming (Kafka + Debezium CDC from PostgreSQL → Spark Structured Streaming → Delta Lake → Grafana dashboard)"),
                createBulletBold("Project 3:", " Data Lakehouse (S3/GCS raw zone, Bronze-Silver-Gold Medallion, dbt transforms, Iceberg table format, Trino federated queries)"),
                createBulletBold("Project 4:", " Cloud-native GCP pipeline (Pub/Sub + Dataflow + BigQuery + Dataplex governance + Cloud Composer orchestration)"),
                createBulletBold("Project 5:", " Data Mesh prototype (domain-owned datasets, data contracts, self-serve platform, DataHub catalog)"),

                new Paragraph({ children: [new PageBreak()] }),

                // ========== ADDITIONAL RESOURCES ==========
                new Paragraph({
                    children: [new TextRun({ text: "Additional Resources & Learning Tips", bold: true, size: 32, color: COLORS.TITLE_BLUE, font: "Arial" })],
                    spacing: { after: 300 },
                }),

                createSubHeader("File Formats Quick Reference"),
                createBulletBold("CSV/TSV:", " simple text, universal support, no schema, no compression"),
                createBulletBold("JSON/JSONL:", " semi-structured, human-readable, verbose, line-delimited for streaming"),
                createBulletBold("Avro:", " row-based binary, schema evolution, compact, Kafka-optimized"),
                createBulletBold("Parquet:", " columnar binary, excellent compression, predicate pushdown, analytics-optimized"),
                createBulletBold("ORC:", " columnar binary, Hive ecosystem, ACID support, lightweight indexing"),
                createBulletBold("Protocol Buffers:", " Google's binary serialization, language-neutral, Schema Registry support"),

                createSubHeader("Compression Codecs"),
                createBulletBold("Snappy:", " fast compress/decompress, moderate ratio, Spark default"),
                createBulletBold("Gzip:", " high compression ratio, slower, NOT splittable"),
                createBulletBold("LZO:", " splittable (with index), fast, Hadoop-optimized"),
                createBulletBold("Zstandard (zstd):", " excellent ratio + speed, modern choice, tunable compression level"),
                createBulletBold("Brotli:", " very high compression, slower, web-optimized"),

                createSubHeader("Learning Path Tips"),
                createBullet("Follow the phase sequence – each phase builds on the previous one"),
                createBullet("Build hands-on projects at every phase (theory alone is insufficient)"),
                createBullet("Practice SQL daily – it is the most-used skill in data engineering"),
                createBullet("Read original papers: Google's GFS, MapReduce, Bigtable, Dremel papers are foundational"),
                createBullet("Join communities: r/dataengineering, dbt Slack, Apache mailing lists, Data Engineering Weekly"),
                createBullet("Use cloud free tiers: GCP $300 credit, AWS Free Tier, Azure $200 credit"),
                createBullet("Build a portfolio: GitHub repos with well-documented data projects"),
                createBullet("Contribute to open-source data tools for learning and networking"),

                createSubHeader("Key Job Requirement Technologies (Quick Map)"),
                createBulletBold("PySpark:", " Phase 4 (4.3)"),
                createBulletBold("GCP Stack:", " Phase 8 (8.1) + BigQuery in Phase 7"),
                createBulletBold("Advanced SQL:", " Phase 2 (2.2–2.3)"),
                createBulletBold("NoSQL / MongoDB:", " Phase 7 (7.1)"),
                createBulletBold("Scala & Python:", " Phase 1 (1.5–1.6)"),
                createBulletBold("Data Quality Tools:", " Phase 8 (8.6)"),
                createBulletBold("Airflow / Prefect / Luigi:", " Phase 6 (6.2–6.4)"),
                createBulletBold("Data Governance:", " Phase 8 (8.7)"),
                createBulletBold("DWH & Data Modeling:", " Phase 7 (7.6–7.7)"),
            ],
        },
    ],
});

// Generate and save the document
Packer.toBuffer(doc).then(buffer => {
    fs.writeFileSync("/Users/imrulhasan/DWH/DataMarts/GitDirectory/Data-Engineering-Playground/Data_Engineering_Complete_Syllabus_2025.docx", buffer);
    
    console.log("Document created successfully!");
});

