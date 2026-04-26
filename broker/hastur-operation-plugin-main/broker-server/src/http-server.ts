import express, { type Request, type Response, type NextFunction } from 'express'
import { ExecutorManager } from './executor-manager.js'
import { TcpServer } from './tcp-server.js'
import { createAuthMiddleware } from './auth.js'
import type { ApiResponse } from './types.js'

// ============ 配置常量 ============
const MAX_REQUEST_BODY_SIZE = '10mb'  // 请求体大小限制（安全）
const MAX_CONNECTIONS = 100           // 最大并发连接数
const REQUEST_TIMEOUT = 60000         // 请求超时（毫秒）

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
				version: '0.3.0',
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
		const executor = executorManager.findById(req.params.id)
		if (!executor) {
			res.status(404).json({
				success: false,
				error: 'Executor not found',
				hint: 'Use GET /api/executors to list all available executors.',
			})
			return
		}
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
		const { code, executor_id, project_name, project_path, type, timeout_ms } = req.body

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
			const result = await tcpServer.sendExecute(executor.id, code, 'gdscript', timeout)
			res.json({ success: true, data: result })
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
		const executor = executorManager.findById(req.params.id)
		if (!executor) {
			res.status(404).json({
				success: false,
				error: 'Executor not found',
				hint: 'Use GET /api/executors to list all available executors.',
			})
			return
		}
		const breakpoints = tcpServer.listBreakpoints(executor.id)
		res.json({ success: true, data: breakpoints })
	})

	app.post('/api/executors/:id/breakpoints', (req: Request, res: Response) => {
		const executor = executorManager.findById(req.params.id)
		if (!executor) {
			res.status(404).json({
				success: false,
				error: 'Executor not found',
				hint: 'Use GET /api/executors to list all available executors.',
			})
			return
		}

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
		const executor = executorManager.findById(req.params.id)
		if (!executor) {
			res.status(404).json({
				success: false,
				error: 'Executor not found',
			})
			return
		}

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
		const executor = executorManager.findById(req.params.id)
		if (!executor) {
			res.status(404).json({
				success: false,
				error: 'Executor not found',
			})
			return
		}

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
		const executor = executorManager.findById(req.params.id)
		if (!executor) {
			res.status(404).json({
				success: false,
				error: 'Executor not found',
			})
			return
		}

		tcpServer.clearBreakpoints(executor.id)
		res.json({ success: true, data: { cleared: true } })
	})

	// 获取变量（需要在 executor 上执行）
	app.post('/api/executors/:id/variables', async (req: Request, res: Response) => {
		const executor = executorManager.findById(req.params.id)
		if (!executor) {
			res.status(404).json({
				success: false,
				error: 'Executor not found',
			})
			return
		}

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

		try {
			const result = await tcpServer.sendSceneTreeRequest(executorId, 10000)
			if (result.success) {
				res.json({
					success: true,
					data: {
						tree: result.tree,
						executor_id: executorId,
					},
				})
			} else {
				res.status(500).json({
					success: false,
					error: result.error || 'Failed to get scene tree',
				})
			}
		} catch (err: unknown) {
			const error = err as Error
			if (error.message === 'TIMEOUT') {
				res.status(504).json({
					success: false,
					error: 'Scene tree request timed out',
					hint: 'The Godot editor may be busy. Try again.',
				})
			} else {
				res.status(500).json({
					success: false,
					error: error.message || 'Failed to get scene tree',
				})
			}
		}
	})

	// 获取场景树（通过 executor ID）
	app.get('/api/executors/:id/scene/tree', async (req: Request, res: Response) => {
		const executor = executorManager.findById(req.params.id)
		if (!executor) {
			res.status(404).json({
				success: false,
				error: 'Executor not found',
			})
			return
		}

		try {
			const result = await tcpServer.sendSceneTreeRequest(executor.id, 10000)
			if (result.success) {
				res.json({
					success: true,
					data: {
						tree: result.tree,
						executor_id: executor.id,
					},
				})
			} else {
				res.status(500).json({
					success: false,
					error: result.error || 'Failed to get scene tree',
				})
			}
		} catch (err: unknown) {
			const error = err as Error
			if (error.message === 'TIMEOUT') {
				res.status(504).json({
					success: false,
					error: 'Scene tree request timed out',
				})
			} else {
				res.status(500).json({
					success: false,
					error: error.message || 'Failed to get scene tree',
				})
			}
		}
	})

	// ============ 创建节点 API ============

	// 创建节点（通过 executor_id）
	app.post('/api/executors/:id/scene/nodes', async (req: Request, res: Response) => {
		const executor = executorManager.findById(req.params.id)
		if (!executor) {
			res.status(404).json({
				success: false,
				error: 'Executor not found',
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

		try {
			const result = await tcpServer.sendCreateNodeRequest(
				executor.id,
				parent_path || '',
				name,
				type || 'Node',
				script || '',
				10000
			)
			if (result.success) {
				res.json({
					success: true,
					data: {
						node_path: result.node_path,
						executor_id: executor.id,
					},
				})
			} else {
				res.status(500).json({
					success: false,
					error: result.error || 'Failed to create node',
				})
			}
		} catch (err: unknown) {
			const error = err as Error
			if (error.message === 'TIMEOUT') {
				res.status(504).json({
					success: false,
					error: 'Create node request timed out',
				})
			} else {
				res.status(500).json({
					success: false,
					error: error.message || 'Failed to create node',
				})
			}
		}
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

		try {
			const result = await tcpServer.sendCreateNodeRequest(
				editorExecutor.id,
				parent_path || '',
				name,
				type || 'Node',
				script || '',
				10000
			)
			if (result.success) {
				res.json({
					success: true,
					data: {
						node_path: result.node_path,
						executor_id: editorExecutor.id,
					},
				})
			} else {
				res.status(500).json({
					success: false,
					error: result.error || 'Failed to create node',
				})
			}
		} catch (err: unknown) {
			const error = err as Error
			if (error.message === 'TIMEOUT') {
				res.status(504).json({
					success: false,
					error: 'Create node request timed out',
				})
			} else {
				res.status(500).json({
					success: false,
					error: error.message || 'Failed to create node',
				})
			}
		}
	})

	// ============ 删除节点 API ============

	// 删除节点（通过 executor_id）
	app.delete('/api/executors/:id/scene/nodes', async (req: Request, res: Response) => {
		const executor = executorManager.findById(req.params.id)
		if (!executor) {
			res.status(404).json({
				success: false,
				error: 'Executor not found',
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

		try {
			const result = await tcpServer.sendDeleteNodeRequest(executor.id, nodePath, 10000)
			if (result.success) {
				res.json({
					success: true,
					data: {
						node_path: nodePath,
						executor_id: executor.id,
					},
				})
			} else {
				res.status(500).json({
					success: false,
					error: result.error || 'Failed to delete node',
				})
			}
		} catch (err: unknown) {
			const error = err as Error
			if (error.message === 'TIMEOUT') {
				res.status(504).json({
					success: false,
					error: 'Delete node request timed out',
				})
			} else {
				res.status(500).json({
					success: false,
					error: error.message || 'Failed to delete node',
				})
			}
		}
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

		try {
			const result = await tcpServer.sendDeleteNodeRequest(editorExecutor.id, nodePath, 10000)
			console.log(`[HTTP] Delete node result for "${nodePath}":`, JSON.stringify(result).substring(0, 500))
			if (result.success) {
				res.json({
					success: true,
					data: {
						node_path: nodePath,
						executor_id: editorExecutor.id,
					},
				})
			} else {
				res.status(500).json({
					success: false,
					error: result.error || 'Failed to delete node',
				})
			}
		} catch (err: unknown) {
			const error = err as Error
			if (error.message === 'TIMEOUT') {
				res.status(504).json({
					success: false,
					error: 'Delete node request timed out',
				})
			} else {
				res.status(500).json({
					success: false,
					error: error.message || 'Failed to delete node',
				})
			}
		}
	})

	// 日志 API
	app.get('/api/executors/:id/logs', (req: Request, res: Response) => {
		const executor = executorManager.findById(req.params.id)
		if (!executor) {
			res.status(404).json({
				success: false,
				error: 'Executor not found',
			})
			return
		}

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
		const executor = executorManager.findById(req.params.id)
		if (!executor) {
			res.status(404).json({
				success: false,
				error: 'Executor not found',
			})
			return
		}

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
		const executor = executorManager.findById(req.params.id)
		if (!executor) {
			res.status(404).json({
				success: false,
				error: 'Executor not found',
			})
			return
		}

		tcpServer.clearLogs(executor.id)
		res.json({
			success: true,
			data: { cleared: true },
		})
	})

	app.use((_req: Request, res: Response) => {
		res.status(404).json({
			success: false,
			error: 'Route not found',
			hint: 'Available endpoints: GET /api/executors - List connected Hastur Executors, POST /api/execute - Execute code on a Hastur Executor',
		})
	})

	return app
}


