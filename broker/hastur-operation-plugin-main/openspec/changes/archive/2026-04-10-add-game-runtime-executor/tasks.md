## 1. Broker Server: Type Support

- [x] 1.1 Add `type` field (`"editor"` | `"game"`) to `ExecutorInfo` interface in `broker-server/src/types.ts`, defaulting to `"editor"` for backward compatibility
- [x] 1.2 Update `tcp-server.ts` to extract and store the `type` field from the `register` message; include `type` in the `missing fields` validation error when absent
- [x] 1.3 Update `executor-manager.ts` lookup methods to accept an optional `type` filter parameter that restricts results to matching executor types
- [x] 1.4 Update `GET /api/executors` in `http-server.ts` to include the `type` field in each executor entry
- [x] 1.5 Update `POST /api/execute` in `http-server.ts` to accept an optional `type` field in the request body and pass it through to the executor lookup

## 2. Broker Client: Type in Registration

- [x] 2.1 Add an `executor_type` parameter to `BrokerClient` (via constructor or property) so the registration message includes the `type` field
- [x] 2.2 Update the editor-side `ExecutorBackend` to pass `type: "editor"` when creating its `BrokerClient`

## 3. GameExecutor Autoload

- [x] 3.1 Create `addons/hasturoperationgd/game_executor.gd` extending `Node` with `OS.is_debug_build()` guard in `_ready()` that frees the node on release builds
- [x] 3.2 In `GameExecutor._ready()`, create and configure a `BrokerClient` instance with `type: "game"` using the existing `hastur_operation/broker_host` and `hastur_operation/broker_port` settings
- [x] 3.3 Implement execute message handling: receive code from `BrokerClient`, execute via `GDScriptExecutor`, return results through `BrokerClient`
- [x] 3.4 Add `_process()` polling for `BrokerClient` (same pattern as `ExecutorBackend`)
- [x] 3.5 Implement graceful shutdown: handle `NOTIFICATION_WM_CLOSE_REQUEST` and `NOTIFICATION_PREDELETE_CLEANUP` to disconnect cleanly from the broker-server

## 4. Verification

- [x] 4.1 Manually test: add `game_executor.gd` as Autoload, launch game from editor, verify game executor appears in `GET /api/executors` with `type: "game"`
- [x] 4.2 Manually test: execute code via `POST /api/execute` with `type: "game"` and verify code runs in game process context
- [x] 4.3 Manually test: stop the game, verify the game executor is removed from the broker's executor list without waiting for heartbeat timeout
- [x] 4.4 Verify existing editor executor functionality is unchanged (backward compatibility)
