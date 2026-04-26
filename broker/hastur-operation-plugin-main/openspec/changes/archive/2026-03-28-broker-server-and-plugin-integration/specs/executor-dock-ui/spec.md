## MODIFIED Requirements

### Requirement: Dock panel with code input
The plugin SHALL register an editor dock panel containing a connection status bar at the top, a code input area using a `CodeEdit` control for writing GDScript code, an "Execute" button, a result output area, and an execution history panel at the bottom. The dock SHALL be titled "Hastur Executor" and positioned on the left side of the editor.

#### Scenario: Dock visible when plugin enabled
- **WHEN** the HasturOperationGD plugin is enabled
- **THEN** a dock titled "Hastur Executor" SHALL appear in the editor's left panel area, showing connection status, code editor, execute button, result area, and history panel

#### Scenario: Dock removed when plugin disabled
- **WHEN** the HasturOperationGD plugin is disabled
- **THEN** the dock SHALL be removed from the editor and its resources freed, including disconnecting the broker client

### Requirement: UI layout
The dock UI SHALL use a `VBoxContainer` as the root layout with the following vertical arrangement: connection status bar (fixed height, showing "Connected"/"Disconnected" and registration ID), `CodeEdit` (expandable, minimum height 200px), `Button` ("Execute") in the middle, `RichTextLabel` (expandable, minimum height 100px) for results, and execution history panel (expandable, minimum height 100px) at the bottom. The dock SHALL be built programmatically (not from a .tscn scene file).

#### Scenario: Layout proportions
- **WHEN** the dock is displayed
- **THEN** the connection status SHALL be fixed at the top, the code input and result output areas SHALL be vertically expandable, with the execute button fixed-height between them, and the history panel SHALL be expandable at the bottom

#### Scenario: Connection status bar layout
- **WHEN** the dock is displayed
- **THEN** the top bar SHALL contain the connection status text (left-aligned) and registration ID label (right-aligned, copyable) on a single line
