# 입채 (IPCHAE) Build Execution Checklist

## 0. 시작 전
1. `docs/00_MASTER_BUILD_SPEC.md` 검토
2. 배포 경로 결정(Cloudflare Pages 권장)
3. Supabase 프로젝트 생성
4. Starter/Part 초기 수량 확정(팩/템플릿/공식파츠)

---

## 1. 프로젝트 부트스트랩
1. React + TypeScript + Vite 생성
2. 라우팅 구성 (`/`, `/studio/:projectId`, `/parts`, `/share/:shareSlug`, `/part/:partShareSlug`, `/collab/:inviteCode`, `/help`)
3. 기본 레이아웃(TopBar/ToolDock/MainStage/Inspector/LayerStrip)

완료 기준:
1. Studio/Parts/Share 페이지 라우트 접근 가능
2. 라우트 직접 접근/새로고침 정상

---

## 2. Starter Scaffold Kit
1. 홈 Quick Start 카드(Blank/Free Draw/Starter)
2. Studio Starter Drawer(팩/템플릿/파츠)
3. 템플릿 삽입 + 비율 슬라이더(head/body/leg)
4. Part Snap(결합 포인트/오토미러)
5. 카탈로그 로컬 fallback(JSON 번들)
6. 스타일 탭(Nendo/Moe/Minecraft/Roblox) 구현

완료 기준:
1. 템플릿 선택 후 3초 내 편집 가능
2. 최소 8 pack / 40 template / 220 official parts 제공
3. 네트워크 실패 시 로컬 카탈로그로 시작 가능

---

## 3. 조형 코어
1. Three.js scene/camera/controller 구성
2. Free Draw 브러시 입력 처리
3. Add Blob / Push-Pull / Smooth / Carve 구현
4. Undo/Redo 스택 구현
5. Multi-view overlay(front/right/top) 토글

완료 기준:
1. Draw->Build->Polish 루프가 실제 동작
2. 30fps 근접 성능 유지

---

## 4. Part Browser + Import/레이어/색상
1. Parts 브라우저(카테고리/필터/검색/정렬)
2. 파츠 적용 전 ghost preview
3. `Save Part`(내 파츠 저장, 기본 private)
4. `Publish Part`(private->unlisted/public)
5. Mesh Import(STL/PLY/OBJ/GLB)
6. Import normalize(recenter/scale)
7. 레이어 CRUD
8. 활성 레이어 기반 색상 도포
9. PLY export용 색상 데이터 경로 준비

완료 기준:
1. 외부 mesh 임포트 후 편집 가능
2. 내 파츠 저장/재사용 가능
3. 카테고리/필터로 파츠 탐색 가능
4. Layer Strip에서 파츠 분리가 가능

---

## 5. Validation + Export
1. thin wall / non-manifold / open edges / self-intersection 검사
2. joint clearance 검사(스냅핏 모드)
3. error/warning UI 분리
4. STL/PLY Export 구현

완료 기준:
1. error 존재 시 export 차단
2. STL/PLY 파일 슬라이서 로드 성공

---

## 6. Local-first 저장
1. IndexedDB(또는 localForage) 저장소 구현
2. 2초 디바운스 자동 저장
3. 홈 Recent Projects 복원
4. My Parts 로컬 캐시 복원

완료 기준:
1. 새로고침/재진입 시 프로젝트 복구
2. 오프라인에서도 편집 지속
3. 내 private 파츠 재사용 가능

---

## 7. Share + Remix + OG
1. 프로젝트 Share URL 생성/복사
2. 파츠 Share URL 생성/복사
3. Share 페이지 3D 뷰어(read-only)
4. CTA 문구 `이걸 이용해서 고쳐보시겠어요?` 노출
5. 프로젝트 Clone 로직
6. 파츠 Import/Remix 로직
7. 이벤트 수집(조회/CTA/클론/임포트)
8. slug 기반 OG 메타 응답 구현(프로젝트/파츠)

완료 기준:
1. 비로그인 사용자 project/part URL 조회 가능
2. 로그인 사용자 Clone/Import 후 편집 가능
3. SNS/메신저 미리보기에서 OG 이미지 정상
4. private 파츠 비소유자 접근 차단

---

## 8. Real-time Collaboration
1. collaborator role 모델(owner/editor/viewer) 구현
2. 협업 초대 링크 생성/만료 처리
3. 세션 입장/퇴장 + presence heartbeat 구현
4. mesh lock 획득/갱신/해제 API 연결
5. lock 상태 하이라이트(점유자 표시) UI 구현
6. operation patch 송신/수신 + version ack 처리
7. conflict 처리(`CONFLICT_STALE_BASE`) + 재적용 UX 구현
8. 호스트 강제해제/강제퇴장 도구 구현
9. checkpoint 저장(주기+누적 op 기준) 구현

완료 기준:
1. 2~4명 동시 접속에서 편집 동기화 정상
2. 동일 메시 동시 수정 시 lock으로 충돌 억제
3. viewer role은 read-only 유지
4. 세션 종료 후 최신 checkpoint 복원 가능

---

## 9. Gamification
1. 업적 카탈로그(코드/조건/보상 XP) 시드 데이터 구성
2. 툴 사용 이벤트 수집(`toolId`, `countDelta`, `projectId`) 연결
3. XP 적립 ledger + 레벨 계산 로직 구현
4. 업적 진행도 누적/해금 평가 로직 구현
5. 공유 성과(owner reward) XP 지급 연결(clone/import/remix)
6. `eventKey` 기반 중복 지급 방지 구현
7. UI 반영(Level 배지, XP 바, 업적 토스트, `/account` 업적 탭)

완료 기준:
1. 툴 첫 사용/마일스톤 업적 해금 + XP 적립 정상
2. 타인 공유 사용 시 owner XP 적립 정상
3. self-action/중복 이벤트에서 XP 미적립 보장
4. 레벨업 시 Top Bar와 계정 페이지 동기화 정상

---

## 10. Supabase 연동
1. `docs/01_SUPABASE_SCHEMA_AND_RLS.sql` 적용
2. Auth 연결(OTP/OAuth)
3. projects/project_versions/layers CRUD
4. starter_* / parts / part_shares / part_remixes / part_events 연결
5. project_shares / project_remixes / share_events 연결
6. project_collaborators / project_collab_sessions / project_presence / project_mesh_locks / project_ops 연결
7. gamification_profiles / achievement_catalog / user_achievement_progress / xp_events 연결
8. Storage(scene/exports/thumbs/starter-assets/share-og/part-files/part-preview/part-og) 설정
9. sync 상태 배지 구현

완료 기준:
1. 로그인 후 클라우드 저장/복원
2. RLS 위반 없이 owner 데이터만 접근
3. public/unlisted/private visibility 정책 검증 완료
4. collaboration role/lock 정책 검증 완료
5. gamification 쓰기 경로(server-side only) 검증 완료

---

## 11. 배포
1. `docs/02_DEPLOYMENT_RUNBOOK.md` 따라 설정
2. 환경변수 설정
3. SPA rewrite/fallback 설정
4. Supabase redirect URL 등록
5. share/part OG 응답 경로(Worker/Function) 연결

완료 기준:
1. 프로덕션 도메인 동작
2. `/studio/:id`, `/share/:slug`, `/part/:slug` 새로고침 정상
3. Auth + 저장 + export + share + collab + part-share + gamification 정상

---

## 12. QA 최종
1. 아동 사용자 시나리오 테스트(60초 내 Starter 베이스)
2. 아동 사용자 시나리오 테스트(10분 내 캐릭터 베이스)
3. project URL -> clone -> 수정 시나리오 테스트
4. part URL -> import/remix -> 수정 시나리오 테스트
5. private->public 파츠 전환 테스트
6. 오프라인->온라인 sync 테스트
7. 대용량 씬 성능 테스트
8. 오류 메시지/가이드 문구 검수
9. 업적 해금/XP 적립/레벨업 시나리오 테스트
10. self-action/중복 이벤트 차단 테스트
11. 협업 세션(2~4명) 동시편집/lock/conflict 시나리오 테스트

완료 기준:
1. Master Spec Done 조건 충족
