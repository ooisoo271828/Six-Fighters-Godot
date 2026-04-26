## 1. Broker-Server Project Setup

- [x] 1.1 Initialize `broker-server/` as a Node.js project: create `package.json` with name "hastur-broker-server", add `commander`, `express` as dependencies, add `typescript`, `vite`, `@types/express`, `@types/node` as devDependencies, configure `scripts.build` to use Vite and `scripts.start` to run the built output
- [x] 1.2 Create `broker-server/tsconfig.json` with strict mode, ES module output, Node.js target, and `src/` as root
- [x] 1.3 Create `broker-server/vite.config.ts` configured for Node.js library mode (externalize `express`, `commander` and all non-bundled deps), output to `dist/`
- [x] 1.4 Create `broker-server/.gitignore` excluding `node_modules/`, `dist/`, and editor/OS files
- [x] 1.5 Create `broker-server/src/types.ts` with TypeScript interfaces for: `ExecutorInfo` (id, project_name, project_path, editor_pid, plugin_version, editor_version, supported_languages, connected_at, status), `TcpMessage` (type, data), `ExecuteRequest` (request_id, code, language), `ExecuteResult` (request_id, compile_success, compile_error, run_success, run_error, outputs), `ApiResponse` (success, error?, hint?, data?)

## 2. TCP Server & Executor Manager

- [x] 2.1 Create `broker-server/src/executor-manager.ts` with an `ExecutorManager` class that manages registered Hastur Executor instances: stores executor info keyed by ID, supports add/remove/query, handles re-registration by replacing existing connections, and provides a method to find executors by ID or fuzzy-match project_name/project_path
- [x] 2.2 Create `broker-server/src/tcp-server.ts` implementing a TCP server using Node.js `net` module: accept connections, parse NDJSON messages (line-split), handle `register` messages with deterministic ID generation (SHA-256 of `project_name|project_path|editor_pid` formatted as UUID), respond with `register_result`
- [x] 2.3 Add RPC execution support to `tcp-server.ts`: generate unique request_id (UUID), send `execute` messages to executors, track pending requests in a Map keyed by request_id, handle `execute_result` responses by resolving pending requests, implement 30-second request timeout
- [x] 2.4 Add heartbeat mechanism to `tcp-server.ts`: track last message time per connection, send `ping` after 60s idle, close connection if no `pong` within 10s
- [x] 2.5 Handle executor disconnection in `tcp-server.ts`: on connection close, remove executor from ExecutorManager, reject all pending RPC requests for that executor with disconnect error

## 3. HTTP API Server

- [x] 3.1 Create `broker-server/src/auth.ts` with Express middleware that validates `Authorization: Bearer <token>` header, returns 401 with AI-friendly error+hint on missing or invalid token
- [x] 3.2 Create `broker-server/src/http-server.ts` with Express app: apply auth middleware to all `/api/*` routes except `/api/health`, add JSON body parser, implement `GET /api/health` returning server status (no auth required)
- [x] 3.3 Implement `GET /api/executors` endpoint: return JSON array of all registered executors with id, project_name, project_path, editor_pid, plugin_version, editor_version, supported_languages, connected_at, status; include hint when list is empty
- [x] 3.4 Implement `POST /api/execute` endpoint: validate request body has `code` field and at least one executor identifier (executor_id, project_name, or project_path), find matching executor, send execute request via TCP server, await result with timeout, return result as JSON; handle all error cases (no match, missing fields, timeout) with AI-friendly hints
- [x] 3.5 Add catch-all 404 handler and 405 method-not-allowed responses with AI-friendly hints listing available endpoints

## 4. CLI Entry Point

- [x] 4.1 Create `broker-server/src/index.ts` using Commander: define `--tcp-port` (default 5301), `--http-port` (default 5302), `--host` (default "localhost"), `--auth-token` (optional) options; auto-generate a random token (32+ chars) if not provided and print to stdout
- [x] 4.2 Wire CLI to TCP server and HTTP server: start both servers with the configured options, print listening addresses and auth token to stdout on startup
- [x] 4.3 Add graceful shutdown: listen for SIGINT/SIGTERM, close TCP connections first, then HTTP server, then exit with code 0

## 5. Godot Hastur Executor - Broker Client

- [x] 5.1 Create `addons/hasturoperationgd/broker_client.gd` as a `RefCounted` class: implement TCP connection using `StreamPeerTCP`, NDJSON message parsing (read until `\n`), and exponential backoff reconnection (1s to max 30s)
- [x] 5.2 Implement registration handshake in `broker_client.gd`: on connect, send register message with project_name (`ProjectSettings.get_setting("application/config/name")`), project_path (`ProjectSettings.globalize_path("res://")`), editor_pid (`OS.get_process_id()`), plugin_version, editor_version, supported_languages; parse `register_result` response
- [x] 5.3 Implement RPC handling in `broker_client.gd`: listen for `execute` messages, run code through `GDScriptExecutor`, send back `execute_result` with the request_id
- [x] 5.4 Implement heartbeat in `broker_client.gd`: respond to `ping` with `pong`
- [x] 5.5 Add signals to `broker_client.gd`: `connection_established(id: String)` and `connection_lost()`
- [x] 5.6 Add `_process` polling in `broker_client.gd`: poll TCP connection status each frame using `StreamPeerTCP.poll()`, handle incoming data, manage connection lifecycle

## 6. Godot Hastur Executor - Settings & Dock UI Updates

- [x] 6.1 Update `addons/hasturoperationgd/plugin_settings.gd` to register `hastur_operation/broker_host` (String, default "localhost") and `hastur_operation/broker_port` (int, default 5301) in ProjectSettings
- [x] 6.2 Update `addons/hasturoperationgd/executor_dock.gd` layout: add connection status bar (HBoxContainer) at top with status label and copyable ID label, keep existing CodeEdit/Button/RichTextLabel, add execution history panel (ItemList or similar) with "Clear History" button at bottom
- [x] 6.3 Implement connection status display in `executor_dock.gd`: connect to `broker_client` signals, update status label to "Connected" (green) / "Disconnected" (red), show/hide registration ID label; instantiate `BrokerClient` in `_ready()` and read broker_host/broker_port from ProjectSettings
- [x] 6.4 Implement execution history in `executor_dock.gd`: maintain an array of history entries (max 50), each containing code, result dict, timestamp, duration_ms, source ("local"/"remote"); populate history on every local and remote execution; display entries in an ItemList with code preview (first line truncated to 60 chars), status indicator, timestamp, duration
- [x] 6.5 Implement history entry selection: when user selects a history entry, populate the code editor with the entry's code and display the result in the result area
- [x] 6.6 Implement "Clear History" button: connect to clear all history entries and reset the history display
- [x] 6.7 Integrate remote execution tracking: when `broker_client` receives and executes remote code, emit a signal with the result so `executor_dock.gd` can add it to history with source "remote"; update local execution to also record to history with source "local" and capture start/end time for duration

## 7. Hastur Executor Lifecycle Integration

- [x] 7.1 Update `addons/hasturoperationgd/hasturoperationgd.gd` to instantiate the `BrokerClient` and pass it to the dock; ensure cleanup in `_exit_tree()` (disconnect client, free resources)
