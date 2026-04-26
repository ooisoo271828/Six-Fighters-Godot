[中文文档](README.zh.md)

# Hastur Operation Plugin

A Godot editor plugin that lets you remotely execute arbitrary GDScript code snippets via an HTTP API.

Yes, you read that correctly. Arbitrary code. Over HTTP. On purpose this time.

## What Problem Does This Solve?

Coding agents are frighteningly good at executing shell commands. They can `npm install`, `git commit`, `docker compose up`, and generally wreak productive havoc across your filesystem — all from the comfort of a terminal.

But a Godot editor? That's a GUI application. You can't exactly `curl` your way into rearranging scene nodes. Until now.

This plugin gives coding agents a "shell" into the Godot editor. Through a simple REST API, an agent can:

- Inspect and manipulate the scene tree
- Create, modify, or delete nodes
- Query and change project settings
- Run editor operations
- Basically anything you could do by typing GDScript into the editor's script panel

Think of it as giving your AI assistant a Godot-sized screwdriver.

## How It Works

The architecture is straightforward — a three-part relay:

```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────────┐
│   Coding Agent  │  HTTP   │  Broker Server   │   TCP   │  Godot Editor       │
│  (opencode,     │ ──────> │  (Node.js/Express│ ──────> │  (Hastur Executor   │
│   Claude, etc.) │ <────── │   + TCP relay)   │ <────── │   Plugin)           │
└─────────────────┘         └─────────────────┘         └─────────────────────┘
```

1. **Coding Agent** sends a `POST /api/execute` request containing GDScript code and an auth token.
2. **Broker Server** authenticates the request, locates the target editor via TCP, and relays the code.
3. **Hastur Executor Plugin** (running inside the Godot editor) receives the code, compiles and executes it, then returns the result back through the same pipe.

The broker server exists because Godot's built-in HTTP client capabilities are... modest, and having a proper HTTP server with Bearer token authentication is a reasonable security boundary between "the internet" and "arbitrary code execution inside your game editor."

## Project Structure

```
hastur-operation-plugin/
├── addons/
│   └── hasturoperationgd/          # The Godot plugin (copy this to your project)
│       ├── plugin.cfg               # Plugin manifest
│       ├── hasturoperationgd.gd     # Entry point — EditorPlugin
│       ├── executor_backend.gd      # Backend orchestrator (local + remote execution)
│       ├── gdscript_executor.gd     # Compiles and runs GDScript snippets
│       ├── execution_context.gd     # Output collector for execution results
│       ├── broker_client.gd         # TCP client connecting to the broker server
│       ├── executor_dock.gd         # Dock UI for the editor panel
│       └── hastur_operation_gd_plugin_settings.gd  # Project settings
│
├── broker-server/                   # The relay server (Node.js)
│   ├── src/
│   │   ├── index.ts                 # CLI entry point (commander)
│   │   ├── http-server.ts           # Express HTTP API (auth, execute, executors)
│   │   ├── tcp-server.ts            # TCP relay to Godot plugin instances
│   │   ├── executor-manager.ts      # Tracks connected editor instances
│   │   ├── auth.ts                  # Bearer token authentication middleware
│   │   └── types.ts                 # Shared TypeScript interfaces
│   └── package.json
│
└── .claude/skills/
    └── godot-remote-executor/       # Skill definition for coding agents
        └── SKILL.md                 # Instructions for agent-driven Godot control
```

## Getting Started

### Prerequisites

- [Godot 4.x](https://godotengine.org/) (tested with 4.6+)
- [Node.js](https://nodejs.org/) 18+ (for the broker server)
- A coding agent that supports loading custom skills (e.g., opencode, Claude)

### Step 1: Start the Broker Server

```bash
cd broker-server
npm install
npm run dev
```

This starts the broker server on `localhost:5302` (HTTP) and `localhost:5301` (TCP) with a default auth token. The token will be printed to stdout — you'll need it shortly.

You can also configure ports and auth token manually:

```bash
npx tsx src/index.ts --http-port 8080 --tcp-port 8081 --auth-token your-secret-token
```

### Step 2: Install the Plugin in Godot

Copy the `addons/hasturoperationgd/` folder into your Godot project's `addons/` directory, then enable the plugin in **Project → Project Settings → Plugins**.

The plugin will automatically try to connect to the broker server at the configured host and port (defaults to `localhost:5301`). You can change these in **Project Settings → Hastur Operation GD**.

Once connected, the editor dock panel will show a green connection status. If it doesn't, check that the broker server is running.

### Step 3: Give Your Coding Agent the Keys

Load the `godot-remote-executor` skill in your coding agent and provide:

1. **Auth token** — the token printed when the broker server started.
2. **Base URL** — defaults to `http://localhost:5302`.

Your agent can now discover connected editors and execute GDScript code on them. For example:

```bash
# List connected editors
curl -s -H "Authorization: Bearer <token>" http://localhost:5302/api/executors

# Execute code
curl -s -X POST \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"code": "print(\"hello from the other side\")", "project_name": "my-game"}' \
  http://localhost:5302/api/execute
```

## API Reference

### `GET /api/health`

Health check. No auth required.

### `GET /api/executors`

List all connected Godot editor instances. Requires Bearer token auth.

### `POST /api/execute`

Execute GDScript code on a connected editor. Requires Bearer token auth.

**Request body:**

| Field           | Type   | Description                                      |
| --------------- | ------ | ------------------------------------------------ |
| `code`          | string | GDScript code to execute                         |
| `executor_id`   | string | Exact executor ID (optional)                     |
| `project_name`  | string | Fuzzy match on project name (optional)           |
| `project_path`  | string | Fuzzy match on project path (optional)           |

Provide exactly one of `executor_id`, `project_name`, or `project_path` to target an editor.

**Response:**

```json
{
  "success": true,
  "data": {
    "request_id": "uuid",
    "compile_success": true,
    "compile_error": "",
    "run_success": true,
    "run_error": "",
    "outputs": [["key", "value"]]
  }
}
```

### Execution Modes

**Snippet mode** (default): If your code doesn't contain `extends`, it's automatically wrapped in a `@tool extends RefCounted` class with an `executeContext` variable available for returning results:

```gdscript
var tree = Engine.get_main_loop() as SceneTree
var scene = tree.edited_scene_root
executeContext.output("scene_name", scene.name)
executeContext.output("child_count", str(scene.get_child_count()))
```

**Full class mode**: If your code contains `extends`, you must define `func execute(executeContext):` yourself:

```gdscript
extends Node

func execute(executeContext):
    var root = get_tree().root
    executeContext.output("viewport_size", str(root.get_visible_rect().size))
```

## A Note on Security

This plugin literally executes arbitrary code in your editor. The broker server uses Bearer token authentication to prevent unauthorized access, but you should still:

- **Never expose the broker server to the public internet.** Bind to `localhost` (the default).
- **Keep your auth token secret.** It's a crypto-random 64-character hex string. Treat it like a password, because functionally it is one.
- **Trust your coding agent.** It can do anything GDScript can do, which is quite a lot.

## License

MIT
