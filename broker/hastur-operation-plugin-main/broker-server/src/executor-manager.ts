import type { ExecutorInfo } from './types.js'

export class ExecutorManager {
	private executors: Map<string, ExecutorInfo> = new Map()

	add(executor: ExecutorInfo): void {
		this.executors.set(executor.id, executor)
	}

	remove(id: string): boolean {
		return this.executors.delete(id)
	}

	get(id: string): ExecutorInfo | undefined {
		return this.executors.get(id)
	}

	getAll(): ExecutorInfo[] {
		return Array.from(this.executors.values())
	}

	findById(id: string): ExecutorInfo | undefined {
		return this.executors.get(id)
	}

	findByProjectName(name: string, type?: 'editor' | 'game'): ExecutorInfo | undefined {
		const lower = name.toLowerCase()
		for (const executor of this.executors.values()) {
			if (executor.project_name.toLowerCase().includes(lower) && executor.status === 'connected') {
				if (type && executor.type !== type) continue
				return executor
			}
		}
		return undefined
	}

	findByProjectPath(path: string, type?: 'editor' | 'game'): ExecutorInfo | undefined {
		const lower = path.toLowerCase()
		for (const executor of this.executors.values()) {
			if (executor.project_path.toLowerCase().includes(lower) && executor.status === 'connected') {
				if (type && executor.type !== type) continue
				return executor
			}
		}
		return undefined
	}

	// 清理所有 executor（用于优雅关闭）
	clearAll(): void {
		const count = this.executors.size
		this.executors.clear()
		console.log(`[ExecutorManager] Cleared ${count} executors`)
	}

	// 获取 executor 数量
	size(): number {
		return this.executors.size
	}
}
