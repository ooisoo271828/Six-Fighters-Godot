## MODIFIED Requirements

### Requirement: Executor registration with deterministic ID
The TCP server SHALL handle a `register` message from the executor containing `project_name`, `project_path`, `editor_pid`, `plugin_version`, `editor_version`, `supported_languages`, and `type` (required, `"editor"` or `"game"`). The server SHALL compute a deterministic ID using `SHA-256(project_name + "|" + project_path + "|" + editor_pid)`, formatted as a UUID-like string (8-4-4-4-12 hex pattern from the first 32 hex chars). If an executor with the same ID is already registered, the old connection SHALL be replaced.

#### Scenario: New executor registration
- **WHEN** the server receives `{"type": "register", "data": {"project_name": "my-game", "project_path": "/home/user/my-game", "editor_pid": 12345, "plugin_version": "0.1", "editor_version": "4.3", "supported_languages": ["gdscript"], "type": "editor"}}`
- **THEN** the server SHALL compute the deterministic ID, store the executor info including the `type` field, and respond with `{"type": "register_result", "data": {"success": true, "id": "<computed-id>"}}`

#### Scenario: Game executor registration
- **WHEN** the server receives `{"type": "register", "data": {"project_name": "my-game", "project_path": "/home/user/my-game", "editor_pid": 67890, "plugin_version": "0.1", "editor_version": "4.3", "supported_languages": ["gdscript"], "type": "game"}}`
- **THEN** the server SHALL compute the deterministic ID (different from the editor due to different PID), store the executor info with `type: "game"`, and respond with `{"type": "register_result", "data": {"success": true, "id": "<computed-id>"}}`

#### Scenario: Re-registration replaces existing
- **WHEN** an executor registers with the same project_name, project_path, and editor_pid as an already registered executor
- **THEN** the server SHALL close the old TCP connection, update the registration with the new connection, and respond with the same deterministic ID

#### Scenario: Missing registration fields
- **WHEN** the server receives a `register` message missing required fields (including `type`)
- **THEN** the server SHALL respond with `{"type": "register_result", "data": {"success": false, "error": "<description of missing fields>"}}`
