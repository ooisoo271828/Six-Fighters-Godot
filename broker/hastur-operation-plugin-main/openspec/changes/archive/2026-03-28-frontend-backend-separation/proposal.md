## Why

The current architecture couples all backend logic (BrokerClient lifecycle, remote command listening, code execution) inside `executor_dock.gd`, which is a UI `Control`. This means the broker client only exists when the dock panel is created, and the plugin's `_exit_tree()` cleanup awkwardly reaches back into the dock to access the client. Without the dock panel, the executor cannot receive or process remote commands — making it impossible to run headlessly or support scenarios where the dock is closed/hidden.

## What Changes

- Introduce a backend service (`ExecutorBackend`) managed by the plugin entry point (`hasturoperationgd.gd`) that owns the `BrokerClient` and handles its lifecycle (create, poll, disconnect) independently of any UI
- The backend service will own the `GDScriptExecutor` for local execution and receive execution events from the `BrokerClient` for remote execution
- Move the `_process()` polling of `BrokerClient` from `executor_dock.gd` to the backend service (driven by the plugin entry point)
- Refactor `executor_dock.gd` to be a pure UI layer: it subscribes to signals from the backend service for status updates and execution results, but owns no network or execution logic
- The plugin entry point creates the backend first, then optionally creates the dock panel and injects the backend reference
- History data management moves to the backend service; the dock only reads and displays it

## Capabilities

### New Capabilities
- `executor-backend-service`: A non-UI backend service that manages the BrokerClient connection, GDScriptExecutor, and execution history, running independently of the dock panel. Drives the broker poll loop, handles remote execution, and exposes signals for connection state and execution events.

### Modified Capabilities
- `executor-dock-ui`: The dock panel will no longer create or manage the BrokerClient. Instead, it receives a reference to the backend service and subscribes to its signals for display-only updates. Layout remains the same.
- `execution-history`: History storage and management moves to the backend service. The dock reads history from the backend instead of managing it locally.

## Impact

- `addons/hasturoperationgd/hasturoperationgd.gd`: Plugin entry point takes on backend lifecycle management (create backend on `_enter_tree`, destroy on `_exit_tree`)
- `addons/hasturoperationgd/executor_dock.gd`: Major refactor — remove BrokerClient creation, GDScriptExecutor creation, poll loop, and signal wiring. Replace with read-only subscription to backend service signals
- New file: `addons/hasturoperationgd/executor_backend.gd` — the backend service class
- `addons/hasturoperationgd/broker_client.gd`: Minor — may need API adjustments to support being owned by the backend instead of the dock
- `addons/hasturoperationgd/gdscript_executor.gd`: No changes expected
- `addons/hasturoperationgd/execution_context.gd`: No changes expected
