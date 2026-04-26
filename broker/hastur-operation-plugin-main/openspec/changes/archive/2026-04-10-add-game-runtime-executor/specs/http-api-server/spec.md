## MODIFIED Requirements

### Requirement: List registered executors endpoint
The HTTP API SHALL provide a `GET /api/executors` endpoint that returns a JSON array of all currently registered Hastur Executor instances. Each executor entry SHALL include `id`, `project_name`, `project_path`, `editor_pid`, `plugin_version`, `editor_version`, `supported_languages`, `connected_at` (ISO 8601 timestamp), `status` ("connected" or "disconnected"), and `type` (`"editor"` or `"game"`).

#### Scenario: Query executors when both editor and game executors are connected
- **WHEN** a `GET /api/executors` request is made and one editor executor and one game executor are registered and connected
- **THEN** the response SHALL be HTTP 200 with body `{"success": true, "data": [{"id": "...", "type": "editor", ...}, {"id": "...", "type": "game", ...}]}`

#### Scenario: Query executors when no executors connected
- **WHEN** a `GET /api/executors` request is made and no executors are registered
- **THEN** the response SHALL be HTTP 200 with body `{"success": true, "data": [], "hint": "No Hastur Executors are currently connected. Ensure the Hastur Executor plugin is enabled in a Godot editor and can reach the broker-server."}`

### Requirement: Execute code endpoint
The HTTP API SHALL provide a `POST /api/execute` endpoint that accepts a JSON body with `code` (required string), and one of `executor_id` (exact match) or `project_name`/`project_path` (fuzzy match). An optional `type` field (`"editor"` or `"game"`) SHALL filter the executor search to only match executors of that type. When no `type` is specified, the search SHALL match executors of any type. When multiple executors match and no `type` filter is given, the first connected result SHALL be returned.

#### Scenario: Execute code by executor ID
- **WHEN** a `POST /api/execute` is made with `{"code": "print(\"hello\")", "executor_id": "<valid-id>"}`
- **THEN** the broker SHALL send the code to the specified executor via TCP and return the execution result

#### Scenario: Execute code by project name with type filter
- **WHEN** a `POST /api/execute` is made with `{"code": "print(\"hello\")", "project_name": "my-game", "type": "game"}`
- **THEN** the broker SHALL find the first connected game executor whose project_name contains "my-game" and forward the code

#### Scenario: Execute code by project name without type filter
- **WHEN** a `POST /api/execute` is made with `{"code": "print(\"hello\")", "project_name": "my-game"}`
- **THEN** the broker SHALL find the first connected executor of any type whose project_name contains "my-game" and forward the code

#### Scenario: No matching executor found with type filter
- **WHEN** a `POST /api/execute` is made with `{"code": "print(\"hello\")", "project_name": "my-game", "type": "game"}`
- **AND** no game executor with that project name is connected
- **THEN** the response SHALL be HTTP 404 with `{"success": false, "error": "No connected Hastur Executor matched the query", "hint": "Use GET /api/executors to list available executors. You can filter by type: \"editor\" or \"game\"."}`

#### Scenario: Missing code field
- **WHEN** a `POST /api/execute` is made without a `code` field
- **THEN** the response SHALL be HTTP 400 with `{"success": false, "error": "Missing required field: code", "hint": "The request body must include a 'code' field (string) containing the GDScript code to execute."}`

#### Scenario: No identifier provided
- **WHEN** a `POST /api/execute` is made with `{"code": "print(\"hello\")"}` but no executor_id, project_name, or project_path
- **THEN** the response SHALL be HTTP 400 with `{"success": false, "error": "No executor identifier provided", "hint": "Provide one of: executor_id (exact match), project_name (fuzzy match), or project_path (fuzzy match) to target a specific executor. Optionally specify type: \"editor\" or \"game\"."}`

#### Scenario: Executor execution timeout
- **WHEN** the executor does not respond within 30 seconds
- **THEN** the response SHALL be HTTP 504 with `{"success": false, "error": "Executor execution timed out (30s)", "hint": "The code execution took too long. Try simplifying the code or check if the executor is responsive."}`
