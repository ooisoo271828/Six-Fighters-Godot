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
