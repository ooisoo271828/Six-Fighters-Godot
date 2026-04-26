## ADDED Requirements

### Requirement: ExecutionContext object with output method
The executor SHALL create an `ExecutionContext` object (inheriting RefCounted) that provides an `output(key: String, value: String)` method. This object SHALL be passed as the `executeContext` parameter to user code in both snippet mode and full class mode, replacing the previous plain Dictionary.

#### Scenario: Output method collects key-value pairs
- **WHEN** user code calls `executeContext.output("result", str(42))`
- **THEN** the ExecutionContext SHALL store the entry `["result", "42"]` in its internal outputs array

#### Scenario: Multiple output calls
- **WHEN** user code calls `executeContext.output("a", "1")` and then `executeContext.output("b", "2")`
- **THEN** the ExecutionContext SHALL store both entries in order: `[["a", "1"], ["b", "2"]]`

### Requirement: Output value character limit and truncation
The ExecutionContext SHALL enforce a maximum character length for each output value. When a value exceeds the limit, the value SHALL be truncated and prefixed with an English truncation warning. The warning SHALL follow the format: `[TRUNCATED: Output exceeded {max_length} char limit. Refine output to be more focused. Actual length: {actual_length}] `. The total length of the warning plus the truncated value SHALL NOT exceed the configured maximum.

#### Scenario: Value within limit
- **WHEN** `output("key", "short value")` is called with max char length 800 and the value is 11 characters
- **THEN** the value SHALL be stored as-is without any modification

#### Scenario: Value exceeds limit
- **WHEN** `output("key", <900-char string>)` is called with max char length 800
- **THEN** the value SHALL be truncated so that the truncation warning prefix plus the remaining value content equals exactly the max char length, and the warning SHALL indicate the actual length was 900

### Requirement: Outputs in execution result
The executor SHALL include an `outputs` key in the returned result Dictionary. The value SHALL be an Array of Arrays, where each inner array contains exactly two elements: `[key, value]` (both Strings). This replaces the previous Dictionary-only executeContext.

#### Scenario: Execution with outputs
- **WHEN** code executes successfully and calls `executeContext.output("x", "hello")` and `executeContext.output("y", "world")`
- **THEN** the result Dictionary SHALL contain `"outputs": [["x", "hello"], ["y", "world"]]` along with existing compile/run status fields

#### Scenario: Execution without any output calls
- **WHEN** code executes successfully without calling `executeContext.output()`
- **THEN** the result Dictionary SHALL contain `"outputs": []`

#### Scenario: Outputs preserved on runtime error
- **WHEN** code calls `executeContext.output("a", "1")` and then causes a runtime error
- **THEN** the result Dictionary SHALL still contain the collected outputs `[["a", "1"]]` along with the run error information

## MODIFIED Requirements

### Requirement: Structured result
The executor SHALL return a Dictionary with the following keys: `compile_success` (bool), `compile_error` (String, empty if no error), `run_success` (bool), `run_error` (String, empty if no error), `outputs` (Array of [key, value] pairs, empty Array if no outputs).

#### Scenario: Fully successful execution
- **WHEN** code compiles and runs without errors and no output calls are made
- **THEN** result SHALL be `{"compile_success": true, "compile_error": "", "run_success": true, "run_error": "", "outputs": []}`

#### Scenario: Compile failure
- **WHEN** code fails to compile
- **THEN** result SHALL be `{"compile_success": false, "compile_error": "<error text>", "run_success": false, "run_error": "", "outputs": []}`

#### Scenario: Run failure
- **WHEN** code compiles but fails at runtime
- **THEN** result SHALL be `{"compile_success": true, "compile_error": "", "run_success": false, "run_error": "<error text>", "outputs": <collected outputs before failure>}`

### Requirement: ExecuteContext injection
Both execution modes SHALL accept an `ExecutionContext` object (inheriting RefCounted) that provides an `output(key, value)` method. In snippet mode, it SHALL be set as a property on the instance before `run()` is called. In full class mode, it SHALL be passed as the argument to `execute(executeContext)`. The ExecutionContext SHALL read its `max_output_char_length` from `ProjectSettings.get_setting("hastur_operation/output_max_char_length", 800)`.

#### Scenario: Snippet receives ExecutionContext
- **WHEN** a snippet is executed
- **THEN** the `executeContext` variable SHALL be an ExecutionContext object with an accessible `output()` method

#### Scenario: Full class receives ExecutionContext
- **WHEN** a full class is executed
- **THEN** the `execute(executeContext)` method SHALL receive the ExecutionContext object as its parameter
