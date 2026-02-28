import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [sveltekit()],
	build: {
		chunkSizeWarningLimit: 550,
		rollupOptions: {
			output: {
				manualChunks(id) {
					if (id.includes('node_modules/three/examples/')) return 'vendor-three-extras';
					if (id.includes('node_modules/three/')) return 'vendor-three';
					if (id.includes('node_modules/@spectrum-web-components/')) return 'vendor-spectrum';
					return undefined;
				}
			}
		}
	},
	test: {
		include: ['src/**/*.{test,spec}.{ts,js}'],
		environment: 'node'
	}
});
