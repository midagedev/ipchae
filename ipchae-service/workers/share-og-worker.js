/**
 * Cloudflare Worker template for dynamic OG metadata on:
 * - /share/:slug
 * - /part/:slug
 *
 * Configure:
 * - SUPABASE_URL
 * - SUPABASE_ANON_KEY
 * - APP_BASE_URL
 */

function htmlEscape(value) {
	return String(value)
		.replaceAll('&', '&amp;')
		.replaceAll('<', '&lt;')
		.replaceAll('>', '&gt;')
		.replaceAll('"', '&quot;')
		.replaceAll("'", '&#039;');
}

async function fetchJson(url, headers) {
	const response = await fetch(url, { headers });
	if (!response.ok) return null;
	return response.json();
}

async function loadProjectShare(env, slug) {
	const url = `${env.SUPABASE_URL}/rest/v1/project_shares?share_slug=eq.${encodeURIComponent(slug)}&select=title,description,og_image_path,visibility&limit=1`;
	const rows = await fetchJson(url, {
		apikey: env.SUPABASE_ANON_KEY,
		authorization: `Bearer ${env.SUPABASE_ANON_KEY}`
	});
	if (!rows?.[0]) return null;
	if (!['public', 'unlisted'].includes(rows[0].visibility)) return null;
	return rows[0];
}

async function loadPartShare(env, slug) {
	const url = `${env.SUPABASE_URL}/rest/v1/part_shares?share_slug=eq.${encodeURIComponent(slug)}&select=title,description,og_image_path,visibility&limit=1`;
	const rows = await fetchJson(url, {
		apikey: env.SUPABASE_ANON_KEY,
		authorization: `Bearer ${env.SUPABASE_ANON_KEY}`
	});
	if (!rows?.[0]) return null;
	if (!['public', 'unlisted'].includes(rows[0].visibility)) return null;
	return rows[0];
}

function renderHtml({ title, description, image, path, appBaseUrl }) {
	const safeTitle = htmlEscape(title || 'IPCHAE Share');
	const safeDescription = htmlEscape(
		description || '이걸 이용해서 고쳐보시겠어요? made with IPCHAE'
	);
	const safeImage = htmlEscape(image || `${appBaseUrl}/og/default-share.png`);
	const safeUrl = htmlEscape(`${appBaseUrl}${path}`);

	return `<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>${safeTitle}</title>
  <meta name="description" content="${safeDescription}" />
  <meta property="og:type" content="website" />
  <meta property="og:title" content="${safeTitle}" />
  <meta property="og:description" content="${safeDescription}" />
  <meta property="og:image" content="${safeImage}" />
  <meta property="og:url" content="${safeUrl}" />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${safeTitle}" />
  <meta name="twitter:description" content="${safeDescription}" />
  <meta name="twitter:image" content="${safeImage}" />
  <script>
    window.location.replace('${safeUrl}');
  </script>
</head>
<body>
  <p>Redirecting to <a href="${safeUrl}">${safeUrl}</a></p>
</body>
</html>`;
}

export default {
	async fetch(request, env) {
		const url = new URL(request.url);
		const appBaseUrl = env.APP_BASE_URL || `${url.protocol}//${url.host}`;

		if (url.pathname.startsWith('/share/')) {
			const slug = url.pathname.replace('/share/', '').split('/')[0];
			const share = await loadProjectShare(env, slug);
			if (!share) return new Response('Not found', { status: 404 });
			return new Response(
				renderHtml({
					title: `${share.title} | made with IPCHAE`,
					description: `${share.description || ''} 이걸 이용해서 고쳐보시겠어요?`,
					image: share.og_image_path,
					path: `/share/${slug}`,
					appBaseUrl
				}),
				{ headers: { 'content-type': 'text/html; charset=utf-8' } }
			);
		}

		if (url.pathname.startsWith('/part/')) {
			const slug = url.pathname.replace('/part/', '').split('/')[0];
			const share = await loadPartShare(env, slug);
			if (!share) return new Response('Not found', { status: 404 });
			return new Response(
				renderHtml({
					title: `${share.title} | made with IPCHAE`,
					description: `${share.description || ''} 이걸 이용해서 고쳐보시겠어요?`,
					image: share.og_image_path,
					path: `/part/${slug}`,
					appBaseUrl
				}),
				{ headers: { 'content-type': 'text/html; charset=utf-8' } }
			);
		}

		return new Response('OK');
	}
};

