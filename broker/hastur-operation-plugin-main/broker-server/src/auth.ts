import type { Request, Response, NextFunction } from 'express'
import type { ApiResponse } from './types.js'

export function createAuthMiddleware(token: string) {
	return (req: Request, res: Response, next: NextFunction): void => {
		const auth = req.headers.authorization
		if (!auth || !auth.startsWith('Bearer ')) {
			res.status(401).json({
				success: false,
				error: 'Authentication required',
				hint: 'Include an Authorization header with Bearer token: Authorization: Bearer <token>. The token was printed when the broker-server started.',
			} satisfies ApiResponse)
			return
		}

		const providedToken = auth.slice(7)
		if (providedToken !== token) {
			res.status(401).json({
				success: false,
				error: 'Invalid authentication token',
				hint: 'Check the auth token. It was printed when the broker-server started with --auth-token or auto-generated.',
			} satisfies ApiResponse)
			return
		}

		next()
	}
}
