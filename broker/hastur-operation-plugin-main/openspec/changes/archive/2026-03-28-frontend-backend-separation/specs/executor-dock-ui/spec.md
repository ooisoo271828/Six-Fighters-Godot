## MODIFIED Requirements

### Requirement: Dock panel with code input
The plugin SHALL register an editor dock panel containing a connection status bar at the top, a code input area using a `CodeEdit` control for writing GDScript code, an "Execute" button, a result output area, and an execution history panel at the bottom. The dock SHALL be titled "Hastur Executor" and positioned on the left side of the editor. The dock SHALL receive an `ExecutorBackend` reference on initialization and use it for all logic operations.

#### Scenario: Dock visible when plugin enabled
- **WHEN** the HasturOperationGD plugin is enabled
- **THEN** a dock titled "Hastur Executor" SHALL appear in the editor's left panel area, showing connection status, code editor, execute button, result area, and history panel

#### Scenario: Dock removed when plugin disabled
- **WHEN** the HasturOperationGD plugin is disabled
- **THEN** the dock SHALL be removed from the editor and its resources freed; the backend SHALL handle broker client disconnection independently

#### Scenario: Dock receives backend reference
- **WHEN** the dock panel is created
- **THEN** it SHALL receive a reference to the `ExecutorBackend` and use it for executing code, reading connection state, and reading history

#### Scenario: Dock without backend reference
- **WHEN** the dock panel is created without a valid backend reference
- **THEN** the dock SHALL display "Disconnected" status and the execute button SHALL have no effect

### Requirement: UI layout
The dock UI SHALL use a `VBoxContainer` as the root layout with the following vertical arrangement: connection status bar (fixed height, showing "Connected"/"Disconnected" and registration ID), `CodeEdit` (expandable, minimum height 200px), `Button` ("Execute") in the middle, `RichTextLabel` (expandable, minimum height 100px) for results, and execution history panel (expandable, minimum height 100px) at the bottom. The dock SHALL be built programmatically (not from a .tscn scene file).

#### Scenario: Layout proportions
- **WHEN** the dock is displayed
- **THEN** the connection status SHALL be fixed at the top, the code input and result output areas SHALL be vertically expandable, with the execute button fixed-height between them, and the history panel SHALL be expandable at the bottom

#### Scenario: Connection status bar layout
- **WHEN** the dock is displayed
- **THEN** the top bar SHALL contain the connection status text (left-aligned) and registration ID label (right-aligned, copyable) on a single line

### Requirement: Execute button delegates to backend
The "Execute" button SHALL call `execute_code()` on the `ExecutorBackend` instead of using a local executor. The result SHALL be displayed in the result output area.

#### Scenario: Execute button pressed
- **WHEN** the user clicks "Execute" with code in the editor
- **THEN** the dock SHALL call `backend.execute_code(code)`, display the result, and the history SHALL be updated via the backend's `execution_completed` signal

### Requirement: Dock subscribes to backend signals
The dock SHALL connect to the backend's `connection_state_changed`, `execution_completed`, and `history_cleared` signals on initialization. The dock SHALL NOT create or manage any `BrokerClient` or `GDScriptExecutor` instances.

#### Scenario: Connection state update
- **WHEN** the backend emits `connection_state_changed(true, "abc-123")`
- **THEN** the dock SHALL update the status label to "Connected" (green) and display "ID: abc-123"

#### Scenario: Connection lost update
- **WHEN** the backend emits `connection_state_changed(false, "")`
- **THEN** the dock SHALL update the status label to "Disconnected" (red) and hide the ID label

#### Scenario: Execution completed updates display
- **WHEN** the backend emits `execution_completed(entry)`
- **THEN** the dock SHALL refresh the history list from `backend.get_history()` and, if the execution was local, display the result in the result area
