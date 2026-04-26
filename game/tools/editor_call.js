#!/usr/bin/env node
/**
 * editor_call.js — Godot Editor Remote Executor (Node.js 版 · 备选)
 *
 * 主推方案：python tools/editor_call.py（Python 3.12）
 * 本文件仅在 Python 不可用时作为 fallback。
 *
 * 与 Python 版功能完全一致：
 * - 自动获取 executor_id
 * - 用 \t 缩进编写 GDScript（避免空格陷阱）
 * - 正确处理 executeContext.output 数组格式
 * - 清晰的错误处理
 *
 * 用法:
 *   node editor_call.js 'print("hello")'          # 直接执行代码
 *   node editor_call.js --file script.gd           # 从文件执行
 *   node editor_call.js --executors                # 列出已连接编辑器
 *   node editor_call.js --health                   # 健康检查
 *   node editor_call.js --scene-tree               # 获取场景树
 */

const BASE_URL = "http://localhost:5302/api";
const AUTH_TOKEN = "995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7";

const http = require("http");
const fs = require("fs");
const path = require("path");

function apiCall(endpoint, method = "GET", body = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: "localhost",
      port: 5302,
      path: `/api${endpoint}`,
      method,
      headers: {
        Authorization: `Bearer ${AUTH_TOKEN}`,
      },
    };
    if (body) {
      options.headers["Content-Type"] = "application/json";
    }
    const req = http.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        try {
          resolve(JSON.parse(data));
        } catch {
          reject(new Error(`Invalid JSON: ${data}`));
        }
      });
    });
    req.on("error", reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function getFirstExecutorId() {
  const data = await apiCall("/executors");
  if (data.success && Array.isArray(data.data) && data.data.length > 0) {
    return data.data[0].id;
  }
  return null;
}

async function execute(code, executorId = null) {
  if (!executorId) {
    executorId = await getFirstExecutorId();
    if (!executorId) {
      console.error("[ERROR] No Godot editor connected. Start broker-server and enable plugin.");
      process.exit(1);
    }
  }
  return apiCall("/execute", "POST", { code, executor_id: executorId, timeout_ms: 30000 });
}

function formatOutput(outputs) {
  for (const out of outputs) {
    const key = out[0];
    const val = out[1];
    console.log(`  ${key} = ${val}`);
  }
}

async function main() {
  const args = process.argv.slice(2);
  if (args.length === 0) {
    showHelp();
    return;
  }

  const cmd = args[0];

  switch (cmd) {
    case "--executors": {
      const data = await apiCall("/executors");
      if (data.success) {
        for (const ed of data.data || []) {
          console.log(`  ID: ${ed.id}`);
          console.log(`  Project: ${ed.project_name || "N/A"}`);
          console.log(`  PID: ${ed.editor_pid || "N/A"}`);
          console.log(`  Status: ${ed.status || "N/A"}`);
          console.log();
        }
      } else {
        console.error(`[ERROR] ${JSON.stringify(data)}`);
      }
      break;
    }

    case "--health": {
      const data = await apiCall("/health");
      console.log(JSON.stringify(data, null, 2));
      break;
    }

    case "--scene-tree": {
      const data = await apiCall("/scene/tree");
      console.log(JSON.stringify(data, null, 2));
      break;
    }

    case "--file": {
      if (args.length < 2) {
        console.error("[ERROR] Usage: node editor_call.js --file <path>");
        process.exit(1);
      }
      const code = fs.readFileSync(args[1], "utf8");
      const result = await execute(code);
      printResult(result);
      break;
    }

    default: {
      const code = args.join(" ");
      const result = await execute(code);
      printResult(result);
    }
  }
}

function printResult(result) {
  if (!result) return;
  const data = result.data || {};

  if (!data.compile_success) {
    console.error(`[COMPILE ERROR] ${data.compile_error || "Unknown"}`);
    process.exit(1);
  }

  if (!data.run_success) {
    console.error(`[RUN ERROR] ${data.run_error || "Unknown"}`);
    process.exit(1);
  }

  console.log("[SUCCESS]");
  const outputs = data.outputs || [];
  if (outputs.length > 0) {
    formatOutput(outputs);
  }
}

function showHelp() {
  console.log(`
Godot Editor Remote Executor — 标准调用脚本

用法:
    node editor_call.js <gdscript_code>
    node editor_call.js --file <path_to_script.gd>
    node editor_call.js --executors    # 仅列出已连接编辑器
    node editor_call.js --health       # 健康检查
    node editor_call.js --scene-tree   # 获取场景树

示例:
    node editor_call.js 'print("hello")'
    node editor_call.js --executors

注意: GDScript 缩进必须用 Tab(\\t)，不能用空格
  `);
}

main().catch((err) => {
  console.error(`[ERROR] ${err.message}`);
  process.exit(1);
});
