## Context

The Hastur Operation GD plugin currently uses `executor_dock.gd` (a `Control` UI node) as the central hub for both UI rendering and backend logic. It creates and owns the `BrokerClient` (TCP connection to broker-server), a `GDScriptExecutor` (for local code execution), and manages execution history. The plugin entry point (`hasturoperationgd.gd`) merely creates the dock and performs cleanup by reaching back into it.

This tight coupling means:
- The broker client only runs when the dock panel exists
- No remote commands can be received without the UI being instantiated
- Cleanup logic in the plugin entry point is awkward (accessing dock internals via `_get_broker_client()`)
- The architecture cannot support headless operation or future alternative frontends

## Goals / Non-Goals

**Goals:**
- Separate backend logic (broker connection, code execution, history management) from UI (dock panel)
- Enable the broker client to run independently of the dock panel, receiving remote commands in the background
- Make the dock panel a pure view layer that subscribes to backend signals for display-only updates
- Manage the backend lifecycle at the plugin entry point level

**Non-Goals:**
- Changing the broker-server protocol or TCP message format
- Changing the GDScriptExecutor execution engine
- Adding new UI features or changing the dock layout
- Persisting execution history across sessions
- Supporting multiple dock panels or multiple broker connections

## Decisions

### Decision 1: ExecutorBackend as a Node (not RefCounted)

**Choice**: `ExecutorBackend` extends `Node` rather than `RefCounted`.

**Rationale**: The backend needs a `_process()` callback to drive the `BrokerClient.poll()` state machine. By extending `Node`, it receives process notifications naturally from the scene tree without manual polling setup. The plugin entry point adds it as a child, so it inherits the processing lifecycle.

**Alternative considered**: Extending `RefCounted` and requiring the plugin to manually call `poll()` in its own `_process()`. This adds unnecessary boilerplate and creates a manual lifecycle management burden. Using `Node` is more idiomatic in Godot for objects that need frame-by-frame processing.

### Decision 2: Backend owns both BrokerClient and GDScriptExecutor

**Choice**: The `ExecutorBackend` owns a single `GDScriptExecutor` and the `BrokerClient`. The dock panel no longer creates its own executor — it calls `backend.execute_code(code)` for local execution.

**Rationale**: Currently there are two separate `GDScriptExecutor` instances (one in the dock for local execution, one inside `BrokerClient` for remote execution). Consolidating to one executor owned by the backend (for local execution) while the `BrokerClient` continues to own its own executor (for remote execution) preserves the existing behavior while simplifying ownership. The dock delegates local execution to the backend.

**Alternative considered**: Having the backend share a single executor between local and remote execution. This introduces concurrency concerns (what if a remote execution is in progress when the user clicks Execute?) and was deemed unnecessary complexity.

### Decision 3: Backend manages execution history

**Choice**: The `ExecutorBackend` stores execution history in memory (same 50-entry limit as before) and exposes it via a getter. It emits a signal when history changes so the dock can refresh.

**Rationale**: History is a backend concern (it tracks what happened) rather than a UI concern. Moving it to the backend means history accumulates even if the dock panel is recreated or doesn't exist. The dock simply reads and displays it.

### Decision 4: Signal-based communication between backend and dock

**Choice**: The backend emits signals (`connection_state_changed(connected: bool, id: String)`, `execution_completed(entry: Dictionary)`, `history_cleared()`). The dock connects to these signals on initialization.

**Rationale**: Godot's signal system is the idiomatic way to decouple producers from consumers. The backend doesn't know about the dock; the dock knows about the backend. This is a unidirectional dependency that allows the backend to run without any UI.

### Decision 5: Plugin entry point orchestrates lifecycle

**Choice**: `hasturoperationgd.gd` creates the `ExecutorBackend` in `_enter_tree()` and frees it in `_exit_tree()`. The dock is created after the backend and receives a reference to it.

**Rationale**: The plugin entry point is the natural lifecycle owner. It's already responsible for creating and destroying the dock. Moving backend creation here ensures the backend outlives any specific UI component.

## Risks / Trade-offs

- **Risk**: Adding a `Node` to the EditorPlugin means it participates in the scene tree, which may have subtle lifecycle implications (e.g., `_process` timing relative to the dock). → **Mitigation**: The backend is added as a direct child of the plugin, so its `_process` runs at the same timing as the current dock-based polling. No behavior change expected.

- **Risk**: The dock needs a reference to the backend, creating a runtime dependency that could be null if setup order changes. → **Mitigation**: The backend is created before the dock and passed via constructor/initializer. If the reference is null, the dock simply shows a disconnected state.

- **Trade-off**: The `BrokerClient` still owns its own `GDScriptExecutor` for remote execution, maintaining two executor instances. This is intentional to avoid concurrency issues, but means slightly more memory usage.
