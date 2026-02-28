# IPCHAE Svelte + Supabase 통합 병렬 오케스트레이션 계획 (Editor 포함)

기준일: 2026-02-28  
대상 저장소: `/Users/hckim/repo/ipchae/ipchae-service`  
참조 MVP 코드: `/Users/hckim/repo/ipchae/app` (SvelteKit + Three.js `FixedDraftStage`)

## 1. 목표
1. 에디터 포함 전체 MVP를 Svelte 기반으로 완성에 가깝게 추진한다.
2. 데이터/권한/협업/게이미피케이션을 Supabase 스키마와 정합되게 동시 개발한다.
3. 병렬 진행 시 의존성 충돌을 최소화하도록 선행 조건, 병렬 가능 구간, 차단 게이트를 명시한다.

## 2. 이번 계획에서의 구현 범위
1. Studio 핵심(에디터): Draw/Fill/Erase, Mirror, Slice Layer, Undo, 카메라/뷰 전환
2. Starter/Parts: Starter 카탈로그, Parts 브라우저, Save/Publish, Import/Remix
3. Validation/Export: 최소 검증 세트 + STL/PLY export
4. Local-first + Sync: IndexedDB 기반 자동저장, 로그인 시 Supabase 동기화
5. Share/OG: `/share/:slug`, `/part/:slug`, 동적 OG 메타
6. Collaboration: invite/session/presence/lock/ops/conflict/checkpoint
7. Gamification: tool/share 이벤트, XP/레벨/업적, idempotency
8. Deploy/QA: Cloudflare Pages + Supabase 운영 검증

## 3. 현재 MVP 레퍼런스에서 바로 가져올 것
1. Studio 레이아웃/툴 제어 UI 패턴: `/app/src/routes/studio/[projectId]/+page.svelte`
2. Stage 핵심 제스처/렌더링 파이프라인: `/app/src/lib/stage/FixedDraftStage.svelte`
3. 이미 작동 중인 핵심 동작:
   1. Draw/Fill/Erase 브러시 흐름
   2. Mirror 드로우
   3. Slice Layer UI/오버레이
   4. Undo/Clear
   5. 뷰 전환, 줌, 팬 모드

## 4. 기술 스택 고정
1. Frontend: SvelteKit(TypeScript) + Three.js
2. Auth/Data/Realtime/Storage: Supabase
3. 배포: Cloudflare Pages(+ Worker/Function for OG)
4. 테스트: Vitest + Playwright + SQL 정책 테스트

## 5. 의존성 중심 트랙 설계
| 트랙 | 내용 | 병렬 가능 여부 | 선행 조건 |
|---|---|---|---|
| T0 Platform | 모노리포/CI/환경변수/공통 타입 | 즉시 가능 | 없음 |
| T1 Editor Core | Stage/툴/입력/Undo/Slice/Mirror | T2, T3와 병렬 | T0 |
| T2 Persistence | IndexedDB, 씬 버전/스냅샷, Sync Queue | T1, T3와 병렬 | T0 |
| T3 Supabase Data | SQL/RLS/Storage/Auth/Repository 계층 | T1, T2와 병렬 | T0 |
| T4 Starter/Parts | 카탈로그/브라우저/저장/게시/리믹스 | T1, T3 후반과 병렬 | T1 + T3 기본 CRUD |
| T5 Share/OG | Share URL/CTA/clone/import/OG | T4와 병렬 | T3 + T4 최소 기능 |
| T6 Collaboration | invite/session/presence/lock/ops | 일부 병렬 가능 | T1 scene op 계약 + T3 realtime |
| T7 Gamification | 이벤트 수집/XP/업적/레벨 | 병렬 가능 | T1 이벤트 + T5/T6 이벤트 |
| T8 QA/Release | 통합/성능/보안/배포 | 마지막 집중 | T1~T7 |

## 6. 핵심 의존성 그래프 (실제 차단 지점)
1. `T0 -> (T1, T2, T3)`  
2. `T1 + T2 -> Validation/Export 품질 확보`  
3. `T3 -> T4/T5/T6/T7` (DB/RLS/API가 없으면 기능 연결 차단)  
4. `T4 -> T5` (share CTA clone/import 대상이 필요)  
5. `T1(scene op) + T3(realtime) -> T6`  
6. `T1(tool events) + T5/T6(events) -> T7`  
7. `T1~T7 -> T8`

## 7. 단계별 실행안 (8주)
## Phase A (Week 1): 기반 + 에디터 뼈대
1. T0: SvelteKit 워크스페이스, 린트/테스트/CI, env matrix
2. T1: MVP Stage 코드 이관(우선 `FixedDraftStage`), Studio shell 연결
3. T2: SceneState 스키마/IndexedDB 저장소/2초 디바운스 자동저장
4. T3: Supabase 프로젝트, `01_SUPABASE_SCHEMA_AND_RLS.sql` 적용 리허설

게이트 A:
1. `/studio/:projectId`에서 드로우 입력 가능
2. 새로고침 후 로컬 복원 가능

## Phase B (Week 2): 조형 코어 안정화
1. T1: Draw/Fill/Erase 품질 튜닝, Mirror/Slice/Undo 안정화
2. T1: Add Blob/Push-Pull/Smooth/Carve 순차 추가
3. T2: 씬 버전 관리/히스토리 스냅샷/복구 루틴
4. T8(부분): 프레임/입력지연 프로파일링

게이트 B:
1. Draw -> Build -> Polish 루프 동작
2. 기본 작업에서 30fps 근접

## Phase C (Week 3): Starter + Parts
1. T4: Starter pack/template loader + local fallback
2. T4: Part Browser(카테고리/필터/검색/미리보기)
3. T4: Save Part(private) + Publish(unlisted/public)
4. T3: parts/part_shares/part_events 경로 연결

게이트 C:
1. Starter에서 3초 이내 편집 시작
2. 내 파츠 저장/재사용 가능

## Phase D (Week 4): Validation + Export + Import
1. T1: validation adapter 연결(non_manifold/open_edges/self_intersection/thin wall 최소 세트)
2. T1/T2: export 파이프라인(STL/PLY)
3. T4: Mesh Import(STL/PLY/OBJ/GLB) + normalize(recenter/scale)
4. T2: export/validation 결과 저장 메타 정리

게이트 D:
1. error 존재 시 export 차단
2. export 파일 슬라이서 로드 성공

## Phase E (Week 5): Supabase Sync + Share/OG
1. T3: Auth(OTP/OAuth), project/version/layer/storage 연동
2. T2/T3: sync 상태(`local/syncing/synced/failed`)와 충돌 처리
3. T5: share/part URL 생성/조회/CTA clone/import/remix
4. T5: Cloudflare Worker/Function OG 주입

게이트 E:
1. 익명 공유 조회 + 로그인 후 clone/import 성공
2. OG title/description/image slug별 반영

## Phase F (Week 6): Collaboration
1. T6: collaborator role(owner/editor/viewer)
2. T6: invite/session join, presence heartbeat
3. T6: lock acquire/renew/release + conflict(`CONFLICT_STALE_BASE`)
4. T6: patch 적용 + checkpoint
5. T1: lock 상태 표시 및 편집 제한 UI

게이트 F:
1. 2~4인 동시세션 기본 동작
2. lock 기반 충돌 억제

## Phase G (Week 7): Gamification
1. T7: tool/share/remix 이벤트 수집
2. T7: XP ledger + level 계산 + achievement 평가
3. T7: `eventKey` idempotency(중복 지급 방지)
4. T7: `/account` 반영(레벨/XP/업적)

게이트 G:
1. 툴 첫 사용/마일스톤 보상 정상
2. self-action/중복 보상 차단

## Phase H (Week 8): 통합 QA + 배포
1. T8: E2E(핵심 시나리오 19.3 기준) + 성능/권한 회귀
2. T8: RLS/Storage 정책 점검
3. T8: Cloudflare Pages 배포 + redirect/rewrites/auth redirect 점검

게이트 H:
1. Master Spec Done 기준 핵심 항목 충족

## 8. 병렬 개발 시 충돌 방지 운영 규칙
1. 브랜치 네이밍: `codex/t{번호}-{topic}` 고정
2. 각 트랙 PR은 `contracts/` 타입 변경 시 먼저 계약 PR 병합
3. 파일 소유 경계:
   1. T1: `src/lib/stage/**`, `src/features/editor/**`
   2. T2: `src/core/persistence/**`, `src/core/sync/**`
   3. T3: `src/core/supabase/**`, `supabase/**`
   4. T4/T5/T6/T7: 기능별 디렉토리 분리
4. 공통 파일(`app state`, `route layout`)은 하루 1회 통합 창구 PR로만 수정
5. 매일 리베이스 대신 `main` 정기 머지(충돌 표면 조기 노출)

## 9. 계약(Contract) 우선 개발 항목
1. SceneState/OperationPatch/ValidationReport 타입
2. API 에러코드 표준:
   1. `LOCK_HELD_BY_OTHER`
   2. `CONFLICT_STALE_BASE`
   3. `ROLE_FORBIDDEN`
3. 이벤트 스키마:
   1. `tool_used`
   2. `share_clone_success`
   3. `part_import_success`
   4. `part_remix_success`

## 10. 리스크와 대응
1. 에디터 코드 이관 리스크: `FixedDraftStage`를 한 번에 갈아엎지 않고 adapter 레이어로 감싼 뒤 단계 치환
2. RLS 정책 리스크: SQL 정책 테스트를 CI 필수 게이트로 승격
3. 성능 리스크: 매 Phase 종료 시 프레임/입력 지표를 수치로 기록
4. 협업 리스크: lock lease/heartbeat 만료 시나리오를 통합테스트에 강제 포함
5. OG 리스크: 배포 후 `curl` 스모크와 실제 메신저 미리보기 검증 분리 수행

## 11. 완료 기준 (Editor 포함)
1. Start -> Draw -> Build -> Polish -> Export를 신규 사용자 시나리오로 완주 가능
2. Starter/Parts/Import/Validation/Export가 모두 실동작
3. 로컬 자동저장 + 로그인 시 Supabase 동기화가 안정 동작
4. Share/Part URL 조회, clone/import/remix, OG가 정상 동작
5. 협업 2~4인 세션에서 presence/lock/patch/checkpoint 동작
6. 업적/XP/레벨, 중복 지급 방지 규칙 동작
7. Cloudflare Pages 프로덕션 경로 새로고침 및 Auth redirect 정상

## 12. 이번 주 즉시 실행 순서
1. T0/T1: SvelteKit 기반 Studio shell과 `FixedDraftStage` 이관 확정
2. T2: SceneState + IndexedDB 저장/복원 구현
3. T3: Supabase 스키마/RLS/Storage 리허설 적용
4. T4: Starter/Parts 로컬 카탈로그 + 브라우저 최소 UI
5. T1/T2: Validation/Export 인터페이스 선고정

## 13. 실행 로그
1. 2026-02-28 (commit `8cbe4ff`)
   1. T0/T1 완료: SvelteKit workspace 부트스트랩, Studio/FixedDraftStage 이관
   2. T2 시작: IndexedDB 기반 Studio snapshot 자동저장/복원
   3. T3 시작: Supabase client/sync queue 기초 계층 추가
2. 2026-02-28 (commit `a8b4421`)
   1. T4 시작: Starter 카탈로그 로더(원격 우선 + 로컬 fallback)
   2. T4 진행: Parts 브라우저 필터 UI, Studio Starter 패널 추가
   3. T5 시작: Share/Part 데모 CTA -> Studio clone/import 경로 추가
3. 2026-02-28 (commit `434a58e`)
   1. T7 시작: 로컬 XP/레벨/업적 엔진 및 `/account` 시각화 연결
   2. T6 시작: 협업 invite/heartbeat/lock 로컬 시뮬레이터 추가
4. 2026-02-28 (진행 중)
   1. T1/T5: Validation + STL/PLY export 루프 연결
   2. T5/T6: Share/Collab Supabase 경로 우선 + 로컬 fallback 구조 적용
   3. T5: Cloudflare Worker 기반 동적 OG 템플릿 추가
5. 2026-02-28 (commit `3e4ff89`)
   1. T1 완료도 상승: Stage summary 추출 + validation report + STL/PLY download 연결
   2. T4 완료도 상승: My Parts 저장/가시성 전환(private/unlisted/public) 연결
   3. T3/T5/T6 진행: Share/Collab 경로 Supabase 우선 처리와 fallback 정리
6. 2026-02-28 (commit `673e3b8`)
   1. T5 진행: Studio에서 Share 링크 생성 + 클립보드 복사 + 로컬 share registry fallback
7. 2026-02-28 (commit `fc8a9b5`)
   1. T1 성능: Studio route에서 Stage 동적 import(lazy load) 적용
8. 2026-02-28 (commit `fceec88`)
   1. T8 진행: Playwright 스모크 테스트(home/parts/share) 도입 및 `test:e2e` 파이프라인 추가
   2. T4 품질: Parts 필터 라벨 접근성 보정(`label for/id`)으로 role 기반 테스트 안정화
9. 2026-02-28 (commit `af7300f`)
   1. T5/T6 진행: Project share 페이지에 `같이 편집하기` CTA 추가 및 collab invite 생성 경로 연결
   2. T4/T5 진행: My Parts에서 Part share 링크 생성/복사 플로우 추가
   3. T6 안정화: inviteCode 파서가 UUID/role suffix/colon 포맷을 안전하게 해석하도록 수정
10. 2026-02-28 (commit `62a8c88`)
   1. T4/T1 진행: Mesh Import 서비스(STL/PLY/OBJ/GLB 감지/파싱/제한 검사) 추가
   2. T1/T8 진행: Studio 상단 Import 액션 연결 + Import summary/warning 노출 + 스모크 테스트 확장
11. 2026-02-28 (commit `789456c`)
   1. T8 성능: Vite manualChunks(`three`, `three/examples`, `spectrum`) 분할 적용
   2. T8 운영: chunk warning 임계치 조정으로 빌드 경고 노이즈 축소
12. 2026-02-28 (commit `e72151e`)
   1. T5 진행: `/share/:slug`, `/part/:slug`에 동적 `<svelte:head>` OG/Twitter 메타 연결
13. 2026-02-28 (commit `f32da05`)
   1. T2/T3 성능: Studio autosave sync queue에 `projectId` 기준 coalescing 적용(중복 스냅샷 병합)
   2. T8 품질: sync queue coalescing 동작 테스트 추가
