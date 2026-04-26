## ADDED Requirements

### Requirement: Bearer token authentication
All HTTP API endpoints SHALL require a valid Bearer token in the `Authorization` header. Requests without a valid token SHALL receive a 401 response with a JSON body containing `success: false`, an error message, and a `hint` field guiding correct authentication.

#### Scenario: Valid auth token provided
- **WHEN** a request includes `Authorization: Bearer <valid-token>`
- **THEN** the request SHALL be processed normally

#### Scenario: Missing auth header
- **WHEN** a request is made without an `Authorization` header
- **THEN** the response SHALL be HTTP 401 with body `{"success": false, "error": "Authentication required", "hint": "Include an Authorization header with Bearer token: Authorization: Bearer <token>. The token was printed when the broker-server started."}`

#### Scenario: Invalid auth token
- **WHEN** a request includes an incorrect Bearer token
- **THEN** the response SHALL be HTTP 401 with body `{"success": false, "error": "Invalid authentication token", "hint": "Check the auth token. It was printed when the broker-server started with --auth-token or auto-generated."}`

### Requirement: List registered executors endpoint
The HTTP API SHALL provide a `GET /api/executors` endpoint that returns a JSON array of all currently registered Hastur Executor instances. Each executor entry SHALL include `id`, `project_name`, `project_path`, `editor_pid`, `plugin_version`, `editor_version`, `supported_languages`, `connected_at` (ISO 8601 timestamp), and `status` ("connected" or "disconnected").

#### Scenario: Query executors when executors are connected
- **WHEN** a `GET /api/executors` request is made and two executors are registered and connected
- **THEN** the response SHALL be HTTP 200 with body `{"success": true, "data": [{"id": "...", "project_name": "...", ...}, {"id": "...", ...}]}`

#### Scenario: Query executors when no executors connected
- **WHEN** a `GET /api/executors` request is made and no executors are registered
- **THEN** the response SHALL be HTTP 200 with body `{"success": true, "data": [], "hint": "No Hastur Executors are currently connected. Ensure the Hastur Executor plugin is enabled in a Godot editor and can reach the broker-server."}`

### Requirement: Execute code endpoint
The HTTP API SHALL provide a `POST /api/execute` endpoint that accepts a JSON body with `code` (required string), and one of `executor_id` (exact match) or `project_name`/`project_path` (fuzzy match, first connected result). The endpoint SHALL forward the code to the matched executor via TCP, wait for the execution result, and return it as JSON.

#### Scenario: Execute code by executor ID
- **WHEN** a `POST /api/execute` is made with `{"code": "print(\"hello\")", "executor_id": "<valid-id>"}`
- **THEN** the broker SHALL send the code to the specified executor via TCP and return the execution result as `{"success": true, "data": {"compile_success": true, "compile_error": "", "run_success": true, "run_error": "", "outputs": [...]}}`

#### Scenario: Execute code by project name fuzzy match
- **WHEN** a `POST /api/execute` is made with `{"code": "print(\"hello\")", "project_name": "my-game"}`
- **THEN** the broker SHALL find the first connected executor whose project_name contains "my-game" (case-insensitive) and forward the code

#### Scenario: Execute code by project path fuzzy match
- **WHEN** a `POST /api/execute` is made with `{"code": "print(\"hello\")", "project_path": "/home/user/my"}`
- **THEN** the broker SHALL find the first connected executor whose project_path contains the given substring (case-insensitive) and forward the code

#### Scenario: No matching executor found
- **WHEN** a `POST /api/execute` is made with `{"code": "print(\"hello\")", "executor_id": "nonexistent"}`
- **THEN** the response SHALL be HTTP 404 with `{"success": false, "error": "No connected Hastur Executor matched the query", "hint": "Use GET /api/executors to list available executors. You can match by executor_id (exact) or project_name/project_path (fuzzy substring match)."}`

#### Scenario: Missing code field
- **WHEN** a `POST /api/execute` is made without a `code` field
- **THEN** the response SHALL be HTTP 400 with `{"success": false, "error": "Missing required field: code", "hint": "The request body must include a 'code' field (string) containing the GDScript code to execute. Example: {\"code\": \"print(\\\"hello\\\")\"}"}`

#### Scenario: No identifier provided
- **WHEN** a `POST /api/execute` is made with `{"code": "print(\"hello\")"}` but no executor_id, project_name, or project_path
- **THEN** the response SHALL be HTTP 400 with `{"success": false, "error": "No executor identifier provided", "hint": "Provide one of: executor_id (exact match), project_name (fuzzy match), or project_path (fuzzy match) to target a specific Godot editor. Use GET /api/executors to see connected editors."}`

#### Scenario: Executor execution timeout
- **WHEN** the executor does not respond within 30 seconds
- **THEN** the response SHALL be HTTP 504 with `{"success": false, "error": "Executor execution timed out (30s)", "hint": "The code execution took too long. Try simplifying the code or check if the Godot editor is responsive."}`

### Requirement: AI-agent-friendly error responses
All HTTP API error responses SHALL include a `hint` field with actionable guidance. The `success` field SHALL always be present. Response structure SHALL be `{"success": boolean, "error"?: string, "hint"?: string, "data"?: object}`.

#### Scenario: 404 route not found
- **WHEN** a request is made to an undefined route
- **THEN** the response SHALL be HTTP 404 with `{"success": false, "error": "Route not found", "hint": "Available endpoints: GET /api/executors - List connected Hastur Executors, POST /api/execute - Execute code on a Hastur Executor"}`

#### Scenario: Method not allowed
- **WHEN** a `POST` request is made to `/api/executors`
- **THEN** the response SHALL be HTTP 405 with `{"success": false, "error": "Method not allowed", "hint": "GET /api/executors to list executors, POST /api/execute to execute code"}`

### Requirement: Health check endpoint
The HTTP API SHALL provide a `GET /api/health` endpoint that returns server status without requiring authentication.

#### Scenario: Health check
- **WHEN** a `GET /api/health` request is made
- **THEN** the response SHALL be HTTP 200 with `{"success": true, "data": {"status": "ok", "tcp_port": <port>, "http_port": <port>, "executors_connected": <count>}}`
