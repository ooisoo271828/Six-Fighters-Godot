import urllib.request
import json
import sys

"""
Godot Editor Remote Executor — 标准调用脚本

用法：
    python editor_call.py <gdscript_code>
    python editor_call.py --file <path_to_script.gd>
    python editor_call.py --executors    # 仅列出已连接编辑器
    python editor_call.py --health       # 健康检查
    python editor_call.py --scene-tree   # 获取场景树

示例：
    python editor_call.py 'print("hello")'
    python editor_call.py --executors
"""

BASE_URL = "http://localhost:5302/api"
AUTH_TOKEN = "995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7"
HEADERS = {
    "Authorization": f"Bearer {AUTH_TOKEN}",
    "Content-Type": "application/json"
}

def get_executors():
    """获取已连接编辑器列表"""
    req = urllib.request.Request(f"{BASE_URL}/executors", headers=HEADERS)
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))

def get_first_executor_id():
    """获取第一个已连接编辑器的 executor_id"""
    data = get_executors()
    if data.get("success") and data.get("data"):
        return data["data"][0]["id"]
    return None

def execute(code, executor_id=None):
    """在 Godot 编辑器中执行 GDScript 代码"""
    if executor_id is None:
        executor_id = get_first_executor_id()
        if executor_id is None:
            print("[ERROR] No Godot editor connected. Start broker-server and enable plugin.", file=sys.stderr)
            return None

    body = json.dumps({"code": code, "executor_id": executor_id}).encode("utf-8")
    req = urllib.request.Request(
        f"{BASE_URL}/execute",
        data=body,
        headers=HEADERS,
        method="POST"
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))

def format_output(outputs):
    """格式化 executeContext.output 的输出"""
    for out in outputs:
        key = out[0] if isinstance(out, list) else out
        val = out[1] if isinstance(out, list) else outputs[out]
        print(f"  {key} = {val}")

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    if sys.argv[1] == "--executors":
        data = get_executors()
        if data.get("success"):
            for ed in data.get("data", []):
                print(f"  ID: {ed['id']}")
                print(f"  Project: {ed.get('project_name', 'N/A')}")
                print(f"  PID: {ed.get('editor_pid', 'N/A')}")
                print(f"  Status: {ed.get('status', 'N/A')}")
                print()
        else:
            print(f"[ERROR] {data}")
        return

    if sys.argv[1] == "--health":
        req = urllib.request.Request(f"{BASE_URL}/health")
        with urllib.request.urlopen(req) as resp:
            print(resp.read().decode("utf-8"))
        return

    if sys.argv[1] == "--scene-tree":
        req = urllib.request.Request(f"{BASE_URL}/scene/tree", headers=HEADERS)
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            print(json.dumps(data, indent=2, ensure_ascii=False))
        return

    if sys.argv[1] == "--file" and len(sys.argv) >= 3:
        with open(sys.argv[2], encoding="utf-8") as f:
            code = f.read()
    else:
        code = " ".join(sys.argv[1:])

    print(f"[Executing GDScript...]")
    result = execute(code)

    if result is None:
        return

    data = result.get("data", {})

    if not data.get("compile_success"):
        print(f"[COMPILE ERROR] {data.get('compile_error', 'Unknown')}", file=sys.stderr)
        sys.exit(1)

    if not data.get("run_success"):
        print(f"[RUN ERROR] {data.get('run_error', 'Unknown')}", file=sys.stderr)
        sys.exit(1)

    print("[SUCCESS]")
    outputs = data.get("outputs", [])
    if outputs:
        format_output(outputs)

if __name__ == "__main__":
    main()
