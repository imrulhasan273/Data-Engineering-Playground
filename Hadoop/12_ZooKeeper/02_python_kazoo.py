#!/usr/bin/env python3
"""
02_python_kazoo.py — ZooKeeper Python client using Kazoo
Install: pip install kazoo
Run:     python 02_python_kazoo.py
"""

import time
import threading
from kazoo.client import KazooClient
from kazoo.client import KazooState
from kazoo.recipe.lock import Lock
from kazoo.recipe.election import Election
from kazoo.recipe.watchers import DataWatcher, ChildrenWatcher
from kazoo.exceptions import NodeExistsError, NoNodeError

ZK_HOSTS = "localhost:2181"

# ─────────────────────────────────────────────────────────────────────────────
# 1. Connect
# ─────────────────────────────────────────────────────────────────────────────
print("=" * 50)
print("  ZooKeeper Python (Kazoo) Examples")
print("=" * 50)

zk = KazooClient(hosts=ZK_HOSTS)
zk.start()
print(f"\n[1] Connected to ZooKeeper: {ZK_HOSTS}")
print(f"    State: {zk.state}")

# ─────────────────────────────────────────────────────────────────────────────
# 2. Connection state listener
# ─────────────────────────────────────────────────────────────────────────────
def state_listener(state):
    if state == KazooState.LOST:
        print("    [!] ZK session LOST — re-register ephemeral nodes")
    elif state == KazooState.SUSPENDED:
        print("    [!] ZK connection SUSPENDED — stop accepting requests")
    elif state == KazooState.CONNECTED:
        print("    [!] ZK connection RESTORED")

zk.add_listener(state_listener)

# ─────────────────────────────────────────────────────────────────────────────
# 3. Basic CRUD operations
# ─────────────────────────────────────────────────────────────────────────────
print("\n[2] Basic CRUD operations")

# ensure_path: creates node and all parents if they don't exist
zk.ensure_path("/demo/config")
zk.ensure_path("/demo/workers")

# Create a persistent node
try:
    zk.create("/demo/config/db-host", b"db-server.internal")
    print("    Created /demo/config/db-host")
except NodeExistsError:
    print("    /demo/config/db-host already exists")

# Set (overwrite) data
zk.set("/demo/config/db-host", b"db-server-v2.internal")
print("    Updated /demo/config/db-host")

# Get data
data, stat = zk.get("/demo/config/db-host")
print(f"    Get /demo/config/db-host = '{data.decode()}' (version={stat.version})")

# Create multiple config values
configs = {
    "db-port":    b"5432",
    "cache-host": b"redis.internal",
    "cache-port": b"6379",
    "max-conn":   b"100",
}
for key, value in configs.items():
    zk.ensure_path(f"/demo/config/{key}")
    zk.set(f"/demo/config/{key}", value)

# List children
children = zk.get_children("/demo/config")
print(f"    Children of /demo/config: {sorted(children)}")

# Check existence
exists = zk.exists("/demo/config/db-host")
print(f"    Exists /demo/config/db-host: {exists is not None} (czxid={exists.czxid if exists else 'N/A'})")

# Delete
zk.delete("/demo/config/db-port")
print(f"    Deleted /demo/config/db-port")

# ─────────────────────────────────────────────────────────────────────────────
# 4. Ephemeral nodes
# ─────────────────────────────────────────────────────────────────────────────
print("\n[3] Ephemeral nodes (service registration)")

# Register this process as a worker (ephemeral — auto-deleted on disconnect)
worker_path = zk.create(
    "/demo/workers/worker-",
    b'{"host":"10.0.0.1","port":8080,"status":"active"}',
    ephemeral=True,
    sequence=True    # sequential = unique name guaranteed
)
print(f"    Registered worker: {worker_path}")

worker_path2 = zk.create(
    "/demo/workers/worker-",
    b'{"host":"10.0.0.2","port":8080,"status":"active"}',
    ephemeral=True,
    sequence=True
)
print(f"    Registered worker: {worker_path2}")

workers = zk.get_children("/demo/workers")
print(f"    Active workers: {sorted(workers)}")

# ─────────────────────────────────────────────────────────────────────────────
# 5. Watches (event callbacks)
# ─────────────────────────────────────────────────────────────────────────────
print("\n[4] Watches — data change notification")

watch_fired = threading.Event()

@zk.DataWatch("/demo/config/db-host")
def watch_db_host(data, stat, event):
    if event is not None:
        print(f"    [WATCH] /demo/config/db-host changed: event={event.type}, data={data.decode() if data else 'None'}")
        watch_fired.set()

# Trigger the watch
time.sleep(0.2)
zk.set("/demo/config/db-host", b"new-db-server.internal")
watch_fired.wait(timeout=2)

print("\n[5] Watches — children change notification")
children_changed = threading.Event()

@zk.ChildrenWatch("/demo/workers")
def watch_workers(children):
    print(f"    [WATCH] Workers updated: {sorted(children)}")
    children_changed.set()

# Add a new worker to trigger watch
time.sleep(0.2)
new_worker = zk.create(
    "/demo/workers/worker-",
    b'{"host":"10.0.0.3","port":8080}',
    ephemeral=True,
    sequence=True
)
children_changed.wait(timeout=2)

# ─────────────────────────────────────────────────────────────────────────────
# 6. Distributed Lock (Kazoo recipe)
# ─────────────────────────────────────────────────────────────────────────────
print("\n[6] Distributed Lock")

lock = zk.Lock("/demo/locks", identifier="process-A")

results = []

def do_work(name, lock_obj, result_list):
    """Simulate two processes competing for a lock."""
    acquired = lock_obj.acquire(blocking=True, timeout=10)
    if acquired:
        result_list.append(f"{name} acquired lock")
        time.sleep(0.1)  # simulate work
        lock_obj.release()
        result_list.append(f"{name} released lock")

# Use context manager (preferred)
with zk.Lock("/demo/locks", "process-A"):
    print("    process-A holding the lock...")
    time.sleep(0.05)
print("    process-A released lock")

# Simulate concurrent lock contenders
lock_a = zk.Lock("/demo/locks", "thread-A")
lock_b = zk.Lock("/demo/locks", "thread-B")
t1 = threading.Thread(target=do_work, args=("thread-A", lock_a, results))
t2 = threading.Thread(target=do_work, args=("thread-B", lock_b, results))
t1.start(); t2.start()
t1.join(); t2.join()
print(f"    Lock sequence: {results}")

# ─────────────────────────────────────────────────────────────────────────────
# 7. Leader Election (Kazoo recipe)
# ─────────────────────────────────────────────────────────────────────────────
print("\n[7] Leader Election")

elected = threading.Event()
election_results = []

def run_as_leader(name):
    """Called when this instance wins the election."""
    election_results.append(f"{name} is LEADER")
    elected.set()

election_a = Election(zk, "/demo/election", identifier="node-A")
election_b = Election(zk, "/demo/election", identifier="node-B")
election_c = Election(zk, "/demo/election", identifier="node-C")

# Run elections in background threads
for node, election in [("node-A", election_a), ("node-B", election_b), ("node-C", election_c)]:
    n = node  # capture
    e = election
    t = threading.Thread(
        target=lambda name=n, elec=e: elec.run(lambda: run_as_leader(name)),
        daemon=True
    )
    t.start()

elected.wait(timeout=5)
print(f"    Election result: {election_results}")

# ─────────────────────────────────────────────────────────────────────────────
# 8. Distributed configuration management
# ─────────────────────────────────────────────────────────────────────────────
print("\n[8] Distributed Configuration Management")

class DistributedConfig:
    """Config that auto-updates when ZK node changes."""

    def __init__(self, zk_client, config_path):
        self.zk = zk_client
        self.path = config_path
        self._config = {}
        self._load()

    def _load(self):
        children = self.zk.get_children(self.path)
        for key in children:
            data, _ = self.zk.get(f"{self.path}/{key}")
            self._config[key] = data.decode()

    def get(self, key, default=None):
        return self._config.get(key, default)

    def watch_and_reload(self):
        """Set a watch to reload on any child change."""
        @self.zk.ChildrenWatch(self.path)
        def on_change(children):
            self._load()
            print(f"    [CONFIG] Reloaded config: {self._config}")

cfg = DistributedConfig(zk, "/demo/config")
print(f"    Config loaded: db-host={cfg.get('db-host')}, max-conn={cfg.get('max-conn')}")
cfg.watch_and_reload()

# Simulate config update from another process
time.sleep(0.1)
zk.set("/demo/config/max-conn", b"200")
time.sleep(0.3)
print(f"    Config after update: max-conn={cfg.get('max-conn')}")

# ─────────────────────────────────────────────────────────────────────────────
# 9. Barrier (synchronization primitive)
# ─────────────────────────────────────────────────────────────────────────────
print("\n[9] Barrier (synchronize N processes)")

from kazoo.recipe.barrier import Barrier, DoubleBarrier

# Double barrier: wait for N participants to enter, then all proceed together
barrier = DoubleBarrier(zk, "/demo/barrier", num_clients=2)

def participant(name, barrier_obj):
    print(f"    {name} entering barrier...")
    barrier_obj.enter()
    print(f"    {name} passed barrier — doing work")
    time.sleep(0.1)
    barrier_obj.leave()
    print(f"    {name} left barrier")

t1 = threading.Thread(target=participant, args=("Process-1", barrier))
t2 = threading.Thread(target=participant, args=("Process-2", DoubleBarrier(zk, "/demo/barrier", num_clients=2)))
t1.start(); t2.start()
t1.join(); t2.join()

# ─────────────────────────────────────────────────────────────────────────────
# Cleanup and disconnect
# ─────────────────────────────────────────────────────────────────────────────
print("\n[Cleanup]")
try:
    zk.delete("/demo", recursive=True)
    print("    Cleaned up /demo")
except NoNodeError:
    pass

zk.stop()
zk.close()
print("    Disconnected from ZooKeeper")

print("\n" + "=" * 50)
print("  ZooKeeper Kazoo Examples — DONE")
print("=" * 50)
