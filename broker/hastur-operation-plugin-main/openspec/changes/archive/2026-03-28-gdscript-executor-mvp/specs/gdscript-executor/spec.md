## ADDED Requirements

### Requirement: Execute code snippet
The executor SHALL accept a GDScript code snippet string and automatically wrap it into a `@tool extends RefCounted` class with a `run()` method containing the user's code. It SHALL set the `executeContext` property on the instance before calling `run()`. After execution, the instance SHALL be released.

#### Scenario: Successful snippet execution
- **WHEN** the executor receives a valid code snippet string (e.g., `print("hello")`) and `executeContext` is an empty Dictionary
- **THEN** the code SHALL be compiled by wrapping into a class, `reload()` SHALL return `OK`, the instance SHALL be created, `executeContext` SHALL be set, `run()` SHALL be called, and the result SHALL indicate compile success and run success with no errors

#### Scenario: Snippet with syntax error
- **WHEN** the executor receives a code snippet with invalid GDScript syntax
- **THEN** `reload()` SHALL return a non-OK Error, and the result SHALL indicate compile failure with the error information

#### Scenario: Snippet with runtime error
- **WHEN** the executor receives a syntactically correct snippet that causes a runtime error during `run()`
- **THEN** the result SHALL indicate compile success but run failure with error information

### Requirement: Execute full class
The executor SHALL accept a complete GDScript class string (containing `extends` keyword) and compile it. The compiled class MUST define a method named `execute(executeContext)`. If the method exists, it SHALL be called with the provided `executeContext` argument. After execution, the instance SHALL be released.

#### Scenario: Successful full class execution
- **WHEN** the executor receives a valid full class string that defines `func execute(executeContext):` and `executeContext` is an empty Dictionary
- **THEN** the code SHALL be compiled, the instance SHALL be created, `execute(executeContext)` SHALL be called, and the result SHALL indicate compile success and run success

#### Scenario: Full class without execute method
- **WHEN** the executor receives a valid full class string that does NOT define a `func execute(executeContext):` method
- **THEN** the result SHALL indicate compile success but run failure with an error message stating that the `execute(executeContext)` method is required

#### Scenario: Full class with syntax error
- **WHEN** the executor receives a full class string with invalid GDScript syntax
- **THEN** `reload()` SHALL return a non-OK Error, and the result SHALL indicate compile failure with error information

### Requirement: Mode detection
The executor SHALL automatically detect the execution mode by checking whether the code string contains an `extends` keyword (outside of comments/strings). If `extends` is found, it SHALL use full class mode; otherwise, it SHALL use snippet mode.

#### Scenario: Code without extends treated as snippet
- **WHEN** the executor receives code that does not contain `extends`
- **THEN** the executor SHALL wrap it as a snippet and execute in snippet mode

#### Scenario: Code with extends treated as full class
- **WHEN** the executor receives code containing `extends`
- **THEN** the executor SHALL compile it directly as a full class and require the `execute` method

### Requirement: Structured result
The executor SHALL return a Dictionary with the following keys: `compile_success` (bool), `compile_error` (String, empty if no error), `run_success` (bool), `run_error` (String, empty if no error).

#### Scenario: Fully successful execution
- **WHEN** code compiles and runs without errors
- **THEN** result SHALL be `{"compile_success": true, "compile_error": "", "run_success": true, "run_error": ""}`

#### Scenario: Compile failure
- **WHEN** code fails to compile
- **THEN** result SHALL be `{"compile_success": false, "compile_error": "<error text>", "run_success": false, "run_error": ""}`

#### Scenario: Run failure
- **WHEN** code compiles but fails at runtime
- **THEN** result SHALL be `{"compile_success": true, "compile_error": "", "run_success": false, "run_error": "<error text>"}`

### Requirement: ExecuteContext injection
Both execution modes SHALL accept an `executeContext` parameter (Dictionary). In snippet mode, it SHALL be set as a property on the instance before `run()` is called. In full class mode, it SHALL be passed as the argument to `execute(executeContext)`.

#### Scenario: Snippet receives executeContext
- **WHEN** a snippet is executed with `executeContext = {"key": "value"}`
- **THEN** the `executeContext` variable SHALL be accessible within the snippet's code with the provided values

#### Scenario: Full class receives executeContext
- **WHEN** a full class is executed with `executeContext = {"key": "value"}`
- **THEN** the `execute(executeContext)` method SHALL receive the Dictionary as its parameter

### Requirement: Memory cleanup
The executor SHALL release all created references (GDScript resource and script instance) after execution completes, whether successful or not. Since both `GDScript` and `RefCounted` instances use reference counting, setting references to `null` SHALL trigger automatic deallocation.

#### Scenario: Cleanup after successful execution
- **WHEN** execution completes successfully
- **THEN** the script instance and GDScript resource references SHALL be set to `null`

#### Scenario: Cleanup after failed execution
- **WHEN** execution fails at compile or run stage
- **THEN** any created references SHALL still be set to `null`
