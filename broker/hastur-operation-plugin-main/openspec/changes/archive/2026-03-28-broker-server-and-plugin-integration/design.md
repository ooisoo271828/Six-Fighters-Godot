## Context

The Hastur Executor is a Godot editor plugin that currently executes GDScript code locally within a single editor instance. The project has an existing codebase under `addons/hasturoperationgd/` with:
- `hasturoperationgd.gd` - Plugin entry point, creates dock
- `executor_dock.gd` - Dock UI with CodeEdit, Execute button, RichTextLabel result area
- `gdscript_executor.gd` - Code compilation and execution engine
- `execution_context.gd` - Output collection context
- `plugin_settings.gd` - ProjectSettings registration

The `broker-server/` directory exists but only contains a `.gdignore` file. No Node.js project exists yet.

## Goals / Non-Goals

**Goals:**
- Enable AI agents to remotely execute GDScript code in running Godot editors via HTTP API
- Provide a stable broker server that mediates between HTTP clients and Godot Hastur Executor instances via TCP
- Maintain backward compatibility with existing local execution functionality
- Make the dock UI informative about connection state and execution history

**Non-Goals:**
- Multi-language execution support (C# etc.) at the broker level — broker treats code as opaque text
- Persistent storage of execution history or executor registrations
- TLS/SSL for the TCP or HTTP servers
- Horizontal scaling or multi-broker architecture

## Decisions

### 1. TCP protocol uses newline-delimited JSON (NDJSON)

**Choice**: Each TCP message is a single JSON object terminated by `\n`.

**Rationale**: Simple to implement in both Node.js (line-based stream splitting) and GDScript (read until `\n`). No need for custom binary framing. Easy to debug.

**Alternatives considered**:
- Length-prefixed binary protocol: More efficient but harder to debug and implement in GDScript
- WebSocket: Requires additional dependency in Godot; overkill for a simple 1:1 connection

### 2. Deterministic UUID generation using SHA-256 hash

**Choice**: Registration ID is derived from `SHA-256(project_name + "|" + project_path + "|" + editor_pid)`, formatted as a UUID-like string (first 32 hex chars with dashes).

**Rationale**: Same project + same editor process always gets the same ID, enabling reconnection without duplicate registrations.

**Alternatives considered**:
- UUID v5: Requires a namespace; more complex with no real benefit
- Random UUID with server-side mapping: Would require persistence for reconnection scenarios
- Simple concatenation: Not a standard-looking identifier

### 3. Express.js for HTTP API with Bearer token auth

**Choice**: Use Express with a simple middleware that checks `Authorization: Bearer <token>` header.

**Rationale**: Standard, minimal, well-understood. The auth token is either provided via CLI arg or auto-generated and printed to console.

**Alternatives considered**:
- API key in query string: Less secure, visible in logs
- JWT: Overkill for a single-server local tool
- No auth: Unsafe if bound to non-localhost addresses

### 4. Commander.js for CLI argument parsing

**Choice**: Use the `commander` npm package for parsing CLI arguments.

**Rationale**: De facto standard for Node.js CLI apps. Provides `--help`, type coercion, and default values out of the box.

### 5. Vite for TypeScript compilation and bundling

**Choice**: Use Vite in library mode to compile and bundle the TypeScript project into a distributable Node.js package.

**Rationale**: Fast builds, good TypeScript support, widely used. The `broker-server` is a standalone CLI tool that needs to be compiled from TypeScript.

### 6. Execution history stored in-memory on the Godot side

**Choice**: The dock panel maintains an in-memory array (max 50 entries) of execution records. No file I/O.

**Rationale**: Simple, fast, no file permission issues. History is ephemeral and resets on editor restart, which is acceptable for debugging/monitoring purposes.

### 7. AI-agent-friendly HTTP responses

**Choice**: HTTP API responses always include structured JSON with `success`, `data`, and `hint` fields. On errors, `hint` contains actionable guidance for AI agents.

**Rationale**: AI agents need clear, machine-parseable feedback. Including hints in error responses reduces retry loops and guides correct API usage.

### 8. Project structure for broker-server

```
broker-server/
  src/
    index.ts            - CLI entry point (commander)
    tcp-server.ts       - TCP server for Hastur Executor connections
    http-server.ts      - Express HTTP API server
    executor-manager.ts - Hastur Executor registration & lifecycle
    auth.ts             - Auth token middleware
    types.ts            - Shared types/interfaces
  package.json
  tsconfig.json
  vite.config.ts
  .gitignore
```

**Rationale**: Flat module structure, each file has a clear single responsibility. No deep nesting needed for this scope.

### 9. Godot plugin additions

New scripts:
- `broker_client.gd` - TCP client with auto-reconnect, registration, RPC handling

Modified scripts:
- `executor_dock.gd` - Add connection status bar, execution history panel, integrate broker_client

**Rationale**: Keep the TCP client separate from UI for testability. The dock acts as the coordinator.

## Risks / Trade-offs

- **[TCP connection drops]** → Hastur Executor implements exponential backoff auto-reconnect (1s, 2s, 4s, max 30s). Registration ID is deterministic so reconnection is seamless.
- **[No TLS]** → Default binding to localhost mitigates exposure. Users binding to external IPs should be aware of plaintext communication.
- **[GDScript TCP limitations]** → Godot's `StreamPeerTCP` API is basic; we use line-based JSON which maps well to its read/write capabilities. Need to handle partial reads carefully.
- **[Concurrent HTTP requests targeting same executor]** → TCP RPC requests are queued per executor connection; each gets a unique `request_id` and responses are matched asynchronously.
- **[Vite for Node.js bundling]** → Vite is primarily a frontend tool but works well for Node.js library bundling with the right config. Alternative would be `tsup` or raw `tsc`, but Vite is already familiar and fast.
