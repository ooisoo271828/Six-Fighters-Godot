## ADDED Requirements

### Requirement: TCP client with auto-reconnect
The Godot Hastur Executor SHALL implement a TCP client that connects to the broker-server. The client SHALL attempt to connect on startup and automatically reconnect with exponential backoff (1s, 2s, 4s, 8s, max 30s) if the connection is lost.

#### Scenario: Initial connection on executor enable
- **WHEN** the Hastur Executor is enabled and the broker-server is reachable
- **THEN** the client SHALL connect to the broker-server TCP server and send a registration message

#### Scenario: Connection refused (server not running)
- **WHEN** the Hastur Executor is enabled and the broker-server is not reachable
- **THEN** the client SHALL retry connection every 1 second initially, increasing to max 30 seconds

#### Scenario: Connection drops during operation
- **WHEN** the established TCP connection is lost
- **THEN** the client SHALL automatically begin reconnection attempts with exponential backoff

#### Scenario: Successful reconnection
- **WHEN** the client reconnects after a disconnect
- **THEN** the client SHALL send the registration message again and receive the same deterministic ID

### Requirement: Registration handshake
Upon connecting, the Hastur Executor SHALL send a `register` message containing `project_name` (from ProjectSettings), `project_path` (from `ProjectSettings.globalize_path("res://")`), `editor_pid` (from `OS.get_process_id()`), `plugin_version` (from plugin.cfg), `editor_version` (from `Engine.get_version_info()`), and `supported_languages` (`["gdscript"]`).

#### Scenario: Successful registration
- **WHEN** the client sends a valid register message and the server responds with `{"type": "register_result", "data": {"success": true, "id": "<uuid>"}}`
- **THEN** the client SHALL store the registration ID and emit a connection established signal

#### Scenario: Registration failure
- **WHEN** the server responds with `{"type": "register_result", "data": {"success": false, "error": "..."}}`
- **THEN** the client SHALL log the error and retry registration after a delay

### Requirement: RPC response handling
The client SHALL listen for `execute` messages from the server, execute the code using the local `GDScriptExecutor`, and send back `execute_result` messages with the `request_id` from the original request.

#### Scenario: Receive and execute remote code
- **WHEN** the client receives `{"type": "execute", "data": {"request_id": "abc-123", "code": "print(\"hello\")", "language": "gdscript"}}`
- **THEN** the client SHALL execute the code using `GDScriptExecutor`, collect the result, and send `{"type": "execute_result", "data": {"request_id": "abc-123", "compile_success": true, "compile_error": "", "run_success": true, "run_error": "", "outputs": [...]}}`

#### Scenario: Remote execution failure
- **WHEN** remote code fails to compile or run
- **THEN** the client SHALL send the result with `compile_success: false` or `run_success: false` and the respective error messages

### Requirement: Heartbeat response
The client SHALL respond to `ping` messages from the server with `pong` messages to maintain the connection.

#### Scenario: Receive ping
- **WHEN** the client receives `{"type": "ping"}`
- **THEN** the client SHALL send `{"type": "pong"}`

### Requirement: Connection state signals
The client SHALL emit signals for connection state changes: `connection_established(id: String)` and `connection_lost()`.

#### Scenario: Connection established signal
- **WHEN** registration succeeds
- **THEN** the client SHALL emit `connection_established` with the registration ID

#### Scenario: Connection lost signal
- **WHEN** the TCP connection drops
- **THEN** the client SHALL emit `connection_lost`
