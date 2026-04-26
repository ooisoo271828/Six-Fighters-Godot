import * as net from 'net'
import * as crypto from 'crypto'
import { ExecutorManager } from './executor-manager.js'
import type { ExecutorInfo, TcpMessage, ExecuteResult, Breakpoint, LogEntry } from './types.js'

// ============ 配置常量 ============
const MAX_LOG_ENTRIES = 1000           // 每个 executor 最多保存的日志条数
const MAX_CONNECTIONS = 100             // 最大并发连接数
const MAX_PENDING_REQUESTS = 200       // 每个连接最大待处理请求数
const SOCKET_KEEPALIVE = true          // 启用 TCP keep-alive
const SOCKET_KEEPALIVE_INITIAL_DELAY = 30000  // 30秒后开始探测
const MAX_LINE_LENGTH = 1024 * 1024    // 单行消息最大长度（1MB）

interface PendingRequest {
	resolve: (result: Record<string, unknown>) => void
	reject: (error: Error) => void
	timer: ReturnType<typeof setTimeout>
}

interface ConnectionContext {
	socket: net.Socket
	executorId: string | null
	lastMessageTime: number
	lastHeartbeatSent: number | null
	lastHeartbeatReceived: number | null
	pingSent: boolean
	pingSentTime: number | null
	buffer: string
	pendingRequests: Map<string, PendingRequest>
	reconnectCount: number
	connectedAt: number
}

export class TcpServer {
	private server: net.Server | null = null
	private executorManager: ExecutorManager
	private connections: Map<string, ConnectionContext> = new Map()
	private heartbeatInterval: ReturnType<typeof setInterval> | null = null
	private breakpoints: Map<string, Breakpoint> = new Map()
	private logs: Map<string, LogEntry[]> = new Map()  // executorId -> logs
	private connectionCount: number = 0  // 当前连接数统计

	constructor(executorManager: ExecutorManager) {
		this.executorManager = executorManager
	}

	async start(host: string, port: number): Promise<void> {
		this.server = net.createServer((socket) => this.handleConnection(socket))

		// 安全增强：TCP socket 选项
		this.server.on('connection', (socket: net.Socket) => {
			// 禁用 Nagle 算法，降低延迟
			socket.setNoDelay(true)

			// TCP keep-alive 检测死连接
			if (SOCKET_KEEPALIVE) {
				socket.setKeepAlive(SOCKET_KEEPALIVE, SOCKET_KEEPALIVE_INITIAL_DELAY)
			}
		})

		return new Promise((resolve) => {
			this.server!.listen(port, host, () => {
				this.startHeartbeatCheck()
				console.log(`[TCP] Server configured with max connections: ${MAX_CONNECTIONS}`)
				resolve()
			})
		})
	}

	async stop(): Promise<void> {
		if (this.heartbeatInterval) {
			clearInterval(this.heartbeatInterval)
			this.heartbeatInterval = null
		}

		for (const [, ctx] of this.connections) {
			for (const [, pending] of ctx.pendingRequests) {
				clearTimeout(pending.timer)
				pending.reject(new Error('Server shutting down'))
			}
			ctx.socket.destroy()
		}
		this.connections.clear()

		if (this.server) {
			return new Promise((resolve) => {
				this.server!.close(() => resolve())
			})
		}
	}

	sendExecute(executorId: string, code: string, language: string, timeoutMs: number = 30000): Promise<ExecuteResult> {
		for (const [, ctx] of this.connections) {
			if (ctx.executorId === executorId) {
				const requestId = crypto.randomUUID()
				const message = JSON.stringify({
					type: 'execute',
					data: { request_id: requestId, code, language },
				}) + '\n'

				return new Promise((resolve, reject) => {
					const timer = setTimeout(() => {
						ctx.pendingRequests.delete(requestId)
						reject(new Error('TIMEOUT'))
					}, timeoutMs)

					ctx.pendingRequests.set(requestId, { resolve, reject, timer })
					ctx.socket.write(message)
				})
			}
		}
		return Promise.reject(new Error('Executor not connected'))
	}

	// 场景树请求
	sendSceneTreeRequest(executorId: string, timeoutMs: number = 10000): Promise<Record<string, unknown>> {
		for (const [, ctx] of this.connections) {
			if (ctx.executorId === executorId) {
				const requestId = crypto.randomUUID()
				const message = JSON.stringify({
					type: 'get_scene_tree',
					data: { request_id: requestId },
				}) + '\n'

				return new Promise((resolve, reject) => {
					const timer = setTimeout(() => {
						ctx.pendingRequests.delete(requestId)
						reject(new Error('TIMEOUT'))
					}, timeoutMs)

					ctx.pendingRequests.set(requestId, {
						resolve: (result: Record<string, unknown>) => {
							clearTimeout(timer)
							ctx.pendingRequests.delete(requestId)
							resolve(result)
						},
						reject: (error: Error) => {
							clearTimeout(timer)
							ctx.pendingRequests.delete(requestId)
							reject(error)
						},
						timer,
					})
					ctx.socket.write(message)
				})
			}
		}
		return Promise.reject(new Error('Executor not connected'))
	}

	// 创建节点请求
	sendCreateNodeRequest(
		executorId: string,
		parentPath: string,
		nodeName: string,
		nodeType: string,
		scriptPath: string,
		timeoutMs: number = 10000
	): Promise<Record<string, unknown>> {
		for (const [, ctx] of this.connections) {
			if (ctx.executorId === executorId) {
				const requestId = crypto.randomUUID()
				const message = JSON.stringify({
					type: 'create_node',
					data: {
						request_id: requestId,
						parent_path: parentPath,
						name: nodeName,
						type: nodeType,
						script: scriptPath,
					},
				}) + '\n'

				return new Promise((resolve, reject) => {
					const timer = setTimeout(() => {
						ctx.pendingRequests.delete(requestId)
						reject(new Error('TIMEOUT'))
					}, timeoutMs)

					ctx.pendingRequests.set(requestId, {
						resolve: (result: Record<string, unknown>) => {
							clearTimeout(timer)
							ctx.pendingRequests.delete(requestId)
							resolve(result)
						},
						reject: (error: Error) => {
							clearTimeout(timer)
							ctx.pendingRequests.delete(requestId)
							reject(error)
						},
						timer,
					})
					ctx.socket.write(message)
				})
			}
		}
		return Promise.reject(new Error('Executor not connected'))
	}

	// 删除节点请求
	sendDeleteNodeRequest(
		executorId: string,
		nodePath: string,
		timeoutMs: number = 10000
	): Promise<Record<string, unknown>> {
		for (const [, ctx] of this.connections) {
			if (ctx.executorId === executorId) {
				const requestId = crypto.randomUUID()
				const message = JSON.stringify({
					type: 'delete_node',
					data: {
						request_id: requestId,
						node_path: nodePath,
					},
				}) + '\n'

				return new Promise((resolve, reject) => {
					const timer = setTimeout(() => {
						ctx.pendingRequests.delete(requestId)
						reject(new Error('TIMEOUT'))
					}, timeoutMs)

					ctx.pendingRequests.set(requestId, {
						resolve: (result: Record<string, unknown>) => {
							clearTimeout(timer)
							ctx.pendingRequests.delete(requestId)
							resolve(result)
						},
						reject: (error: Error) => {
							clearTimeout(timer)
							ctx.pendingRequests.delete(requestId)
							reject(error)
						},
						timer,
					})
					ctx.socket.write(message)
				})
			}
		}
		return Promise.reject(new Error('Executor not connected'))
	}

	getConnectedCount(): number {
		let count = 0
		for (const [, ctx] of this.connections) {
			if (ctx.executorId) count++
		}
		return count
	}

	private handleConnection(socket: net.Socket): void {
		// 安全增强：连接数限制
		if (this.connectionCount >= MAX_CONNECTIONS) {
			console.warn(`[TCP] Max connections (${MAX_CONNECTIONS}) reached, rejecting new connection`)
			socket.destroy()
			return
		}

		this.connectionCount++
		const socketId = crypto.randomUUID()
		const ctx: ConnectionContext = {
			socket,
			executorId: null,
			lastMessageTime: Date.now(),
			lastHeartbeatSent: null,
			lastHeartbeatReceived: null,
			pingSent: false,
			pingSentTime: null,
			buffer: '',
			pendingRequests: new Map(),
			reconnectCount: 0,
			connectedAt: Date.now(),
		}
		this.connections.set(socketId, ctx)
		console.log(`[TCP] New connection ${socketId} (total: ${this.connectionCount})`)

		socket.on('data', (data) => {
			ctx.buffer += data.toString()
			const lines = ctx.buffer.split('\n')
			ctx.buffer = lines.pop()!

			for (const line of lines) {
				if (line.trim()) {
					// 安全增强：单行消息长度限制
					if (line.length > MAX_LINE_LENGTH) {
						console.warn(`[TCP] Message too long (${line.length} > ${MAX_LINE_LENGTH}), truncating`)
						this.handleMessage(socketId, line.substring(0, MAX_LINE_LENGTH))
					} else {
						this.handleMessage(socketId, line.trim())
					}
				}
			}
		})

		socket.on('close', () => {
			this.connectionCount--
			this.handleDisconnection(socketId)
			console.log(`[TCP] Connection closed ${socketId} (remaining: ${this.connectionCount})`)
		})

		socket.on('error', (err) => {
			console.warn(`[TCP] Socket error ${socketId}: ${err.message}`)
		})
	}

	private handleMessage(socketId: string, raw: string): void {
		const ctx = this.connections.get(socketId)
		if (!ctx) return

		ctx.lastMessageTime = Date.now()

		let message: TcpMessage
		try {
			message = JSON.parse(raw)
		} catch (err) {
			// 增强：JSON解析错误时输出日志
			const errorMsg = err instanceof Error ? err.message : 'Unknown error'
			console.warn(`[TCP] JSON parse error from ${socketId}: ${errorMsg}, raw: ${raw.substring(0, 100)}...`)
			return
		}

		switch (message.type) {
			case 'register':
				this.handleRegister(socketId, message.data as Record<string, unknown>)
				break
			case 'execute_result':
				this.handleExecuteResult(socketId, message.data as Record<string, unknown>)
				break
			case 'scene_tree_result':
				this.handleSceneTreeResult(socketId, message.data as Record<string, unknown>)
				break
			case 'create_node_result':
				this.handleCreateNodeResult(socketId, message.data as Record<string, unknown>)
				break
			case 'delete_node_result':
				this.handleDeleteNodeResult(socketId, message.data as Record<string, unknown>)
				break
			case 'pong':
				// 心跳响应
				if (ctx.pingSent) {
					ctx.lastHeartbeatReceived = Date.now()
					ctx.pingSent = false
					ctx.pingSentTime = null
				}
				break
			case 'heartbeat':
				// 客户端主动心跳
				this.sendToSocket(socketId, { type: 'heartbeat_ack', data: { timestamp: Date.now() } })
				break
			case 'logs':
				// 日志消息
				this.handleLogs(ctx, message.data as Record<string, unknown>)
				break
		}
	}

	private handleSceneTreeResult(socketId: string, data: Record<string, unknown>): void {
		const ctx = this.connections.get(socketId)
		if (!ctx) return

		const requestId = data.request_id as string
		const pending = ctx.pendingRequests.get(requestId)
		if (pending) {
			clearTimeout(pending.timer)
			ctx.pendingRequests.delete(requestId)
			pending.resolve(data)
		}
	}

	private handleCreateNodeResult(socketId: string, data: Record<string, unknown>): void {
		const ctx = this.connections.get(socketId)
		if (!ctx) return

		const requestId = data.request_id as string
		const pending = ctx.pendingRequests.get(requestId)
		if (pending) {
			clearTimeout(pending.timer)
			ctx.pendingRequests.delete(requestId)
			pending.resolve(data)
		}
	}

	private handleDeleteNodeResult(socketId: string, data: Record<string, unknown>): void {
		const ctx = this.connections.get(socketId)
		if (!ctx) return

		const requestId = data.request_id as string
		const pending = ctx.pendingRequests.get(requestId)
		if (pending) {
			clearTimeout(pending.timer)
			ctx.pendingRequests.delete(requestId)
			pending.resolve(data)
		}
	}

	private handleRegister(socketId: string, data: Record<string, unknown>): void {
		const ctx = this.connections.get(socketId)
		if (!ctx) return

		const requiredFields = ['project_name', 'project_path', 'editor_pid', 'type']
		const missing = requiredFields.filter((f) => data[f] === undefined || data[f] === null || data[f] === '')
		if (missing.length > 0) {
			this.sendToSocket(socketId, {
				type: 'register_result',
				data: { success: false, error: `Missing required fields: ${missing.join(', ')}` },
			})
			return
		}

		const id = this.generateDeterministicId(
			data.project_name as string,
			data.project_path as string,
			data.editor_pid as number,
		)

		for (const [otherSocketId, otherCtx] of this.connections) {
			if (otherCtx.executorId === id && otherSocketId !== socketId) {
				for (const [, pending] of otherCtx.pendingRequests) {
					clearTimeout(pending.timer)
					pending.reject(new Error('Executor reconnected'))
				}
				otherCtx.socket.destroy()
				this.connections.delete(otherSocketId)
			}
		}

		// 检测重连
		const isReconnect = ctx.connectedAt > 0 && Date.now() - ctx.connectedAt < 60000
		if (isReconnect) {
			ctx.reconnectCount++
		}

		ctx.executorId = id
		const executorInfo: ExecutorInfo = {
			id,
			project_name: data.project_name as string,
			project_path: data.project_path as string,
			editor_pid: data.editor_pid as number,
			plugin_version: (data.plugin_version as string) || '',
			editor_version: (data.editor_version as string) || '',
			supported_languages: (data.supported_languages as string[]) || [],
			connected_at: new Date().toISOString(),
			status: 'connected',
			type: (data.type as 'editor' | 'game') || 'editor',
		}
		this.executorManager.add(executorInfo)

		// 清空旧日志（重新连接时）
		this.logs.delete(id)

		this.sendToSocket(socketId, {
			type: 'register_result',
			data: { success: true, id },
		})
	}

	private handleExecuteResult(socketId: string, data: Record<string, unknown>): void {
		const ctx = this.connections.get(socketId)
		if (!ctx) return

		const requestId = data.request_id as string
		const pending = ctx.pendingRequests.get(requestId)
		if (pending) {
			clearTimeout(pending.timer)
			ctx.pendingRequests.delete(requestId)
			pending.resolve(data)
		}
	}

	private handleDisconnection(socketId: string): void {
		const ctx = this.connections.get(socketId)
		if (!ctx) return

		const executorId = ctx.executorId
		if (executorId) {
			this.executorManager.remove(executorId)
			console.log(`[Connection] Executor ${executorId} disconnected (reconnect_count: ${ctx.reconnectCount})`)
		}

		for (const [, pending] of ctx.pendingRequests) {
			clearTimeout(pending.timer)
			pending.reject(new Error('Executor disconnected'))
		}

		this.connections.delete(socketId)
	}

	private generateDeterministicId(projectName: string, projectPath: string, editorPid: number): string {
		const input = `${projectName}|${projectPath}|${editorPid}`
		const hash = crypto.createHash('sha256').update(input).digest('hex')
		return `${hash.slice(0, 8)}-${hash.slice(8, 12)}-${hash.slice(12, 16)}-${hash.slice(16, 20)}-${hash.slice(20, 32)}`
	}

	private sendToSocket(socketId: string, message: TcpMessage): void {
		const ctx = this.connections.get(socketId)
		if (ctx && !ctx.socket.destroyed) {
			ctx.socket.write(JSON.stringify(message) + '\n')
		}
	}

	private startHeartbeatCheck(): void {
		this.heartbeatInterval = setInterval(() => {
			const now = Date.now()
			for (const [socketId, ctx] of this.connections) {
				if (!ctx.executorId) continue

				const idle = now - ctx.lastMessageTime
				// 30秒无消息则发送心跳
				if (idle > 30000 && !ctx.pingSent) {
					ctx.pingSent = true
					ctx.pingSentTime = now
					ctx.lastHeartbeatSent = now
					this.sendToSocket(socketId, { type: 'ping' })
				}
				// 15秒内没收到 pong 则断开连接
				else if (ctx.pingSent && ctx.pingSentTime && now - ctx.pingSentTime > 15000) {
					console.log(`[Heartbeat] Executor ${ctx.executorId} heartbeat timeout, disconnecting`)
					ctx.socket.destroy()
				}
			}
		}, 5000)
	}

	getConnectionMetrics(executorId: string): import('./types.js').ConnectionMetrics | null {
		for (const [, ctx] of this.connections) {
			if (ctx.executorId === executorId) {
				const now = Date.now()
				return {
					executor_id: ctx.executorId,
					connected_at: new Date(ctx.connectedAt).toISOString(),
					last_message_at: new Date(ctx.lastMessageTime).toISOString(),
					last_heartbeat_sent: ctx.lastHeartbeatSent ? new Date(ctx.lastHeartbeatSent).toISOString() : '',
					last_heartbeat_received: ctx.lastHeartbeatReceived ? new Date(ctx.lastHeartbeatReceived).toISOString() : '',
					idle_seconds: Math.floor((now - ctx.lastMessageTime) / 1000),
					reconnect_count: ctx.reconnectCount,
					rtt_ms: ctx.pingSentTime && ctx.lastHeartbeatReceived
						? ctx.lastHeartbeatReceived - ctx.pingSentTime
						: null,
				}
			}
		}
		return null
	}

	// 断点管理
	setBreakpoint(executorId: string, bp: Omit<import('./types.js').Breakpoint, 'id' | 'created_at'>): import('./types.js').Breakpoint | null {
		const ctx = this.findContextByExecutorId(executorId)
		if (!ctx) return null

		const id = crypto.randomUUID()
		const breakpoint: import('./types.js').Breakpoint = {
			...bp,
			id,
			created_at: new Date().toISOString(),
		}
		this.breakpoints.set(id, breakpoint)

		// 通知 executor
		this.sendToSocketByExecutorId(executorId, {
			type: 'breakpoint_set',
			data: breakpoint,
		})

		return breakpoint
	}

	removeBreakpoint(executorId: string, breakpointId: string): boolean {
		if (!this.breakpoints.has(breakpointId)) return false

		this.breakpoints.delete(breakpointId)

		// 通知 executor
		this.sendToSocketByExecutorId(executorId, {
			type: 'breakpoint_removed',
			data: { id: breakpointId },
		})

		return true
	}

	listBreakpoints(_executorId: string): import('./types.js').Breakpoint[] {
		const result: import('./types.js').Breakpoint[] = []
		for (const [, bp] of this.breakpoints) {
			result.push(bp)
		}
		return result
	}

	clearBreakpoints(executorId: string): void {
		const toRemove: string[] = []
		for (const [id] of this.breakpoints) {
			toRemove.push(id)
		}
		for (const id of toRemove) {
			this.removeBreakpoint(executorId, id)
		}
	}

	updateBreakpoint(executorId: string, breakpointId: string, updates: Partial<import('./types.js').Breakpoint>): import('./types.js').Breakpoint | null {
		const bp = this.breakpoints.get(breakpointId)
		if (!bp) return null

		const updated = { ...bp, ...updates, id: bp.id }
		this.breakpoints.set(breakpointId, updated)

		this.sendToSocketByExecutorId(executorId, {
			type: 'breakpoint_updated',
			data: updated,
		})

		return updated
	}

	private findContextByExecutorId(executorId: string): ConnectionContext | undefined {
		for (const [, ctx] of this.connections) {
			if (ctx.executorId === executorId) {
				return ctx
			}
		}
		return undefined
	}

	private sendToSocketByExecutorId(executorId: string, message: TcpMessage): void {
		const ctx = this.findContextByExecutorId(executorId)
		if (ctx && !ctx.socket.destroyed) {
			ctx.socket.write(JSON.stringify(message) + '\n')
		}
	}

	// 日志处理
	private handleLogs(ctx: ConnectionContext, data: Record<string, unknown>): void {
		if (!ctx.executorId) return

		const logs = data.logs as LogEntry[]
		if (!Array.isArray(logs)) return

		// 存储日志
		const existingLogs = this.logs.get(ctx.executorId) || []
		const newLogs = [...existingLogs, ...logs]

		// 限制存储数量（FIFO）
		while (newLogs.length > MAX_LOG_ENTRIES) {
			newLogs.shift()
		}

		this.logs.set(ctx.executorId, newLogs)
		console.log(`[Logs] Received ${logs.length} log entries from ${ctx.executorId}`)
	}

	getLogs(executorId: string, options: { limit?: number; type?: string } = {}): LogEntry[] {
		const logs = this.logs.get(executorId) || []

		let filtered = logs

		// 过滤类型
		if (options.type) {
			filtered = filtered.filter(log => log.type === options.type)
		}

		// 限制数量
		if (options.limit && options.limit > 0) {
			filtered = filtered.slice(-options.limit)
		}

		return filtered
	}

	getErrorLogs(executorId: string): LogEntry[] {
		return this.getLogs(executorId).filter(
			log => log.type === 'compile_error' || log.type === 'runtime_error' || log.type === 'script_error'
		)
	}

	clearLogs(executorId: string): void {
		this.logs.delete(executorId)
	}

	getLogCount(executorId: string): number {
		return this.logs.get(executorId)?.length || 0
	}
}
