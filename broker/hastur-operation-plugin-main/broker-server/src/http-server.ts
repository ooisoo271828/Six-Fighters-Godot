import express, { type Request, type Response, type NextFunction } from 'express'
import { ExecutorManager } from './executor-manager.js'
import { TcpServer } from './tcp-server.js'
import { createAuthMiddleware } from './auth.js'
import type { ApiResponse } from './types.js'

// ============ 配置常量 ============
const MAX_REQUEST_BODY_SIZE = '10mb'  // 请求体大小限制（安全）
const MAX_CONNECTIONS = 100           // 最大并发连接数
const REQUEST_TIMEOUT = 60000         // 请求超时（毫秒）

// 从 Godot 错误字符串中提取行号
function extractLine(error: string): number | null {
	if (!error) return null
	// 匹配 "at line N" 模式
	const lineMatch = error.match(/at line (\d+)/i)
	if (lineMatch) return parseInt(lineMatch[1])
	// 匹配 "(N:M)" 模式
	const colMatch = error.match(/\((\d+):\d+\)/)
	if (colMatch) return parseInt(colMatch[1])
	return null
}

export function createHttpApp(
	executorManager: ExecutorManager,
	tcpServer: TcpServer,
	authToken: string,
	tcpPort: number,
	httpPort: number,
) {
	const app = express()
	const authMiddleware = createAuthMiddleware(authToken)

	// 安全增强：请求体大小限制
	app.use(express.json({ limit: MAX_REQUEST_BODY_SIZE }))
	app.use(express.urlencoded({ extended: true, limit: MAX_REQUEST_BODY_SIZE }))

	// 安全增强：请求超时
	app.use((req: Request, res: Response, next: NextFunction) => {
		// 设置响应超时
		res.setTimeout(REQUEST_TIMEOUT, () => {
			console.warn(`[HTTP] Request timeout: ${req.method} ${req.path}`)
			if (!res.headersSent) {
				res.status(504).json({
					success: false,
					error: 'Request timeout',
					hint: 'The request took too long to process.',
				})
			}
		})
		next()
	})

	app.get('/api/health', (_req: Request, res: Response) => {
		const executors = executorManager.getAll()
		const now = Date.now()
		const executorDetails = executors.map(ex => {
			const metrics = tcpServer.getConnectionMetrics(ex.id)
			return {
				id: ex.id,
				project_name: ex.project_name,
				project_path: ex.project_path,
				status: ex.status,
				type: ex.type,
				connected_at: ex.connected_at,
				uptime_seconds: Math.floor((now - new Date(ex.connected_at).getTime()) / 1000),
				last_heartbeat: metrics?.last_heartbeat_received || ex.connected_at,
				idle_seconds: metrics?.idle_seconds || 0,
				reconnect_count: metrics?.reconnect_count || 0,
				rtt_ms: metrics?.rtt_ms,
			}
		})

		res.json({
			success: true,
			data: {
				status: 'ok',
				version: '0.6.0',
				tcp_port: tcpPort,
				http_port: httpPort,
				executors_connected: executors.length,
				executors: executorDetails,
				timestamp: new Date().toISOString(),
			},
		})
	})

	app.use('/api', (req: Request, res: Response, next: NextFunction) => {
		if (req.path === '/health') {
			next()
			return
		}
		authMiddleware(req, res, next)
	})

	// Helper: resolve executor by :id param, returns null if not found (sends 404)
	function resolveExecutor(req: Request, res: Response): import('./types.js').ExecutorInfo | null {
		const executor = executorManager.findById(req.params.id)
		if (!executor) {
			res.status(404).json({
				success: false,
				error: 'Executor not found',
				hint: 'Use GET /api/executors to list all available executors.',
			})
			return null
		}
		return executor
	}

	// Helper: wrap a TCP request with standard error handling
	function asyncTcpRoute(handler: () => Promise<Record<string, unknown>>, res: Response, errorMsg: string): void {
		handler()
			.then(result => res.json({ success: true, data: result }))
			.catch((err: unknown) => {
				const error = err as Error
				const status = error.message === 'TIMEOUT' ? 504 : 500
				res.status(status).json({
					success: false,
					error: error.message || errorMsg,
				})
			})
	}

	app.get('/api/executors', (_req: Request, res: Response) => {
		const executors = executorManager.getAll()
		const response: ApiResponse = {
			success: true,
			data: executors,
		}
		if (executors.length === 0) {
			response.hint = 'No Hastur Executors are currently connected. Ensure the Hastur Executor plugin is enabled in a Godot editor and can reach the broker-server.'
		}
		res.json(response)
	})

	app.get('/api/executors/:id', (req: Request, res: Response) => {
		const executor = resolveExecutor(req, res)
		if (!executor) return
		const metrics = tcpServer.getConnectionMetrics(executor.id)
		res.json({
			success: true,
			data: {
				...executor,
				metrics,
			},
		})
	})

	app.get('/api/executors/:id/metrics', (req: Request, res: Response) => {
		const metrics = tcpServer.getConnectionMetrics(req.params.id)
		if (!metrics) {
			res.status(404).json({
				success: false,
				error: 'Executor not found or not connected',
				hint: 'Use GET /api/executors to list all available executors.',
			})
			return
		}
		res.json({
			success: true,
			data: metrics,
		})
	})

	app.post('/api/executors', (_req: Request, res: Response) => {
		res.status(405).json({
			success: false,
			error: 'Method not allowed',
			hint: 'GET /api/executors to list executors, POST /api/execute to execute code',
		})
	})

	app.post('/api/execute', async (req: Request, res: Response) => {
		const { code, executor_id, project_name, project_path, type, timeout_ms, execution_mode, context_path } = req.body

		// 可配置超时，默认 30 秒，最大 120 秒
		const timeout = Math.min(
			Math.max(parseInt(timeout_ms) || 30000, 1000),
			120000
		)

		if (!code) {
			res.status(400).json({
				success: false,
				error: 'Missing required field: code',
				hint: 'The request body must include a \'code\' field (string) containing the GDScript code to execute. Example: {"code": "print(\\"hello\\")"}',
			})
			return
		}

		if (!executor_id && !project_name && !project_path) {
			res.status(400).json({
				success: false,
				error: 'No executor identifier provided',
				hint: 'Provide one of: executor_id (exact match), project_name (fuzzy match), or project_path (fuzzy match) to target a specific executor. Optionally specify type: "editor" or "game".',
			})
			return
		}

		const executorType = type as ('editor' | 'game') | undefined
		let executor
		if (executor_id) {
			executor = executorManager.findById(executor_id)
			if (executor && executorType && executor.type !== executorType) {
				executor = undefined
			}
		} else if (project_name) {
			executor = executorManager.findByProjectName(project_name, executorType)
		} else if (project_path) {
			executor = executorManager.findByProjectPath(project_path, executorType)
		}

		if (!executor) {
			res.status(404).json({
				success: false,
				error: 'No connected Hastur Executor matched the query',
				hint: 'Use GET /api/executors to list available executors. You can filter by type: "editor" or "game".',
			})
			return
		}

		try {
			const result = await tcpServer.sendExecute(executor.id, code, 'gdscript', timeout, execution_mode, context_path)
			// Execute summary — 让 AI/CLI 快速判断成功/失败
			const compileOk = (result as Record<string, unknown>).compile_success as boolean
			const runOk = (result as Record<string, unknown>).run_success as boolean
			const compileErr = (result as Record<string, unknown>).compile_error as string
			const runErr = (result as Record<string, unknown>).run_error as string
			const outputs = (result as Record<string, unknown>).outputs as unknown[]
			const summary = {
				compile_ok: compileOk,
				run_ok: runOk,
				error_count: (compileErr ? 1 : 0) + (runErr ? 1 : 0),
				first_error: compileErr
					? { message: compileErr, line: extractLine(compileErr) }
					: runErr
					? { message: runErr, line: extractLine(runErr) }
					: null,
				output_count: outputs?.length || 0,
			}
			res.json({ success: true, data: result, summary })
		} catch (err: unknown) {
			const error = err as Error
			if (error.message === 'TIMEOUT') {
				res.status(504).json({
					success: false,
					error: `Executor execution timed out (${timeout}ms)`,
					hint: 'The code execution took too long. Try simplifying the code or check if the Godot editor is responsive. You can also increase the timeout using the "timeout_ms" parameter.',
				})
			} else {
				res.status(500).json({
					success: false,
					error: error.message || 'Execution failed',
					hint: 'An unexpected error occurred during code execution.',
				})
			}
		}
	})

	// 断点管理 API
	app.get('/api/executors/:id/breakpoints', (req: Request, res: Response) => {
		const executor = resolveExecutor(req, res)
		if (!executor) return
		const breakpoints = tcpServer.listBreakpoints(executor.id)
		res.json({ success: true, data: breakpoints })
	})

	app.post('/api/executors/:id/breakpoints', (req: Request, res: Response) => {
		const executor = resolveExecutor(req, res)
		if (!executor) return

		const { file, line, condition, enabled } = req.body
		if (!file || line === undefined) {
			res.status(400).json({
				success: false,
				error: 'Missing required fields: file, line',
			})
			return
		}

		const bp = tcpServer.setBreakpoint(executor.id, {
			file,
			line,
			condition,
			enabled: enabled !== false,
			hit_count: 0,
		})

		if (!bp) {
			res.status(500).json({
				success: false,
				error: 'Failed to set breakpoint',
			})
			return
		}

		res.json({ success: true, data: bp })
	})

	app.delete('/api/executors/:id/breakpoints/:bpId', (req: Request, res: Response) => {
		const executor = resolveExecutor(req, res)
		if (!executor) return

		const removed = tcpServer.removeBreakpoint(executor.id, req.params.bpId)
		if (!removed) {
			res.status(404).json({
				success: false,
				error: 'Breakpoint not found',
			})
			return
		}

		res.json({ success: true, data: { id: req.params.bpId } })
	})

	app.patch('/api/executors/:id/breakpoints/:bpId', (req: Request, res: Response) => {
		const executor = resolveExecutor(req, res)
		if (!executor) return

		const bp = tcpServer.updateBreakpoint(executor.id, req.params.bpId, req.body)
		if (!bp) {
			res.status(404).json({
				success: false,
				error: 'Breakpoint not found',
			})
			return
		}

		res.json({ success: true, data: bp })
	})

	app.delete('/api/executors/:id/breakpoints', (req: Request, res: Response) => {
		const executor = resolveExecutor(req, res)
		if (!executor) return
		tcpServer.clearBreakpoints(executor.id)
		res.json({ success: true, data: { cleared: true } })
	})

	// 获取变量（需要在 executor 上执行）
	app.post('/api/executors/:id/variables', async (req: Request, res: Response) => {
		const executor = resolveExecutor(req, res)
		if (!executor) return

		const { expression } = req.body
		if (!expression) {
			res.status(400).json({
				success: false,
				error: 'Missing required field: expression',
			})
			return
		}

		// 使用 get_variable 命令获取变量值
		const code = `executeContext.get_variable("${expression}")`
		try {
			const result = await tcpServer.sendExecute(executor.id, code, 'gdscript', 5000)
			res.json({ success: true, data: result })
		} catch (err: unknown) {
			const error = err as Error
			res.status(500).json({
				success: false,
				error: error.message || 'Failed to get variable',
			})
		}
	})

	// ============ 场景树 API ============

	// 获取场景树
	app.get('/api/scene/tree', async (req: Request, res: Response) => {
		// 如果没有指定 executor_id，尝试使用第一个连接的 executor
		let executorId = req.query.executor_id as string

		if (!executorId) {
			// 查找第一个 editor 类型的 executor
			const executors = executorManager.getAll()
			const editorExecutor = executors.find((ex) => ex.type === 'editor')
			if (!editorExecutor) {
				res.status(404).json({
					success: false,
					error: 'No editor executor connected',
					hint: 'Connect a Godot editor with the Hastur plugin enabled, then retry.',
				})
				return
			}
			executorId = editorExecutor.id
		}

		asyncTcpRoute(async () => {
			const result = await tcpServer.sendSceneTreeRequest(executorId, 10000)
			if (!result.success) throw new Error(String(result.error || 'Failed to get scene tree'))
			return { tree: result.tree, executor_id: executorId }
		}, res, 'Failed to get scene tree')
	})

	// 获取场景树（通过 executor ID）
	app.get('/api/executors/:id/scene/tree', async (req: Request, res: Response) => {
		const executor = resolveExecutor(req, res)
		if (!executor) return

		asyncTcpRoute(async () => {
			const result = await tcpServer.sendSceneTreeRequest(executor.id, 10000)
			if (!result.success) throw new Error(String(result.error || 'Failed to get scene tree'))
			return { tree: result.tree, executor_id: executor.id }
		}, res, 'Failed to get scene tree')
	})

	// ============ 创建节点 API ============

	// 创建节点（通过 executor_id）
	app.post('/api/executors/:id/scene/nodes', async (req: Request, res: Response) => {
		const executor = resolveExecutor(req, res)
		if (!executor) return

		const { parent_path, name, type, script } = req.body
		if (!name) {
			res.status(400).json({
				success: false,
				error: 'Missing required field: name',
			})
			return
		}

		asyncTcpRoute(async () => {
			const result = await tcpServer.sendCreateNodeRequest(
				executor.id,
				parent_path || '',
				name,
				type || 'Node',
				script || '',
				10000
			)
			if (!result.success) throw new Error(String(result.error || 'Failed to create node'))
			return { node_path: result.node_path, executor_id: executor.id }
		}, res, 'Failed to create node')
	})

	// 创建节点（自动选择 editor executor）
	app.post('/api/scene/nodes', async (req: Request, res: Response) => {
		// 查找第一个 editor 类型的 executor
		const executors = executorManager.getAll()
		const editorExecutor = executors.find((ex) => ex.type === 'editor')
		if (!editorExecutor) {
			res.status(404).json({
				success: false,
				error: 'No editor executor connected',
			})
			return
		}

		const { parent_path, name, type, script } = req.body
		if (!name) {
			res.status(400).json({
				success: false,
				error: 'Missing required field: name',
			})
			return
		}

		asyncTcpRoute(async () => {
			const result = await tcpServer.sendCreateNodeRequest(
				editorExecutor.id,
				parent_path || '',
				name,
				type || 'Node',
				script || '',
				10000
			)
			if (!result.success) throw new Error(String(result.error || 'Failed to create node'))
			return { node_path: result.node_path, executor_id: editorExecutor.id }
		}, res, 'Failed to create node')
	})

	// ============ 删除节点 API ============

	// 删除节点（通过 executor_id）
	app.delete('/api/executors/:id/scene/nodes', async (req: Request, res: Response) => {
		const executor = resolveExecutor(req, res)
		if (!executor) return

		const nodePath = req.query.path as string
		if (!nodePath) {
			res.status(400).json({
				success: false,
				error: 'Missing required query parameter: path',
			})
			return
		}

		asyncTcpRoute(async () => {
			const result = await tcpServer.sendDeleteNodeRequest(executor.id, nodePath, 10000)
			if (!result.success) throw new Error(String(result.error || 'Failed to delete node'))
			return { node_path: nodePath, executor_id: executor.id }
		}, res, 'Failed to delete node')
	})

	// 删除节点（自动选择 editor executor）
	app.delete('/api/scene/nodes', async (req: Request, res: Response) => {
		// 查找第一个 editor 类型的 executor
		const executors = executorManager.getAll()
		const editorExecutor = executors.find((ex) => ex.type === 'editor')
		if (!editorExecutor) {
			res.status(404).json({
				success: false,
				error: 'No editor executor connected',
			})
			return
		}

		const nodePath = req.query.path as string
		if (!nodePath) {
			res.status(400).json({
				success: false,
				error: 'Missing required query parameter: path',
			})
			return
		}

		asyncTcpRoute(async () => {
			const result = await tcpServer.sendDeleteNodeRequest(editorExecutor.id, nodePath, 10000)
			if (!result.success) throw new Error(String(result.error || 'Failed to delete node'))
			console.log(`[HTTP] Delete node result for "${nodePath}":`, JSON.stringify(result).substring(0, 500))
			return { node_path: nodePath, executor_id: editorExecutor.id }
		}, res, 'Failed to delete node')
	})

	// 日志 API
	app.get('/api/executors/:id/logs', (req: Request, res: Response) => {
		const executor = resolveExecutor(req, res)
		if (!executor) return

		const limit = parseInt(req.query.limit as string) || 100
		const type = req.query.type as string | undefined
		const logs = tcpServer.getLogs(executor.id, { limit, type })

		res.json({
			success: true,
			data: {
				logs,
				count: logs.length,
				total: tcpServer.getLogCount(executor.id),
			},
		})
	})

	app.get('/api/executors/:id/logs/errors', (req: Request, res: Response) => {
		const executor = resolveExecutor(req, res)
		if (!executor) return

		const limit = parseInt(req.query.limit as string) || 50
		const logs = tcpServer.getErrorLogs(executor.id).slice(-limit)

		res.json({
			success: true,
			data: {
				logs,
				count: logs.length,
			},
		})
	})

	app.delete('/api/executors/:id/logs', (req: Request, res: Response) => {
		const executor = resolveExecutor(req, res)
		if (!executor) return
		tcpServer.clearLogs(executor.id)
		res.json({
			success: true,
			data: { cleared: true },
		})
	})

	// ============ v0.5.0 新增路由 ============

	// 强制编辑器刷新文件系统
	app.post('/api/project/rescan', (_req: Request, res: Response) => {
		const executors = executorManager.getAll()
		const editorExecutor = executors.find((ex) => ex.type === 'editor')
		if (!editorExecutor) {
			res.status(404).json({
				success: false,
				error: 'No editor executor connected',
			})
			return
		}
		asyncTcpRoute(() => tcpServer.sendRequest(editorExecutor.id, 'rescan', {}, 10000), res, 'Failed to rescan')
	})

	// 编译检查（不执行）
	app.post('/api/script/check', async (req: Request, res: Response) => {
		const { code, executor_id } = req.body
		if (!code) {
			res.status(400).json({
				success: false,
				error: 'Missing required field: code',
			})
			return
		}

		let executor
		if (executor_id) {
			executor = executorManager.findById(executor_id)
		} else {
			const executors = executorManager.getAll()
			executor = executors.find((ex) => ex.type === 'editor')
		}
		if (!executor) {
			res.status(404).json({
				success: false,
				error: 'No editor executor connected',
			})
			return
		}

		asyncTcpRoute(() => tcpServer.sendRequest(executor.id, 'script_check', { code }, 15000), res, 'Script check failed')
	})

	// 获取节点属性
	app.get('/api/executors/:id/scene/properties', (req: Request, res: Response) => {
		const executor = resolveExecutor(req, res)
		if (!executor) return

		const nodePath = (req.query.path as string) || ''
		const filter = (req.query.filter as string) || ''

		asyncTcpRoute(() => tcpServer.sendRequest(executor.id, 'get_properties', {
			node_path: nodePath,
			filter,
		}, 10000), res, 'Failed to get properties')
	})

	// 保存当前场景
	app.post('/api/scene/save', (req: Request, res: Response) => {
		const executors = executorManager.getAll()
		const editorExecutor = executors.find((ex) => ex.type === 'editor')
		if (!editorExecutor) {
			res.status(404).json({
				success: false,
				error: 'No editor executor connected',
			})
			return
		}
			const force = req.body?.force === true
			if (force) {
				console.log(`[SCENE_SAVE] Force save requested`)
			}
			asyncTcpRoute(() => tcpServer.sendRequest(editorExecutor.id, 'scene_save', { force }, 10000), res, 'Failed to save scene')
	})

	// ── v0.6.0 Scene Diagnostics ──

	app.get('/api/scene/inspect', (req: Request, res: Response) => {
		const executors = executorManager.getAll()
		const editorExecutor = executors.find((ex) => ex.type === 'editor')
		if (!editorExecutor) {
			res.status(404).json({ success: false, error: 'No editor executor connected' })
			return
		}
		const path = req.query.path as string || '/root'
		const depth = parseInt(req.query.depth as string) || 2
		asyncTcpRoute(() => tcpServer.sendRequest(editorExecutor.id, 'get_scene_inspect', {
			path, depth,
			include_children: req.query.include_children !== 'false',
			include_properties: req.query.include_properties !== 'false',
			include_signals: req.query.include_signals === 'true',
			property_filter: req.query.property_filter as string || '',
		}, 15000), res, 'Failed to inspect scene')
	})

	app.get('/api/scene/signals', (req: Request, res: Response) => {
		const executors = executorManager.getAll()
		const editorExecutor = executors.find((ex) => ex.type === 'editor')
		if (!editorExecutor) {
			res.status(404).json({ success: false, error: 'No editor executor connected' })
			return
		}
		const path = req.query.path as string || '/root'
		asyncTcpRoute(() => tcpServer.sendRequest(editorExecutor.id, 'get_signal_connections', { path }, 10000), res, 'Failed to get signal connections')
	})

	// ── v0.6.0 Compile Errors ──

	app.get('/api/project/compile-errors', (req: Request, res: Response) => {
		const executors = executorManager.getAll()
		const editorExecutor = executors.find((ex) => ex.type === 'editor')
		if (!editorExecutor) {
			res.status(404).json({ success: false, error: 'No editor executor connected' })
			return
		}
		asyncTcpRoute(() => tcpServer.sendRequest(editorExecutor.id, 'get_compile_errors', {}, 5000), res, 'Failed to get compile errors')
	})

	// ── v0.6.0 Console Stream ──

	app.get('/api/executors/:id/console/stream', (req: Request, res: Response) => {
		const executor = resolveExecutor(req, res, executorManager)
		if (!executor) return
		const since = req.query.since as string || '0'
		const limit = parseInt(req.query.limit as string) || 50
		asyncTcpRoute(() => tcpServer.sendRequest(executor.id, 'get_console_stream', {
			since_timestamp: parseFloat(since), limit,
		}, 5000), res, 'Failed to get console stream')
	})

	// ── v0.6.0 Script Reload ──

	app.post('/api/script/reload', (req: Request, res: Response) => {
		const executors = executorManager.getAll()
		const editorExecutor = executors.find((ex) => ex.type === 'editor')
		if (!editorExecutor) {
			res.status(404).json({ success: false, error: 'No editor executor connected' })
			return
		}
		const path = req.body?.path as string
		if (!path) {
			res.status(400).json({ success: false, error: 'Missing path in request body' })
			return
		}
		asyncTcpRoute(() => tcpServer.sendRequest(editorExecutor.id, 'script_reload', { path }, 15000), res, 'Failed to reload script')
	})

	// ── End v0.6.0 routes ──

	app.use((_req: Request, res: Response) => {
		res.status(404).json({
			success: false,
			error: 'Route not found',
			hint: 'Available endpoints: GET /api/executors, POST /api/execute, POST /api/project/rescan, POST /api/script/check, GET /api/executors/:id/scene/properties, POST /api/scene/save, GET /api/scene/inspect, GET /api/scene/signals, GET /api/project/compile-errors, POST /api/script/reload',
		})
	})

	return app
}


