## ADDED Requirements

### Requirement: Backend service lifecycle
The plugin SHALL create an `ExecutorBackend` node during `_enter_tree()` before creating any UI. The backend SHALL be added as a child of the plugin node. The backend SHALL be freed during `_exit_tree()` after removing the dock panel.

#### Scenario: Plugin enabled creates backend
- **WHEN** the HasturOperationGD plugin is enabled via `_enter_tree()`
- **THEN** the plugin SHALL create an `ExecutorBackend` node, add it as a child, and start the broker client connection before creating the dock panel

#### Scenario: Plugin disabled destroys backend
- **WHEN** the HasturOperationGD plugin is disabled via `_exit_tree()`
- **THEN** the plugin SHALL disconnect and free the `ExecutorBackend` after removing the dock panel

### Requirement: Broker client ownership by backend
The `ExecutorBackend` SHALL own and manage the `BrokerClient` instance. It SHALL create the client on initialization using host/port from `HasturOperationGDPluginSettings` and drive its poll loop via `_process()`.

#### Scenario: Backend creates broker client
- **WHEN** the `ExecutorBackend` is initialized
- **THEN** it SHALL create a `BrokerClient` with the host and port from `HasturOperationGDPluginSettings`

#### Scenario: Backend drives broker client poll loop
- **WHEN** the `ExecutorBackend` receives a `_process()` callback
- **THEN** it SHALL call `poll(delta)` on the `BrokerClient`

#### Scenario: Backend disconnects broker client on cleanup
- **WHEN** the `ExecutorBackend` is being freed
- **THEN** it SHALL call `disconnect_client()` on the `BrokerClient`

### Requirement: Local code execution via backend
The `ExecutorBackend` SHALL own a `GDScriptExecutor` for local code execution and expose an `execute_code(code: String)` method that returns the execution result.

#### Scenario: Local execution through backend
- **WHEN** `execute_code("print(\"hello\")")` is called on the backend
- **THEN** the backend SHALL execute the code using its `GDScriptExecutor` and return the result dictionary

### Requirement: Connection state signals
The `ExecutorBackend` SHALL emit a `connection_state_changed(connected: bool, executor_id: String)` signal when the broker client connection state changes.

#### Scenario: Connection established
- **WHEN** the `BrokerClient` emits `connection_established(id)`
- **THEN** the `ExecutorBackend` SHALL emit `connection_state_changed(true, id)`

#### Scenario: Connection lost
- **WHEN** the `BrokerClient` emits `connection_lost()`
- **THEN** the `ExecutorBackend` SHALL emit `connection_state_changed(false, "")`

### Requirement: Execution completed signal
The `ExecutorBackend` SHALL emit an `execution_completed(entry: Dictionary)` signal when any execution (local or remote) completes. The entry SHALL contain `code`, `result`, `timestamp`, `duration_ms`, and `source`.

#### Scenario: Local execution completed signal
- **WHEN** code is executed locally via `execute_code()`
- **THEN** the backend SHALL emit `execution_completed` with the execution entry containing `source: "local"`

#### Scenario: Remote execution completed signal
- **WHEN** the `BrokerClient` emits `remote_execution_completed(code, result, duration_ms)`
- **THEN** the backend SHALL emit `execution_completed` with the execution entry containing `source: "remote"`

### Requirement: Execution history management
The `ExecutorBackend` SHALL maintain an in-memory execution history with a maximum of 50 entries. New entries SHALL be appended. When the limit is reached, the oldest entry SHALL be removed. The backend SHALL expose a `get_history()` method returning the history array.

#### Scenario: History entry added
- **WHEN** an execution completes (local or remote)
- **THEN** the backend SHALL add a history entry and emit `execution_completed`

#### Scenario: History at capacity
- **WHEN** there are 50 history entries and a new execution completes
- **THEN** the oldest entry SHALL be removed before the new entry is appended

#### Scenario: Clear history
- **WHEN** `clear_history()` is called on the backend
- **THEN** all history entries SHALL be removed and `history_cleared` signal SHALL be emitted

### Requirement: Backend operates without dock panel
The `ExecutorBackend` SHALL function independently of the dock panel. It SHALL connect to the broker-server, respond to remote execution requests, and accumulate history even if no dock panel exists.

#### Scenario: Remote execution without dock
- **WHEN** the plugin is enabled but no dock panel is created (e.g., dock is closed)
- **THEN** the backend SHALL still receive and execute remote commands from the broker-server

#### Scenario: Broker reconnect without dock
- **WHEN** the broker connection is lost and no dock panel exists
- **THEN** the backend SHALL still drive the reconnection attempts via its poll loop
