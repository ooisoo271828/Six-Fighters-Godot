## ADDED Requirements

### Requirement: Dock panel with code input
The plugin SHALL register an editor dock panel containing a code input area using a `CodeEdit` control for writing GDScript code. The dock SHALL be titled "Hastur Executor" and positioned on the left side of the editor.

#### Scenario: Dock visible when plugin enabled
- **WHEN** the HasturOperationGD plugin is enabled
- **THEN** a dock titled "Hastur Executor" SHALL appear in the editor's left panel area

#### Scenario: Dock removed when plugin disabled
- **WHEN** the HasturOperationGD plugin is disabled
- **THEN** the dock SHALL be removed from the editor and its resources freed

### Requirement: Execute button
The dock SHALL contain a button labeled "Execute" that triggers code execution when clicked. The button SHALL use the GDScript executor to run the code currently in the code input area.

#### Scenario: Button triggers execution
- **WHEN** the user clicks the "Execute" button
- **THEN** the code in the input area SHALL be passed to the executor, and the result SHALL be displayed in the output area

#### Scenario: Empty code input
- **WHEN** the user clicks "Execute" with empty code input
- **THEN** the result area SHALL show a compile failure with an appropriate error message

### Requirement: Result output area
The dock SHALL contain a `RichTextLabel` control that displays the execution result. The result SHALL show compile status, compile errors (if any), run status, and run errors (if any) in a human-readable format.

#### Scenario: Display successful result
- **WHEN** code executes successfully
- **THEN** the output area SHALL display "Compile: SUCCESS" and "Run: SUCCESS"

#### Scenario: Display compile error
- **WHEN** code fails to compile
- **THEN** the output area SHALL display "Compile: FAILED" followed by the error text, and "Run: (skipped)"

#### Scenario: Display runtime error
- **WHEN** code compiles but fails at runtime
- **THEN** the output area SHALL display "Compile: SUCCESS" and "Run: FAILED" followed by the error text

### Requirement: UI layout
The dock UI SHALL use a `VBoxContainer` as the root layout with the following vertical arrangement: `CodeEdit` (expandable, minimum height 200px) at top, `Button` ("Execute") in the middle, `RichTextLabel` (expandable, minimum height 100px) at bottom. The dock SHALL be built programmatically (not from a .tscn scene file).

#### Scenario: Layout proportions
- **WHEN** the dock is displayed
- **THEN** the code input and result output areas SHALL be vertically expandable, with the execute button fixed-height between them
