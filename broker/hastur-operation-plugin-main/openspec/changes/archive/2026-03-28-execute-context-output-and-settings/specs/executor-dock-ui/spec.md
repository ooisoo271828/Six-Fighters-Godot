## MODIFIED Requirements

### Requirement: Result output area
The dock SHALL contain a `RichTextLabel` control that displays the execution result. The result SHALL show compile status, compile errors (if any), run status, and run errors (if any) in a human-readable format. When outputs are present, the result SHALL also display an `Output:` section after the run status, listing each output entry as `key: value` on its own line.

#### Scenario: Display successful result with outputs
- **WHEN** code executes successfully with outputs `[["a", "2"], ["b", "3"]]`
- **THEN** the output area SHALL display "Compile: SUCCESS", "Run: SUCCESS", "---", "Output:", "a: 2", "b: 3"

#### Scenario: Display successful result without outputs
- **WHEN** code executes successfully without any output calls
- **THEN** the output area SHALL display "Compile: SUCCESS" and "Run: SUCCESS" (no Output section)

#### Scenario: Display compile error
- **WHEN** code fails to compile
- **THEN** the output area SHALL display "Compile: FAILED" followed by the error text, and "Run: (skipped)"

#### Scenario: Display runtime error with collected outputs
- **WHEN** code compiles but fails at runtime after collecting some outputs
- **THEN** the output area SHALL display "Compile: SUCCESS", "Run: FAILED" with the error, "---", "Output:", and the collected key-value pairs

#### Scenario: Display runtime error without outputs
- **WHEN** code compiles but fails at runtime without any output calls
- **THEN** the output area SHALL display "Compile: SUCCESS" and "Run: FAILED" followed by the error text (no Output section)
