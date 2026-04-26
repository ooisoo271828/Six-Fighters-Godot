#!/usr/bin/env python3
"""
Hastur CLI — AI-assistant helper for Godot remote execution

Usage:
  python hastur.py health              — Check broker health
  python hastur.py executors           — List connected executors
  python hastur.py exec '<code>'       — Execute GDScript code
  python hastur.py scene-tree          — Get current scene tree
  python hastur.py create-node <name> <type> [parent_path] — Create a node
  python hastur.py delete-node <path>  — Delete a node
  python hastur.py logs [limit]        — Get executor logs
  python hastur.py start               — Start the broker-server
  python hastur.py stop                — Stop the broker-server
  python hastur.py restart             — Restart the broker-server
  python hastur.py status              — Full status overview
"""

import json
import os
import subprocess
import sys
import time
import urllib.request
import urllib.error

TOKEN = os.environ.get("HASTUR_TOKEN", "995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7")
HOST = os.environ.get("HASTUR_HOST", "localhost")
PORT = os.environ.get("HASTUR_PORT", "5302")
BROKER_DIR = "/e/VibeCoding/hastur-operation-plugin-main/broker-server"
PROJECT_NAME = "Six Fighter"
BASE_URL = f"http://{HOST}:{PORT}/api"
HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
}


# ── HTTP helpers ──────────────────────────────────────────────────────────────


def api(method, endpoint, body=None):
    url = f"{BASE_URL}{endpoint}"
    data = json.dumps(body).encode("utf-8") if body else None
    req = urllib.request.Request(url, data=data, headers=HEADERS, method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        return {"error": f"HTTP {e.code}", "detail": e.read().decode("utf-8", errors="replace")}
    except Exception as e:
        return {"error": str(e)}


def api_raw(method, endpoint):
    """Returns raw text response (e.g., for health check without auth)."""
    url = f"{BASE_URL}{endpoint}"
    req = urllib.request.Request(url, method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.read().decode("utf-8")
    except Exception as e:
        return json.dumps({"error": str(e)})


def find_executor_id():
    resp = api("GET", "/executors")
    items = resp.get("data") or resp.get("executors") or []
    if isinstance(items, list) and len(items) > 0:
        return items[0].get("id", "")
    return ""


# ── Commands ──────────────────────────────────────────────────────────────────


def cmd_health():
    print("== Health Check ==")
    raw = api_raw("GET", "/health")
    try:
        parsed = json.loads(raw)
        print(json.dumps(parsed, indent=2, ensure_ascii=False))
    except json.JSONDecodeError:
        print(raw)


def cmd_executors():
    print("== Connected Executors ==")
    resp = api("GET", "/executors")
    print(json.dumps(resp, indent=2, ensure_ascii=False))


def cmd_exec(code):
    if not code:
        print("[ERROR] Code is required")
        print("Usage: hastur.py exec 'print(42)'")
        sys.exit(1)

    eid = find_executor_id()
    print(">> Executing GDScript...")
    print(f"  Code: {code}")

    body = {"code": code, "timeout_ms": 30000}
    if eid:
        body["executor_id"] = eid
    else:
        body["project_name"] = PROJECT_NAME

    resp = api("POST", "/execute", body)
    print(json.dumps(resp, indent=2, ensure_ascii=False))


def cmd_scene_tree():
    print("== Scene Tree ==")
    resp = api("GET", "/scene/tree")
    print(json.dumps(resp, indent=2, ensure_ascii=False))


def cmd_create_node(name, node_type="Node", parent_path=None):
    if not name:
        print("[ERROR] node name is required")
        print("Usage: hastur.py create-node <name> <type> [parent_path]")
        sys.exit(1)

    print(f"++ Creating node: {name} ({node_type})")
    body = {"name": name, "type": node_type}
    if parent_path:
        body["parent_path"] = parent_path

    resp = api("POST", "/scene/nodes", body)
    print(json.dumps(resp, indent=2, ensure_ascii=False))


def cmd_delete_node(path):
    if not path:
        print("[ERROR] node path is required")
        print("Usage: hastur.py delete-node <path>")
        sys.exit(1)

    print(f"-- Deleting node: {path}")
    resp = api("DELETE", f"/scene/nodes?path={path}")
    print(json.dumps(resp, indent=2, ensure_ascii=False))


def cmd_logs(limit=20):
    eid = find_executor_id()
    if not eid:
        print("[WARN] No executor connected.")
        return

    print(f"== Logs (last {limit}) ==")
    resp = api("GET", f"/executors/{eid}/logs?limit={limit}")
    print(json.dumps(resp, indent=2, ensure_ascii=False))


def cmd_start():
    # Check if already running
    try:
        health = api_raw("GET", "/health")
        if json.loads(health).get("success"):
            print("[WARN] Broker-server is already running.")
            return
    except Exception:
        pass

    print(">> Starting broker-server...")
    log_file = "/tmp/hastur-broker.log"
    with open(log_file, "w") as f:
        proc = subprocess.Popen(
            ["npx", "tsx", "src/index.ts", "--auth-token", TOKEN],
            cwd=BROKER_DIR,
            stdout=f,
            stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL,
        )

    print(f"[OK] Started (PID: {proc.pid})")
    print(f"  Logs: {log_file}")

    time.sleep(2)
    for _ in range(10):
        try:
            health = api_raw("GET", "/health")
            if json.loads(health).get("success"):
                print("[OK] Broker is ready.")
                return
        except Exception:
            pass
        time.sleep(1)
    print("[WARN] Broker may not have started in time. Check logs.")


def cmd_stop():
    print(">> Stopping broker-server...")
    try:
        result = subprocess.run(
            ["ps", "aux"], capture_output=True, text=True, timeout=5
        )
        for line in result.stdout.split("\n"):
            if "tsx src/index.ts" in line and "--auth-token" in line:
                parts = line.split()
                pid = parts[1] if len(parts) > 1 else ""
                if pid:
                    subprocess.run(["kill", pid], capture_output=True)
                    print(f"[OK] Stopped (PID: {pid})")
                    return
        print("[WARN] No broker-server process found.")
    except Exception as e:
        print(f"[WARN] Could not stop broker: {e}")


def cmd_restart():
    cmd_stop()
    time.sleep(1)
    cmd_start()


def cmd_status():
    print("== Six Fighter - Hastur Plugin Status ==")
    print()

    # Broker health
    broker_ok = False
    try:
        raw = api_raw("GET", "/health")
        health = json.loads(raw)
        broker_ok = health.get("success", False)
    except Exception:
        pass

    if broker_ok:
        ver = (health.get("data", {}) or {}).get("version", "?")
        count = (health.get("data", {}) or {}).get("executors_connected", 0)
        print(f"  [OK] Broker: running ({HOST}:{PORT})")
        print(f"  - Version: {ver}")
        print(f"  - Executors connected: {count}")
    else:
        print(f"  [FAIL] Broker: not running")

    # Executor status
    exec_resp = api("GET", "/executors")
    items = exec_resp.get("data") or exec_resp.get("executors") or []

    if isinstance(items, list) and len(items) > 0:
        print(f"  [OK] Godot Editor: connected")
        for ex in items:
            print(f"     ID:      {ex.get('id', '?')}")
            print(f"     Project: {ex.get('project_name', '?')}")
            godot_ver = ex.get("editor_version", "")
            if godot_ver:
                print(f"     Godot:   {godot_ver}")
    else:
        print(f"  [FAIL] Godot Editor: not connected")
        print(f"     (Open the project in Godot 4.x Editor and enable the HasturOperationGD plugin)")

    print()
    print("Quick actions:")
    print("  python tools/hastur.py exec 'print(\"hello\")'")
    print("  python tools/hastur.py scene-tree")
    print("  python tools/hastur.py executors")


# ── Main ──────────────────────────────────────────────────────────────────────


def main():
    if len(sys.argv) < 2:
        cmd_status()
        return

    cmd = sys.argv[1]
    args = sys.argv[2:]

    commands = {
        "health": cmd_health,
        "status": cmd_status,
        "executors": cmd_executors,
        "exec": lambda: cmd_exec(" ".join(args)),
        "scene-tree": cmd_scene_tree,
        "scene_tree": cmd_scene_tree,
        "tree": cmd_scene_tree,
        "create-node": lambda: cmd_create_node(*args),
        "create_node": lambda: cmd_create_node(*args),
        "delete-node": lambda: cmd_delete_node(*args),
        "delete_node": lambda: cmd_delete_node(*args),
        "logs": lambda: cmd_logs(int(args[0]) if args else 20),
        "start": cmd_start,
        "stop": cmd_stop,
        "restart": cmd_restart,
    }

    handler = commands.get(cmd)
    if handler:
        handler()
    else:
        print(f"Unknown command: {cmd}")
        print(__doc__.strip())
        sys.exit(1)


if __name__ == "__main__":
    main()
