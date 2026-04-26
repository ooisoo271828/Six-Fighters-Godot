## MODIFIED Requirements

### Requirement: History entry display format
Each history entry in the list SHALL display: a status text indicator first (`[OK]` or `[FAIL]`), the execution timestamp, the execution duration in milliseconds, and the execution source (`local` or `remote`). The code preview text SHALL NOT be displayed in the history list item; the full code is available by selecting the entry. The display format SHALL be `[STATUS] HH:MM:SS - Nms (source)`. Successful entries (compile and run both succeeded) SHALL display the item text in green (`Color.GREEN`). Failed entries (compile failure or run failure) SHALL display the item text in red (`Color.RED`).

#### Scenario: Successful entry display
- **WHEN** a history entry exists for code that executed successfully in 45ms at 14:30:05 locally
- **THEN** the history list SHALL show `[OK] 14:30:05 - 45ms (local)` with green foreground color

#### Scenario: Failed entry display
- **WHEN** a history entry exists for code with a syntax error that failed at 14:31:10 locally in 12ms
- **THEN** the history list SHALL show `[FAIL] 14:31:10 - 12ms (local)` with red foreground color

#### Scenario: Remote execution entry
- **WHEN** a history entry exists for remotely executed code that succeeded in 120ms at 15:00:00
- **THEN** the history list SHALL show `[OK] 15:00:00 - 120ms (remote)` with green foreground color

#### Scenario: Code preview not shown in list
- **WHEN** a history entry exists for code `var x = 1 + 2`
- **THEN** the history list item text SHALL NOT contain `var x = 1 + 2` or any portion of the code
