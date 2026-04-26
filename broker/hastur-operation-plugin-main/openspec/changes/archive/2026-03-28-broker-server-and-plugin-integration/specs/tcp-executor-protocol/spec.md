## ADDED Requirements

### Requirement: TCP server for executor connections
The broker-server SHALL start a TCP server that listens for connections from Hastur Executor instances (Godot editor plugins). The server SHALL use newline-delimited JSON (NDJSON) as the message protocol. Each incoming TCP connection SHALL be tracked and associated with a registered executor.

#### Scenario: Executor connects
- **WHEN** a TCP client connects to the TCP server
- **THEN** the server SHALL accept the connection and wait for a registration message

#### Scenario: Executor disconnects
- **WHEN** a registered executor's TCP connection closes
- **THEN** the server SHALL mark that executor as disconnected and remove it from the active executor list

### Requirement: Executor registration with deterministic ID
The TCP server SHALL handle a `register` message from the executor containing `project_name`, `project_path`, `editor_pid`, `plugin_version`, `editor_version`, and `supported_languages`. The server SHALL compute a deterministic ID using `SHA-256(project_name + "|" + project_path + "|" + editor_pid)`, formatted as a UUID-like string (8-4-4-4-12 hex pattern from the first 32 hex chars). If an executor with the same ID is already registered, the old connection SHALL be replaced.

#### Scenario: New executor registration
- **WHEN** the server receives `{"type": "register", "data": {"project_name": "my-game", "project_path": "/home/user/my-game", "editor_pid": 12345, "plugin_version": "0.1", "editor_version": "4.3", "supported_languages": ["gdscript"]}}`
- **THEN** the server SHALL compute the deterministic ID, store the executor info, and respond with `{"type": "register_result", "data": {"success": true, "id": "<computed-id>"}}`

#### Scenario: Re-registration replaces existing
- **WHEN** an executor registers with the same project_name, project_path, and editor_pid as an already registered executor
- **THEN** the server SHALL close the old TCP connection, update the registration with the new connection, and respond with the same deterministic ID

#### Scenario: Missing registration fields
- **WHEN** the server receives a `register` message missing required fields
- **THEN** the server SHALL respond with `{"type": "register_result", "data": {"success": false, "error": "<description of missing fields>"}}`

### Requirement: RPC code execution over TCP
The TCP server SHALL support sending `execute` messages to a registered executor and receiving `execute_result` responses. Each execute message SHALL include a unique `request_id` for correlating responses. The server SHALL track pending requests and match responses by `request_id`.

#### Scenario: Server sends execute request to executor
- **WHEN** the HTTP API triggers code execution on an executor
- **THEN** the server SHALL send `{"type": "execute", "data": {"request_id": "<uuid>", "code": "<code-string>", "language": "gdscript"}}` to the executor's TCP connection

#### Scenario: Executor returns execution result
- **WHEN** the server receives `{"type": "execute_result", "data": {"request_id": "<id>", "compile_success": true, "compile_error": "", "run_success": true, "run_error": "", "outputs": [["key", "value"]]}}`
- **THEN** the server SHALL resolve the pending request and forward the result to the HTTP API caller

#### Scenario: Executor disconnects during pending request
- **WHEN** an executor disconnects while there are pending execute requests
- **THEN** all pending requests for that executor SHALL be resolved with an error result indicating the executor disconnected

### Requirement: Request timeout
The TCP server SHALL enforce a timeout (default 30 seconds) on pending execute requests. If an executor does not respond within the timeout, the request SHALL be resolved with a timeout error.

#### Scenario: Execute request times out
- **WHEN** an executor does not respond to an execute request within 30 seconds
- **THEN** the server SHALL resolve the pending request with an error result indicating timeout

### Requirement: Heartbeat mechanism
The TCP server SHALL implement a heartbeat mechanism. If a registered executor does not send any message for 60 seconds, the server SHALL send a `{"type": "ping"}` message. If no response is received within 10 seconds, the connection SHALL be closed.

#### Scenario: Idle executor receives ping
- **WHEN** a registered executor has been idle (no messages sent) for 60 seconds
- **THEN** the server SHALL send `{"type": "ping"}` to the executor

#### Scenario: Executor responds to ping
- **WHEN** the server receives `{"type": "pong"}` in response to a ping
- **THEN** the server SHALL reset the idle timer for that executor

#### Scenario: Executor does not respond to ping
- **WHEN** a ping was sent and no response is received within 10 seconds
- **THEN** the server SHALL close the connection and remove the executor from the active list
