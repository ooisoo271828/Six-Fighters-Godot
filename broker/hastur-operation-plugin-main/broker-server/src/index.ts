import crypto from 'crypto'
import { Command } from 'commander'
import { ExecutorManager } from './executor-manager.js'
import { TcpServer } from './tcp-server.js'
import { createHttpApp } from './http-server.js'

const program = new Command()

program
	.option('--tcp-port <port>', 'TCP port for executor connections', '5301')
	.option('--http-port <port>', 'HTTP port for API', '5302')
	.option('--host <host>', 'Host to bind to', 'localhost')
	.option('--auth-token <token>', 'Authentication token for HTTP API')
	.parse()

const options = program.opts()
const tcpPort = parseInt(options.tcpPort as string, 10)
const httpPort = parseInt(options.httpPort as string, 10)
const host = options.host as string

const authToken = (options.authToken as string) || crypto.randomBytes(32).toString('hex')

if (!options.authToken) {
	console.log(`Auto-generated auth token: ${authToken}`)
}

const executorManager = new ExecutorManager()
const tcpServer = new TcpServer(executorManager)
const app = createHttpApp(executorManager, tcpServer, authToken, tcpPort, httpPort)

// 优雅关闭超时（毫秒）
const GRACEFUL_SHUTDOWN_TIMEOUT = 10000

async function main(): Promise<void> {
	await tcpServer.start(host, tcpPort)
	console.log(`TCP server listening on ${host}:${tcpPort}`)

	const httpServer = app.listen(httpPort, host, () => {
		console.log(`HTTP server listening on ${host}:${httpPort}`)
	})

	// 增强：优雅关闭机制
	let isShuttingDown = false

	const shutdown = async (signal: string): Promise<void> => {
		if (isShuttingDown) {
			console.log('[Shutdown] Already shutting down...')
			return
		}
		isShuttingDown = true
		console.log(`[Shutdown] Received ${signal}, starting graceful shutdown...`)

		// 设置强制退出超时
		const forceExitTimer = setTimeout(() => {
			console.error('[Shutdown] Graceful shutdown timeout, forcing exit')
			process.exit(1)
		}, GRACEFUL_SHUTDOWN_TIMEOUT)

		try {
			// 1. 停止接受新连接
			console.log('[Shutdown] Stopping HTTP server...')
			await new Promise<void>((resolve) => {
				httpServer.close(() => {
					console.log('[Shutdown] HTTP server closed')
					resolve()
				})
			})

			// 2. 停止 TCP 服务器并断开所有连接
			console.log('[Shutdown] Stopping TCP server...')
			await tcpServer.stop()
			console.log('[Shutdown] TCP server stopped')

			// 3. 清理资源
			console.log('[Shutdown] Cleaning up resources...')
			executorManager.clearAll()

			clearTimeout(forceExitTimer)
			console.log('[Shutdown] Graceful shutdown completed')
			process.exit(0)
		} catch (err) {
			console.error('[Shutdown] Error during shutdown:', err)
			clearTimeout(forceExitTimer)
			process.exit(1)
		}
	}

	process.on('SIGINT', () => shutdown('SIGINT'))
	process.on('SIGTERM', () => shutdown('SIGTERM'))

	// 处理未捕获的异常
	process.on('uncaughtException', (err) => {
		console.error('[Error] Uncaught exception:', err)
		shutdown('uncaughtException')
	})

	// 处理未捕获的 Promise 拒绝
	process.on('unhandledRejection', (reason) => {
		console.error('[Error] Unhandled rejection:', reason)
	})

	console.log('[Server] Ready. Press Ctrl+C to stop.')
}

main().catch((err: unknown) => {
	console.error('Failed to start:', err)
	process.exit(1)
})
