## MODIFIED Requirements

### Requirement: Registration handshake
Upon connecting, the Hastur Executor SHALL send a `register` message containing `project_name` (from ProjectSettings), `project_path` (from `ProjectSettings.globalize_path("res://")`), `editor_pid` (from `OS.get_process_id()`), `plugin_version` (from plugin.cfg), `editor_version` (from `Engine.get_version_info()`), `supported_languages` (`["gdscript"]`), and `type` (`"editor"` for the editor plugin, `"game"` for the GameExecutor autoload).

#### Scenario: Successful registration from editor
- **WHEN** the editor plugin client sends a valid register message with `type: "editor"` and the server responds with `{"type": "register_result", "data": {"success": true, "id": "<uuid>"}}`
- **THEN** the client SHALL store the registration ID and emit a connection established signal

#### Scenario: Successful registration from game executor
- **WHEN** the GameExecutor client sends a valid register message with `type: "game"` and the server responds with `{"type": "register_result", "data": {"success": true, "id": "<uuid>"}}`
- **THEN** the client SHALL store the registration ID and emit a connection established signal

#### Scenario: Registration failure
- **WHEN** the server responds with `{"type": "register_result", "data": {"success": false, "error": "..."}}`
- **THEN** the client SHALL log the error and retry registration after a delay
