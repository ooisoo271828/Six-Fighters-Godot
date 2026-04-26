import { defineConfig } from 'vite'

export default defineConfig({
	build: {
		lib: {
			entry: 'src/index.ts',
			formats: ['es'],
			fileName: () => 'index.js',
		},
		outDir: 'dist',
		rollupOptions: {
			external: ['express', 'commander', 'crypto', 'net', 'http', 'os', 'path', /^node:/],
		},
	},
})
