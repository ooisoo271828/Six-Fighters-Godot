export interface ExecutorInfo {
	id: string
	project_name: string
	project_path: string
	editor_pid: number
	plugin_version: string
	editor_version: string
	supported_languages: string[]
	connected_at: string
	status: 'connected' | 'disconnected' | 'reconnecting'
	type: 'editor' | 'game'
	last_heartbeat: string
	reconnect_count: number
}

export interface ConnectionMetrics {
	executor_id: string
	connected_at: string
	last_message_at: string
	last_heartbeat_sent: string
	last_heartbeat_received: string
	idle_seconds: number
	reconnect_count: number
	rtt_ms: number | null
}

export interface TcpMessage {
	type: string
	data?: unknown
}

export interface ExecuteRequest {
	request_id: string
	code: string
	language: string
}

export interface ExecuteResult {
	request_id: string
	compile_success: boolean
	compile_error: string
	run_success: boolean
	run_error: string
	outputs: [string, string][]
}

export interface ApiResponse {
	success: boolean
	error?: string
	hint?: string
	data?: unknown
}

export interface Breakpoint {
	id: string
	file: string
	line: number
	condition?: string
	enabled: boolean
	hit_count: number
	created_at: string
}

export interface BreakpointHit {
	breakpoint_id: string
	file: string
	line: number
	variables: Record<string, unknown>
}

export interface LogEntry {
	id: string
	type: 'compile_error' | 'runtime_error' | 'script_error' | 'warning' | 'output'
	timestamp: string
	timestamp_ms: number
	message: string
	source: string
	stack: Array<{ file?: string; line?: number; function?: string; raw?: string }>
	count: number
	output_type?: string
	script_path?: string
	line_number?: number
	error_code?: string
}

export interface LogStore {
	executorId: string
	logs: LogEntry[]
	lastUpdated: string
}

export interface RescanResult {
	request_id: string
	success: boolean
	scanned: boolean
	error?: string
}

export interface ScriptCheckResult {
	request_id: string
	compile_success: boolean
	method_count: number
	errors: Array<{ line: number; column: number; message: string; file: string }>
	compile_error?: string
}

export interface ScenePropertiesResult {
	request_id: string
	success: boolean
	node_path: string
	node_type: string
	property_count: number
	properties: Record<string, unknown>
	error?: string
}

export interface SceneSaveResult {
	request_id: string
	success: boolean
	saved: boolean
	path: string
	error?: string
}

export interface ExecuteSummary {
	compile_ok: boolean
	run_ok: boolean
	error_count: number
	first_error: { message: string; line: number | null } | null
	output_count: number
}

// ── v0.6.0 Scene Diagnostics ──

export interface SignalConnectionInfo {
	node_path: string
	signal_name: string
	connected_to: string
	method: string
	flags: number
	binds: unknown[]
}

export interface NodeSnapshot {
	name: string
	type: string
	script?: string
	children?: NodeSnapshot[]
	properties?: Record<string, unknown>
	signals?: Record<string, SignalConnectionInfo[]>
}

export interface SceneInspectQuery {
	request_id: string
	path: string
	depth: number
	include_children: boolean
	include_properties: boolean
	include_signals: boolean
	property_filter?: string
}

export interface SceneInspectResult {
	request_id: string
	success: boolean
	node: NodeSnapshot | null
	error?: string
	truncated?: boolean
}

export interface SignalConnectionResult {
	request_id: string
	success: boolean
	node_path: string
	signal_count: number
	signals: Record<string, SignalConnectionInfo[]>
	error?: string
}

// ── v0.6.0 Compile Errors ──

export interface CompileError {
	timestamp_ms: number
	file: string
	line: number
	column: number
	message: string
	code: string
	type: string
}

export interface CompileErrorListResult {
	request_id: string
	success: boolean
	error_count: number
	errors: CompileError[]
}

// ── v0.6.0 Console Stream ──

export interface ConsoleEntry {
	timestamp_ms: number
	type: string
	message: string
}

export interface ConsoleStreamResult {
	request_id: string
	success: boolean
	entries: ConsoleEntry[]
	next_timestamp_ms: number
}

// ── v0.6.0 Script Reload ──

export interface ScriptReloadRequest {
	request_id: string
	path: string
}

export interface ScriptReloadResult {
	request_id: string
	success: boolean
	reloaded: boolean
	compile_success: boolean
	method_count: number
	error?: string
	errors?: Array<{ line: number; column: number; message: string }>
}
