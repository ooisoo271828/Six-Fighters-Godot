## Why

The plugin currently only supports executing GDScript code within the editor process. When the game is running (a separate process), AI agents have no way to inspect or manipulate the live game state — scene tree, physics, input, runtime variables — even though this is precisely where debugging and iteration are most valuable.

## What Changes

- Add a `GameExecutor` autoload singleton script that connects to the broker-server from the running game process, enabling remote code execution in the game runtime
- Extend the TCP executor protocol to include an executor `type` field (`"editor"` / `"game"`) during registration
- Extend the broker-server HTTP API to expose executor type information and support filtering by type
- Add `OS.is_debug_build()` guard to prevent the GameExecutor from running in release/exported builds

## Capabilities

### New Capabilities
- `game-runtime-executor`: Autoload singleton that runs in the game process, connects to the broker-server, and enables remote GDScript code execution during gameplay. Includes debug-build-only guard and graceful lifecycle management.

### Modified Capabilities
- `tcp-executor-protocol`: Registration message gains a `type` field (`"editor"` | `"game"`) to distinguish executor kinds
- `executor-remote-connection`: Executor type is included in the registration handshake
- `http-api-server`: `/api/executors` response includes `type` field; `/api/execute` supports optional `type` filter parameter

## Impact

- **New file**: `addons/hasturoperationgd/game_executor.gd` (Autoload script, user manually adds to Project Settings)
- **Modified**: `addons/hasturoperationgd/broker_client.gd` — sends `type` in registration
- **Modified**: `broker-server/src/tcp-server.ts` — stores and exposes executor type
- **Modified**: `broker-server/src/http-server.ts` — returns type in responses, supports type filtering
- **Modified**: `broker-server/src/types.ts` — `ExecutorInfo` gains `type` field
- **No breaking changes**: All existing API consumers continue to work without modification
