## MODIFIED Requirements

### Requirement: Dock panel with code input
The plugin SHALL register an editor dock panel containing a connection status bar at the top, a code input area using a `CodeEdit` control for writing GDScript code, an "Execute" button, a result output area, and an execution history panel at the bottom. The dock SHALL be titled "Hastur Executor" and positioned on the right side of the editor in the same dock group as the Inspector panel (`DOCK_SLOT_RIGHT_UL`). The dock SHALL receive an `ExecutorBackend` reference on initialization and use it for all logic operations.

#### Scenario: Dock visible when plugin enabled
- **WHEN** the HasturOperationGD plugin is enabled
- **THEN** a dock titled "Hastur Executor" SHALL appear in the editor's right panel area in the upper-left dock group (same group as Inspector), showing connection status, code editor, execute button, result area, and history panel

#### Scenario: Dock removed when plugin disabled
- **WHEN** the HasturOperationGD plugin is disabled
- **THEN** the dock SHALL be removed from the editor and its resources freed; the backend SHALL handle broker client disconnection independently

#### Scenario: Dock receives backend reference
- **WHEN** the dock panel is created
- **THEN** it SHALL receive a reference to the `ExecutorBackend` and use it for executing code, reading connection state, and reading history

#### Scenario: Dock without backend reference
- **WHEN** the dock panel is created without a valid backend reference
- **THEN** the dock SHALL display "Disconnected" status and the execute button SHALL have no effect
