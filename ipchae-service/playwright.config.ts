import { defineConfig, devices } from '@playwright/test';

const PORT = 4173;

export default defineConfig({
	testDir: './e2e',
	timeout: 30_000,
	fullyParallel: true,
	use: {
		baseURL: `http://127.0.0.1:${PORT}`,
		trace: 'on-first-retry'
	},
	projects: [
		{
			name: 'chromium',
			use: { ...devices['Desktop Chrome'] }
		}
	],
	webServer: {
		command: `npm run dev -- --host 127.0.0.1 --port ${PORT}`,
		port: PORT,
		reuseExistingServer: true
	}
});

