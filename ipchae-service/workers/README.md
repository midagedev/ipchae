# Workers

## Dynamic OG Worker
`share-og-worker.js`는 `/share/:slug`, `/part/:slug` 요청에서 slug별 OG 메타를 렌더링하는 템플릿입니다.

필수 환경변수:
1. `SUPABASE_URL`
2. `SUPABASE_ANON_KEY`
3. `APP_BASE_URL`

Cloudflare Worker 라우팅 예시:
1. `example.com/share/*`
2. `example.com/part/*`

