# 입채 (IPCHAE) Deployment Runbook

## 1. 목표
입채 (IPCHAE) 프론트엔드를 배포하고, 커스텀 도메인을 Cloudflare에 연결하며, Supabase 환경과 안전하게 연동한다.

이 문서는 두 경로를 제공한다.
1. Option A: Cloudflare Pages (권장)
2. Option B: GitHub Pages + Cloudflare DNS

---

## 2. 공통 준비

## 2.1 리포지토리 준비
1. GitHub repository 생성
2. 기본 브랜치 `main`
3. 배포 브랜치 정책
4. production: `main`
5. staging: `develop` (선택)

## 2.2 환경변수 정의
프론트엔드 환경변수:
1. `VITE_SUPABASE_URL`
2. `VITE_SUPABASE_ANON_KEY`
3. `VITE_APP_ENV` (`production`/`staging`)
4. `VITE_STARTER_CATALOG_VERSION`
5. `VITE_PART_CATALOG_VERSION`
6. `VITE_ACHIEVEMENT_CATALOG_VERSION`
7. `VITE_COLLAB_MAX_EDITORS`

서버/함수 환경변수(Edge Functions/Workers):
1. `SUPABASE_SERVICE_ROLE_KEY`
2. `SUPABASE_URL`
3. `APP_BASE_URL`
4. `GAMIFICATION_EVENT_SALT`
5. `COLLAB_LOCK_LEASE_SEC`
6. `COLLAB_LOCK_HEARTBEAT_SEC`

보안 원칙:
1. `service_role` 키는 절대 프론트엔드에 넣지 않는다.
2. Edge Functions 또는 서버에서만 service role 사용.

## 2.3 SPA 라우팅 대응
React Router 사용 시 rewrite/fallback 필요.

필수 경로:
1. `/studio/:projectId`
2. `/parts`
3. `/share/:shareSlug`
4. `/part/:partShareSlug`
5. `/collab/:inviteCode`

---

## 3. Option A: Cloudflare Pages (권장)

## 3.1 Pages 프로젝트 생성
1. Cloudflare Dashboard -> Pages -> Create project
2. GitHub 연결
3. Repository 선택

## 3.2 Build 설정
1. Framework preset: Vite (또는 None)
2. Build command: `npm ci && npm run build`
3. Build output directory: `dist`
4. Node version: 프로젝트와 동일 버전 지정

## 3.3 환경변수 설정
Pages -> Settings -> Environment Variables
1. `VITE_SUPABASE_URL`
2. `VITE_SUPABASE_ANON_KEY`
3. `VITE_APP_ENV`
4. `VITE_STARTER_CATALOG_VERSION`
5. `VITE_PART_CATALOG_VERSION`
6. `VITE_ACHIEVEMENT_CATALOG_VERSION`
7. `VITE_COLLAB_MAX_EDITORS`

## 3.4 SPA rewrite
루트에 `_redirects` 파일 추가:
```txt
/* /index.html 200
```

## 3.5 Share/Part OG 동적 메타 처리
공유 URL(`/share/:slug`, `/part/:slug`)은 정적 HTML만으로 OG 동적 주입이 어렵다.

권장 방식:
1. Cloudflare Worker 또는 Pages Function에서 `GET /share/:slug`, `GET /part/:slug` 처리
2. Supabase에서 share/part-share 메타 조회
3. slug별 `og:title`, `og:description`, `og:image`를 포함한 HTML 반환
4. 앱 진입 스크립트를 포함해 SPA hydration

검증:
1. `curl https://yourdomain.com/share/{slug}` 에 OG 메타 포함
2. `curl https://yourdomain.com/part/{slug}` 에 OG 메타 포함

## 3.6 커스텀 도메인 연결
1. Pages -> Custom domains -> Add domain
2. Cloudflare DNS 자동 레코드 확인
3. SSL mode: Full (strict) 권장

## 3.7 Supabase Auth 허용 도메인 등록
Supabase Dashboard -> Auth -> URL Configuration
1. Site URL: `https://yourdomain.com`
2. Redirect URLs:
3. `https://yourdomain.com/*`
4. `https://<project>.pages.dev/*`

## 3.8 배포 검증
1. `/` 로드
2. `/studio/test` 새로고침
3. `/parts` 접근
4. `/share/test-slug` 접근
5. `/part/test-part-slug` 접근
6. `/collab/test-invite` 접근
7. 로그인/로그아웃
8. Supabase 호출 성공 여부
9. 협업 Realtime 채널 subscribe 성공 여부

---

## 4. Option B: GitHub Pages + Cloudflare DNS

## 4.1 GitHub Actions 배포 예시
`.github/workflows/deploy.yml`
```yml
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npm run build
      - run: cp dist/index.html dist/404.html
      - uses: actions/upload-pages-artifact@v3
        with:
          path: dist

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

## 4.2 Vite base 설정
1. `username.github.io/repo`면 `base: '/repo/'`
2. 커스텀 도메인 루트면 `base: '/'`

## 4.3 커스텀 도메인
1. GitHub Pages Custom domain 설정
2. Cloudflare DNS에서 CNAME/A 레코드 연결
3. HTTPS 강제 활성화

## 4.4 주의
1. SPA fallback을 위해 `404.html` 필수
2. 동적 OG 처리를 위해 별도 Worker 경로 권장
3. 빌드/대역폭/아티팩트 제한은 GitHub 정책 준수

---

## 5. Supabase 운영 체크리스트

## 5.1 필수
1. SQL 스키마 적용: `docs/01_SUPABASE_SCHEMA_AND_RLS.sql`
2. RLS 정책 검증
3. Storage 버킷 확인:
4. `scene`, `exports`, `thumbs`, `starter-assets`, `share-og`
5. `part-files`, `part-preview`, `part-og`
6. Auth provider 설정(OTP/OAuth)
7. gamification 테이블(read/write 경로) 점검
8. collaboration 테이블(read/write/role/lock 경로) 점검
9. Realtime publication에 collaboration 테이블 포함 확인

## 5.2 권장
1. Edge Functions 배포 파이프라인 구축
2. share/part OG 이미지 생성 함수 운영
3. starter/part 카탈로그 배포 파이프라인 운영
4. 에러/성능 로깅 수집(Sentry 등)
5. DB 백업 및 migration 전략 수립
6. gamification 지급 함수(event idempotency 포함) 운영

---

## 6. 배포 결정 가이드

Cloudflare Pages 권장 조건:
1. SPA rewrite와 프리뷰 배포가 중요
2. Cloudflare DNS/SSL 이미 사용 중
3. 공유 URL 동적 OG 처리 필요

GitHub Pages 고려 조건:
1. 단순 정적 호스팅이면 충분
2. GitHub 중심 워크플로우 선호
3. OG 동적 처리용 별도 Worker 운영 가능

입채 (IPCHAE) 현재 권장:
1. **Cloudflare Pages + Supabase + Cloudflare Worker(share/part OG)**

---

## 7. 배포 완료 정의 (DoD)
1. 프로덕션 도메인 HTTPS 정상
2. `/studio/:projectId` 새로고침 200
3. `/share/:shareSlug` 새로고침 200
4. `/part/:partShareSlug` 새로고침 200
5. Supabase Auth 로그인/세션 유지 정상
6. 프로젝트 저장/복원 정상
7. project/part share 조회/clone/import 정상
8. OG 미리보기(제목/설명/이미지) 정상
9. Export(STL/PLY) 다운로드 정상
10. 업적/XP/레벨 조회 API 정상
11. 협업 세션 join/presence/lock/op 동작 정상

---

## 8. 트러블슈팅
1. 404 on refresh
2. 원인: SPA rewrite 미설정
3. 해결: `_redirects` 또는 fallback 설정

4. Auth redirect mismatch
5. 원인: Supabase Redirect URLs 누락
6. 해결: 배포/프리뷰 도메인 모두 등록

7. RLS permission denied
8. 원인: owner_id 불일치 또는 policy 누락
9. 해결: SQL 정책 재적용 및 auth.uid() 확인

10. Storage upload denied
11. 원인: bucket policy 누락 또는 경로 규칙 불일치
12. 해결: `uid/project/...`, `private/{uid}/{part_id}` 규칙 통일

13. Share/Part OG 미리보기 미노출
14. 원인: 동적 메타 주입 누락 또는 og image 접근 불가
15. 해결: Worker 응답 HTML 메타 검증 + `share-og`/`part-og` 정책 확인

16. Part Browser 로드 실패
17. 원인: part 카탈로그 query/RLS/인덱스 문제
18. 해결: visibility 정책, 인덱스, 캐시 버전(`VITE_PART_CATALOG_VERSION`) 점검
