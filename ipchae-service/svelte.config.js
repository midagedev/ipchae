import adapter from '@sveltejs/adapter-static';

const basePath = process.env.BASE_PATH ?? '';

if (basePath !== '' && !basePath.startsWith('/')) {
	throw new Error('BASE_PATH must be empty or start with "/"');
}

/** @type {import('@sveltejs/kit').Config} */
const config = {
	kit: {
		adapter: adapter({
			pages: 'build',
			assets: 'build',
			fallback: '404.html',
			precompress: false,
			strict: false
		}),
		paths: {
			base: basePath
		},
		prerender: {
			handleHttpError: 'warn'
		}
	}
};

export default config;
