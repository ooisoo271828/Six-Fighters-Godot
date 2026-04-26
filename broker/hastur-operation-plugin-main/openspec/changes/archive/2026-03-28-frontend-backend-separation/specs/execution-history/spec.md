## MODIFIED Requirements

### Requirement: Execution history list
The executor dock SHALL display an execution history panel below the result output area. History data SHALL be managed by the `ExecutorBackend`. The dock SHALL read history entries from `backend.get_history()`. Each history entry SHALL show: the executed code (truncated if long), compilation result, run result, outputs summary, execution timestamp, and execution duration.

#### Scenario: History entry after successful local execution
- **WHEN** the user executes code locally and it succeeds
- **THEN** the backend SHALL add a history entry and the dock SHALL refresh its display from `backend.get_history()`, showing the code, compile success, run success, outputs, timestamp, and duration

#### Scenario: History entry after failed local execution
- **WHEN** the user executes code locally and it fails to compile
- **THEN** the backend SHALL add a history entry and the dock SHALL refresh, showing the code, compile failure with error, "(skipped)" for run result, timestamp, and duration

#### Scenario: History entry after remote execution
- **WHEN** code is executed remotely via the broker-server
- **THEN** the backend SHALL add a history entry and the dock SHALL refresh with a "Remote" label, showing the same fields as a local execution entry

### Requirement: Maximum history entries
The execution history SHALL maintain a maximum of 50 entries in the backend. When the limit is reached, the oldest entry SHALL be removed when a new one is added.

#### Scenario: History at capacity
- **WHEN** there are 50 history entries and a new execution completes
- **THEN** the oldest (first) entry SHALL be removed in the backend and the new entry SHALL be appended

#### Scenario: History below capacity
- **WHEN** there are fewer than 50 history entries and a new execution completes
- **THEN** the new entry SHALL be appended without removing any existing entries

### Requirement: Runtime-only storage
The execution history SHALL be stored only in memory during the editor session in the backend. No file I/O or persistence SHALL be performed. History SHALL be cleared when the backend is freed.

#### Scenario: Plugin disable clears history
- **WHEN** the plugin is disabled
- **THEN** the backend SHALL be freed and all history entries SHALL be discarded

#### Scenario: Editor restart clears history
- **WHEN** the Godot editor is restarted
- **THEN** the history SHALL be empty on the next session

### Requirement: Clear history button
The executor dock SHALL provide a button labeled "Clear History" that calls `backend.clear_history()` when clicked.

#### Scenario: Clear history
- **WHEN** the user clicks "Clear History" and there are 25 history entries
- **THEN** the dock SHALL call `backend.clear_history()`, the backend SHALL remove all entries and emit `history_cleared`, and the dock SHALL clear its history list

#### Scenario: Clear empty history
- **WHEN** the user clicks "Clear History" and there are no history entries
- **THEN** the dock SHALL call `backend.clear_history()` and nothing visible SHALL change

### Requirement: History entry selection
The execution history panel SHALL allow selecting a history entry. When an entry is selected, the code content and result SHALL be displayed in the main code editor and result area respectively, allowing re-execution.

#### Scenario: Select history entry
- **WHEN** the user clicks on a history entry showing `print("hello")`
- **THEN** the code editor SHALL be populated with `print("hello")` and the result area SHALL show the execution result from that entry

### Requirement: History entry display format
Each history entry in the list SHALL display: a truncated code preview (first line, max 60 characters), a status icon or text (success/fail), the execution timestamp, and the execution duration in milliseconds.

#### Scenario: Successful entry display
- **WHEN** a history entry exists for code `print("hello")` that executed successfully in 45ms at 14:30:05
- **THEN** the history list SHALL show `print("hello")`, a success indicator, `14:30:05`, and `45ms`

#### Scenario: Failed entry display
- **WHEN** a history entry exists for code with a syntax error that failed at 14:31:10
- **THEN** the history list SHALL show the code preview, a failure indicator, `14:31:10`, and the duration

#### Scenario: Long code truncation
- **WHEN** a history entry has code spanning multiple lines or exceeding 60 characters on the first line
- **THEN** the preview SHALL show the first line truncated to 60 characters with "..." appended
