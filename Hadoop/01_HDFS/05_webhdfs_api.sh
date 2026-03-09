#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# 05_webhdfs_api.sh — WebHDFS REST API & HttpFS
# Run from host machine (not inside container) — uses curl against port 9870
# WebHDFS endpoint: http://<namenode-host>:9870/webhdfs/v1/<path>?op=<OPERATION>
# ─────────────────────────────────────────────────────────────────────────────

NAMENODE="localhost"
WEBHDFS_PORT="9870"
BASE="http://${NAMENODE}:${WEBHDFS_PORT}/webhdfs/v1"
USER="root"

echo "════════════════════════════════════════════"
echo "  WebHDFS REST API Operations"
echo "  Endpoint: ${BASE}"
echo "════════════════════════════════════════════"

# ── Helper ────────────────────────────────────────────────────────────────────
pretty() { python3 -m json.tool 2>/dev/null || cat; }

# ── 1. LISTSTATUS — List directory ───────────────────────────────────────────
echo -e "\n[1] List root directory (/)"
curl -s "${BASE}/?op=LISTSTATUS&user.name=${USER}" | pretty

# ── 2. MKDIRS — Create directory ─────────────────────────────────────────────
echo -e "\n[2] Create /webhdfs-demo directory"
curl -s -X PUT "${BASE}/webhdfs-demo?op=MKDIRS&user.name=${USER}&permission=755" | pretty

# ── 3. CREATE — Upload a file (two-step redirect) ────────────────────────────
echo -e "\n[3] Upload file via WebHDFS (two-step)"
# Step 3a: Get the redirect URL (DataNode write URL)
REDIRECT=$(curl -s -i -X PUT \
  "${BASE}/webhdfs-demo/hello.txt?op=CREATE&user.name=${USER}&overwrite=true" \
  | grep "^Location:" | tr -d '\r' | awk '{print $2}')

echo "  Redirect URL: ${REDIRECT}"

# Step 3b: Send the file content to the DataNode URL
echo "Hello from WebHDFS REST API" | curl -s -X PUT -T - \
  -H "Content-Type: application/octet-stream" \
  "${REDIRECT}"
echo "  Upload complete"

# ── 4. OPEN — Read a file ────────────────────────────────────────────────────
echo -e "\n[4] Read /webhdfs-demo/hello.txt"
curl -s -L "${BASE}/webhdfs-demo/hello.txt?op=OPEN&user.name=${USER}"

# ── 5. GETFILESTATUS — File metadata ─────────────────────────────────────────
echo -e "\n[5] Get file status (metadata)"
curl -s "${BASE}/webhdfs-demo/hello.txt?op=GETFILESTATUS&user.name=${USER}" | pretty

# ── 6. GETCONTENTSUMMARY — Directory summary ─────────────────────────────────
echo -e "\n[6] Content summary for /webhdfs-demo"
curl -s "${BASE}/webhdfs-demo?op=GETCONTENTSUMMARY&user.name=${USER}" | pretty

# ── 7. RENAME — Rename/move a file ───────────────────────────────────────────
echo -e "\n[7] Rename hello.txt → renamed.txt"
curl -s -X PUT \
  "${BASE}/webhdfs-demo/hello.txt?op=RENAME&destination=/webhdfs-demo/renamed.txt&user.name=${USER}" | pretty

# ── 8. SETREPLICATION — Change replication factor ────────────────────────────
echo -e "\n[8] Set replication factor to 1"
curl -s -X PUT \
  "${BASE}/webhdfs-demo/renamed.txt?op=SETREPLICATION&replication=1&user.name=${USER}" | pretty

# ── 9. SETPERMISSION — Change permissions ────────────────────────────────────
echo -e "\n[9] chmod 644 on renamed.txt"
curl -s -X PUT \
  "${BASE}/webhdfs-demo/renamed.txt?op=SETPERMISSION&permission=644&user.name=${USER}" | pretty

# ── 10. APPEND — Append data to a file ───────────────────────────────────────
echo -e "\n[10] Append to renamed.txt"
APPEND_URL=$(curl -s -i -X POST \
  "${BASE}/webhdfs-demo/renamed.txt?op=APPEND&user.name=${USER}" \
  | grep "^Location:" | tr -d '\r' | awk '{print $2}')
echo " (appended text)" | curl -s -X POST -T - \
  -H "Content-Type: application/octet-stream" \
  "${APPEND_URL}"
echo "  Append complete"

# ── 11. Read back appended content ───────────────────────────────────────────
echo -e "\n[11] Verify appended content"
curl -s -L "${BASE}/webhdfs-demo/renamed.txt?op=OPEN&user.name=${USER}"

# ── 12. DELETE — Delete file ──────────────────────────────────────────────────
echo -e "\n[12] Delete /webhdfs-demo/renamed.txt"
curl -s -X DELETE \
  "${BASE}/webhdfs-demo/renamed.txt?op=DELETE&user.name=${USER}" | pretty

# ── 13. DELETE — Delete directory recursively ────────────────────────────────
echo -e "\n[13] Delete /webhdfs-demo directory (recursive)"
curl -s -X DELETE \
  "${BASE}/webhdfs-demo?op=DELETE&recursive=true&user.name=${USER}" | pretty

# ── 14. GETHOMEDIRECTORY ─────────────────────────────────────────────────────
echo -e "\n[14] Get home directory for user"
curl -s "${BASE}/?op=GETHOMEDIRECTORY&user.name=${USER}" | pretty

# ── 15. LISTSTATUS with path params ──────────────────────────────────────────
echo -e "\n[15] List /user directory"
curl -s "${BASE}/user?op=LISTSTATUS&user.name=${USER}" | pretty

# ─────────────────────────────────────────────────────────────────────────────
# HttpFS (alternative single-endpoint REST gateway)
# HttpFS runs on port 14000 and exposes the same WebHDFS API
# Useful when DataNodes are not directly reachable (e.g., behind a firewall)
#
# Start HttpFS on the NameNode:
#   hdfs --daemon start httpfs
#
# Usage: Same API, different port and different URL format:
#   curl -s "http://<namenode>:14000/webhdfs/v1/?op=LISTSTATUS&user.name=root"
# ─────────────────────────────────────────────────────────────────────────────
echo -e "\n[HttpFS Note]"
echo "HttpFS is an alternative REST gateway (single endpoint, port 14000)."
echo "Start it with: hdfs --daemon start httpfs"
echo "Access it at:  http://${NAMENODE}:14000/webhdfs/v1/?op=LISTSTATUS&user.name=${USER}"

echo -e "\n════════════════════════════════════════════"
echo "  WebHDFS REST API — DONE"
echo "════════════════════════════════════════════"
