## Requirements

### Requirement: GameExecutor autoload singleton
The plugin SHALL provide a `game_executor.gd` script at `addons/hasturoperationgd/game_executor.gd` that extends `Node`. Users SHALL manually register this script as an Autoload in Project Settings (singleton name: `"GameExecutor"`). The GameExecutor SHALL reuse the existing `BrokerClient`, `GDScriptExecutor`, and `ExecutionContext` classes without modification.

#### Scenario: User manually adds GameExecutor as Autoload
- **WHEN** a user adds `res://addons/hasturoperationgd/game_executor.gd` as an Autoload named `GameExecutor` in Project Settings
- **THEN** the GameExecutor node SHALL be available in the scene tree as `/root/GameExecutor` when the game runs

#### Scenario: User has not added the Autoload
- **WHEN** the user has not registered `game_executor.gd` as an Autoload
- **THEN** no game executor functionality SHALL be present in the running game

### Requirement: Debug-build-only execution guard
The GameExecutor SHALL check `OS.is_debug_build()` in `_ready()`. If the build is not a debug build, the GameExecutor SHALL free itself immediately without connecting to the broker-server.

#### Scenario: Running in debug build
- **WHEN** the game is launched from the editor (debug build) and `OS.is_debug_build()` returns `true`
- **THEN** the GameExecutor SHALL proceed to connect to the broker-server

#### Scenario: Running in release/exported build
- **WHEN** the game is an exported release build and `OS.is_debug_build()` returns `false`
- **THEN** the GameExecutor SHALL call `queue_free()` on itself and SHALL NOT connect to the broker-server

### Requirement: Broker connection and registration
The GameExecutor SHALL connect to the broker-server using the configured `hastur_operation/broker_host` and `hastur_operation/broker_port` project settings. Upon connection, it SHALL send a `register` message with `type: "game"` to identify itself as a game runtime executor.

#### Scenario: GameExecutor connects and registers
- **WHEN** the game starts in debug mode and the broker-server is reachable
- **THEN** the GameExecutor SHALL connect via TCP, send a registration with `type: "game"`, project metadata, and the game process PID
- **THEN** the GameExecutor SHALL receive and store its executor ID

#### Scenario: Broker-server unreachable on game start
- **WHEN** the game starts and the broker-server is not reachable
- **THEN** the GameExecutor SHALL retry connection with exponential backoff without blocking the game

### Requirement: Remote code execution in game runtime
The GameExecutor SHALL receive `execute` messages from the broker-server, execute the provided GDScript code using `GDScriptExecutor`, and return the results via the broker-server.

#### Scenario: Execute code in running game
- **WHEN** the GameExecutor receives `{"type": "execute", "data": {"request_id": "...", "code": "executeContext.output(\"fps\", Engine.get_frames_per_second())", "language": "gdscript"}}`
- **THEN** the GameExecutor SHALL execute the code in the game process context and return the result including any outputs

#### Scenario: Code accesses game scene tree
- **WHEN** an agent sends code like `get_tree().current_scene` through the GameExecutor
- **THEN** the code SHALL execute with full access to the game's scene tree, nodes, and runtime state

### Requirement: Graceful shutdown on game exit
The GameExecutor SHALL cleanly disconnect from the broker-server when the game process is exiting, by handling `NOTIFICATION_WM_CLOSE_REQUEST` and `NOTIFICATION_PREDELETE_CLEANUP` to prevent ghost executor entries.

#### Scenario: Game closes normally
- **WHEN** the game window is closed or the game stops
- **THEN** the GameExecutor SHALL disconnect from the broker-server before the process exits

#### Scenario: Game crashes
- **WHEN** the game process crashes unexpectedly
- **THEN** the broker-server SHALL detect the disconnection via the existing heartbeat timeout mechanism
