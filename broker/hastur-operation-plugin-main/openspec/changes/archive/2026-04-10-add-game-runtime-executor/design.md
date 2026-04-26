## Context

The HasturOperationGD plugin currently provides remote GDScript execution within the Godot editor process via a TCP→HTTP relay architecture (plugin → broker-server → AI agent). The game runtime process is a separate OS process that the plugin cannot reach. When the game is running, the scene tree, physics engine, input state, and all runtime variables are inaccessible to AI agents.

The existing codebase already has well-separated components (`BrokerClient`, `GDScriptExecutor`, `ExecutionContext`) that can be reused directly in a game-runtime context.

## Goals / Non-Goals

**Goals:**
- Enable AI agents to execute arbitrary GDScript code in the running game process via the existing broker-server HTTP API
- Reuse existing `BrokerClient`, `GDScriptExecutor`, and `ExecutionContext` components without modification
- Distinguish editor executors from game executors in the broker-server's registry so agents can target the right one
- Ensure the game executor never runs in exported/release builds

**Non-Goals:**
- In-editor UI for managing the game executor (users manually add the Autoload)
- Game-internal developer console (could be a future addition)
- IPC relay through the editor process (game connects directly to broker-server)
- Automatic Autoload registration by the plugin

## Decisions

### D1: Autoload singleton approach

**Decision**: `GameExecutor` is a GDScript file placed at `addons/hasturoperationgd/game_executor.gd` that extends `Node`. Users manually register it as an Autoload in Project Settings.

**Rationale**: Simple, transparent, and gives users full control. The script lives in the plugin directory so it updates with the plugin. No magic — users know exactly what's running in their game.

**Alternatives considered**:
- Auto-registration by the plugin: Adds complexity, could conflict with user edits to `project.godot`, and hides behavior from the user.
- Separate scene with UI: Overkill for an Autoload that just needs to run code.

### D2: Direct broker connection (no editor relay)

**Decision**: The game process connects directly to the broker-server via TCP, using the same `BrokerClient`.

**Rationale**: Eliminates an entire IPC layer. The `BrokerClient` already handles connection, registration, heartbeat, and reconnection — all reusable as-is.

**Alternatives considered**:
- Editor-as-relay: Would avoid exposing broker to game process, but adds a full IPC protocol for no clear benefit.

### D3: Executor type in registration protocol

**Decision**: Add a `type` field (`"editor"` | `"game"`) to the TCP registration message. Stored in `ExecutorInfo` on the broker. Exposed via HTTP API.

**Rationale**: The broker needs to distinguish executor kinds so agents can target a specific one. Default executor selection (by `project_name`) should prefer editor executors when both exist.

**Alternatives considered**:
- Separate endpoints for game executors: Adds API surface area for no benefit.
- Infer type from metadata: Fragile and implicit.

### D4: Executor ID generation — same algorithm, different PID

**Decision**: Game executors use the same `SHA-256(project_name + project_path + OS.get_process_id())` algorithm. Since the game process has a different PID from the editor, IDs will naturally differ.

**Rationale**: Consistent, deterministic, no special-casing needed.

### D5: Debug-build-only guard

**Decision**: `GameExecutor._ready()` calls `OS.is_debug_build()`. If false, the node frees itself immediately without connecting to the broker.

**Rationale**: Exported builds must never connect to the broker. `OS.is_debug_build()` is the standard Godot check for this.

### D6: Graceful shutdown on game exit

**Decision**: `GameExecutor._notification(NOTIFICATION_WM_CLOSE_REQUEST)` disconnects cleanly from the broker to avoid ghost executors.

**Rationale**: Games start/stop frequently during development. Without clean disconnect, the broker accumulates stale entries until the heartbeat timeout (60s + 10s) cleans them up.

## Risks / Trade-offs

**[High-frequency connect/disconnect]** → Games start and stop much more often than editors. The broker's heartbeat cleanup (70s total) means stale game executors could linger. **Mitigation**: Clean disconnect on game exit (D6) plus the existing heartbeat timeout as a fallback.

**[User forgets to add Autoload]** → The feature silently doesn't work. **Mitigation**: The executor dock UI could show a hint if no game executor is detected. Out of scope for this change but noted for future.

**[Security in debug builds]** → Any debug build will connect to the broker if the Autoload is present and the broker is reachable. **Mitigation**: Acceptable for a development tool — broker requires Bearer token auth and defaults to localhost.

**[BrokerClient reconnection during gameplay]** → The exponential backoff (1s→30s) was designed for editors staying open long-term. Games are more ephemeral. **Mitigation**: Accept as-is; the reconnection logic works correctly regardless of session length.
