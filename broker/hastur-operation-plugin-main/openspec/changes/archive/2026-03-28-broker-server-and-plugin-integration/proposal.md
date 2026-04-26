## Why

The Hastur Executor plugin currently only supports local code execution within a single Godot editor instance. There is no way for external tools (particularly AI agents) to remotely execute GDScript code in a running Godot editor. A broker server is needed to bridge external HTTP clients with Godot editor Hastur Executor instances via a TCP connection, enabling AI-driven workflows and remote editor manipulation.

## What Changes

- Create a new Node.js project (`broker-server/`) with TypeScript, managed by npm, using Commander for CLI and Express for HTTP server, bundled with Vite
- Add a TCP server (default port 5301) that accepts connections from Godot Hastur Executor instances, handles registration (project name, path, editor PID → stable UUID), and supports bidirectional RPC for remote code execution
- Add an HTTP RESTful API server (default port 5302) with auth token protection, providing endpoints to query registered executors and execute code on connected executor instances
- Add execution history UI to the Hastur Executor dock panel, showing up to 50 records (local and remote) with code, results, timestamps, duration, and a clear button
- Add connection status and registration ID display to the Hastur Executor dock panel, with auto-reconnect logic and copyable ID
- Support configurable host binding (default localhost), TCP/HTTP ports, and auth token via CLI arguments

## Capabilities

### New Capabilities
- `broker-server-cli`: CLI entry point for the broker-server Node.js project, handling argument parsing (ports, host, auth token) and server lifecycle management
- `tcp-executor-protocol`: TCP server handling Hastur Executor connections, registration with deterministic UUID, bidirectional RPC for code execution, and heartbeat management
- `http-api-server`: HTTP RESTful API server for AI agents with auth middleware, executor query endpoints, and code execution proxying to connected executors via TCP
- `executor-remote-connection`: Client-side TCP connection logic in the Godot Hastur Executor with auto-reconnect, registration handshake, and RPC response handling
- `executor-dock-connection-status`: UI additions to the executor dock showing connection status, registration ID (copyable), and real-time connection state
- `execution-history`: Execution history tracking in the executor dock showing up to 50 records (local + remote) with code, results, timestamps, duration, and clear functionality

### Modified Capabilities
- `executor-dock-ui`: Add connection status panel above the code editor and execution history panel below the result output area

## Impact

- **New codebase**: `broker-server/` directory becomes a standalone Node.js project (package.json, tsconfig, vite config, src/)
- **Plugin code**: `executor_dock.gd` modified to add connection status, history panel, and remote execution integration
- **New plugin scripts**: TCP client script for the Hastur Executor (`broker_client.gd` or similar), history manager
- **Dependencies**: Node.js dependencies (commander, express, typescript, vite, etc.)
- **API contract**: New HTTP API endpoints that AI agents will consume
- **Protocol**: New TCP-based JSON protocol between broker-server and Godot Hastur Executor instances
