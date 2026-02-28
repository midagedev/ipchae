# 입채 (IPCHAE) Master Build Spec

## 1. 문서 목적
이 문서는 입채 (IPCHAE)를 처음부터 구현하기 위한 단일 기준 문서다. 이 문서와 `01_SUPABASE_SCHEMA_AND_RLS.sql`, `02_DEPLOYMENT_RUNBOOK.md`, `04_STARTER_SCAFFOLD_CATALOG.md`, `05_SHARING_AND_REMIX_SPEC.md`만으로 MVP 구현/배포를 진행할 수 있게 구성한다.

문서 기준일: 2026-02-28

---

## 2. 제품 정의

### 2.1 한 줄 정의
입채 (IPCHAE)는 "3D 펜처럼 그리고 붙이고 다듬어서" 캐릭터를 만드는 아동 친화형 3D 모델링 툴이다.

### 2.2 핵심 사용자
1. 초등학생(직접 사용)
2. 학부모/교사(보조, 출력)
3. 3D프린팅 입문 취미 사용자

### 2.3 핵심 가치
1. 빠른 시작: 수치/다각형 없이 즉시 시작
2. 즉시 스캐폴딩: 넨도/모에/마크/로블록스형 시작 베이스 제공
3. 직관적 조형: Blob + Push/Pull + Smooth
4. 파츠 생태계: 공식 프리셋 + 유저 파츠(private/public 전환)
5. 공유/바이럴: 프로젝트/파츠 공유 URL + Remix(클론)
6. 출력 가능: STL/PLY Export + 사전 Validation
7. 데이터 안전: Local-first + Supabase Sync
8. 성장 동기: 업적/경험치/레벨 기반 제작 루프

### 2.4 브랜드 표기 규칙
1. 한글 제품명: `입채`
2. 영문 제품명: `IPCHAE`
3. 설명 문구에서는 필요 시 `입체`를 보조 키워드로 사용 가능

---

## 3. 범위 정의

### 3.1 MVP 포함
1. Start Mode 선택(`Blank`, `Free Draw First`, `Starter Scaffold`)
2. Free Draw 3D 스트로크
3. Build 툴(Add Blob, Push/Pull, Pinch/Inflate, Mirror)
4. Polish 툴(Smooth, Carve)
5. Color 적용 및 PLY 색상 Export
6. Validation(두께/비다양체/오픈엣지/자기교차)
7. STL/PLY Export
8. Mesh Import(STL/PLY/OBJ/GLB)
9. Local-first 저장
10. Starter Scaffold Kit(팩/템플릿/파츠 카탈로그)
11. Part Browser(카테고리/스타일/난이도/인기 필터)
12. 유저 파츠 저장/재사용/게시(private->unlisted/public)
13. 프로젝트 공유 URL 생성/복사
14. 파츠 공유 URL 생성/복사
15. 공유 페이지 CTA("이걸 이용해서 고쳐보시겠어요?")
16. 프로젝트/파츠 Remix/Clone(내 라이브러리로 가져오기)
17. 공유 URL별 OG 메타(동적 title/description/image)
18. Supabase 로그인 + 동기화(P1 후보지만 구조는 MVP에서 준비)
19. 카탈로그 원격 로딩 + 오프라인 로컬 fallback
20. 업적 시스템(툴 첫 사용/횟수/공유/재사용 보상)
21. 경험치(XP) 적립 및 레벨업 시스템
22. 공유 결과(타인 clone/import/remix)에 대한 제작자 보상
23. 공유 프로젝트 동시편집(실시간 presence + 메시 단위 점유)

### 3.2 MVP 제외
1. 결제/구독
2. 고급 파라메트릭 제약 CAD
3. 완전 자동 리깅/애니메이션 리타게팅
4. 대규모 협업(동시 5인 이상, 고급 분산 머지)

---

## 4. 사용자 플로우

### 4.1 기본 플로우
1. 프로젝트 생성
2. Start 모드 선택(Blank/Free Draw/Starter)
3. Draw 단계: Free Draw로 실루엣/골격 생성
4. Build 단계: 덩어리 추가 및 표면 확장
5. Polish 단계: 표면 다듬기/조각
6. Export 단계: 검사 후 STL/PLY 저장

### 4.2 Starter 퀵스타트 플로우
1. 홈에서 `Start with Starter` 클릭
2. 스타일 탭 선택(`Nendo`, `Moe`, `Minecraft`, `Roblox`, `Animal`, `Robot`)
3. 템플릿 선택 후 즉시 Stage 삽입
4. 비율 슬라이더(머리/몸통/다리 길이)로 1차 조정
5. 얼굴/헤어/액세서리 파츠를 스냅 배치
6. 이후 Draw/Build/Polish로 자유 조형

### 4.3 Part Browser 플로우
1. Studio에서 `Parts` 패널 오픈
2. 카테고리 선택(Head, Face, Hair, Outfit, Hand, Foot, Props, Voxel Blocks)
3. 필터 선택(스타일/난이도/무료/인기/최신/작성자)
4. 파츠 미리보기 클릭 -> Stage 프리뷰
5. `Apply Part`로 장착
6. 필요 시 `Save as My Part`로 내 라이브러리에 저장

### 4.4 파츠 게시 플로우
1. 사용자가 만든 파츠를 `Save Part` 실행
2. 초기 가시성 `private`
3. 본인 프로젝트에서 재사용
4. 필요 시 `Publish`에서 `unlisted` 또는 `public` 전환
5. 게시된 파츠는 브라우저/공유 URL에서 노출

### 4.5 공유/리믹스 플로우
1. 사용자 A가 프로젝트 또는 파츠에서 `Share` 클릭
2. 공개 범위 선택(`public`, `unlisted`)
3. 공유 URL 생성
4. 사용자 B가 URL 접속 후 결과물 확인
5. 공유 페이지 CTA로 `이걸 이용해서 고쳐보시겠어요?` 클릭
6. 로그인 후 clone/import 실행
7. 사용자 B가 본인 프로젝트/파츠로 수정/재공유

### 4.6 동기화 플로우
1. 비로그인 상태: 로컬 편집
2. 로그인 시: 로컬 프로젝트/내 파츠 클라우드 업로드
3. 이후 자동 백그라운드 sync
4. 충돌 시: latest 우선 + 히스토리 복원

### 4.7 실패 플로우
1. Validation error 발생
2. Stage 하이라이트 + Inspector 오류 목록 노출
3. 수정 후 재검증
4. error=0이면 Export 활성화
5. Import 실패 시 원인(포맷/면수/손상 메쉬) 안내

### 4.8 게이미피케이션 플로우
1. 사용자가 툴 사용/공유/리믹스 같은 행동 수행
2. 이벤트 수집(`tool_used`, `share_clone_success`, `part_import_success` 등)
3. 누적 카운터 업데이트(툴별 횟수, 공유 성과)
4. 업적 조건 충족 시 업적 해금 + XP 적립
5. 누적 XP가 기준치를 넘으면 레벨업
6. 레벨업/업적 해금 토스트와 계정 페이지 히스토리 반영

### 4.9 실시간 동시편집 플로우
1. 오너가 공유 프로젝트에서 `같이 편집` 활성화
2. 초대 링크 또는 collaborator 지정으로 세션 참가자 확보
3. 참가자는 세션 입장 후 presence(커서/카메라/선택 파츠) 송신
4. 편집 전 `mesh_node_id` 단위 lock 요청
5. lock 획득 사용자만 해당 메시 영역 편집 가능
6. 편집 operation patch를 실시간 브로드캐스트
7. 서버는 `base_version`/lock 소유자 검증 후 적용
8. lock 만료/수동 해제/강제 해제 시 다른 사용자가 점유 가능
9. 충돌 시 `CONFLICT_STALE_BASE` 응답 + 최신 상태 pull 후 재적용
10. 세션 종료 시 checkpoint를 `project_versions`에 스냅샷 저장

---

## 5. IA 및 화면 구조

### 5.1 라우트
1. `/` 홈
2. `/studio/:projectId` 편집기
3. `/parts` 파츠 브라우저
4. `/share/:shareSlug` 프로젝트 공유 페이지
5. `/part/:partShareSlug` 파츠 공유 페이지
6. `/collab/:inviteCode` 협업 참여 링크
7. `/help` 도움말
8. `/account` 계정/동기화 상태

### 5.2 Studio 레이아웃
1. Top Bar: 브랜드/프로젝트명/Stepper/Save/Import/Parts/Share/Export/Sync 상태/레벨 배지
2. Left Tool Dock: Start/Draw/Build/Polish 툴
3. Main Stage: 단일 메인 3D 뷰 + 미니 다중시점 토글
4. Right Inspector: 브러시/비율/컬러/메쉬/검증
5. Bottom Layer Strip: Base/Body/Face/Hair/Accessory 레이어
6. Starter Drawer: 팩/템플릿/파츠 빠른 선택
7. Part Browser Drawer: 카테고리/필터/검색/정렬
8. Collaboration Panel: 참여자/역할/점유 메시/팔로우/강제해제

### 5.3 공유 페이지 레이아웃
1. Hero: 썸네일, 제목, 작성자, 조회수
2. Viewer: Orbit 가능한 read-only 3D 뷰
3. Primary CTA: `이걸 이용해서 고쳐보시겠어요?`
4. Secondary CTA: `입채에서 바로 수정하기`
5. Tertiary CTA: `같이 편집하기`
6. Footer CTA: 앱 시작/회원가입 유도

### 5.4 Stepper
1. Start
2. Draw
3. Build
4. Polish
5. Export

---

## 6. 툴 명세

### 6.1 툴 목록
| ID | 이름 | 단계 | 기본 단축키 | 파라미터 |
|---|---|---|---|---|
| `starter_open_catalog` | Open Starter Catalog | Start | `0` | pack, template |
| `starter_insert_template` | Insert Starter Template | Start | `Shift+0` | templateId, scale |
| `starter_proportion_scale` | Proportion Scale | Start/Build | `7` | headRatio, bodyRatio, legRatio |
| `starter_part_snap` | Part Snap | Build | `8` | snapTolerance, autoMirror |
| `parts_open_browser` | Open Part Browser | Build | `P` | category, filters |
| `parts_apply` | Apply Part | Build | `Shift+P` | partId, slot |
| `parts_save_my_part` | Save My Part | Build/Polish | `Ctrl+S` | name, category |
| `parts_publish` | Publish Part | Build/Polish | `Ctrl+Shift+P` | visibility |
| `collab_start_session` | Start Co-edit Session | View | `Shift+C` | maxEditors, inviteMode |
| `collab_join_session` | Join Co-edit Session | View | `Alt+C` | inviteCode |
| `collab_request_lock` | Request Mesh Lock | Build/Polish | `L` | meshNodeId, lockScope |
| `collab_release_lock` | Release Mesh Lock | Build/Polish | `Shift+L` | lockId |
| `collab_follow_user` | Follow Collaborator Camera | View | `F` | targetUserId |
| `tool_free_draw` | Free Draw | Draw | `1` | size, strength |
| `tool_add_blob` | Add Blob | Build | `2` | radius, hardness |
| `tool_push_pull` | Push/Pull | Build | `3` | size, strength |
| `tool_pinch_inflate` | Pinch/Inflate | Build | `4` | size, strength(±) |
| `tool_smooth` | Smooth | Polish | `5` | size, strength |
| `tool_carve` | Carve | Polish | `6` | size, strength |
| `tool_mirror` | Mirror | Build | `M` | axis(x/y/z) |
| `tool_import_mesh` | Import Mesh | Start/Build | `I` | format, scale, recenter |
| `view_reset` | Reset Camera | View | `R` | - |
| `view_wireframe` | Wireframe | View | `W` | on/off |
| `view_multiview` | Multi-view Overlay | View | `V` | front/right/top |

### 6.2 기본 파라미터
1. `brush.size`: 12 (범위 1~60)
2. `brush.strength`: 0.45 (범위 0.05~1.0)
3. `mesh.resolution`: medium (`low`, `medium`, `high`)
4. `mirror.axis`: x
5. `starter.headRatio`: 1.45 (범위 1.0~2.1)
6. `starter.legRatio`: 0.75 (범위 0.45~1.25)
7. `starter.snapTolerance`: 1.6mm
8. `import.maxFileSizeMb`: 25
9. `import.maxTriangles`: 300000
10. `collab.maxEditors`: 4
11. `collab.lockLeaseSec`: 20
12. `collab.lockHeartbeatSec`: 8
13. `collab.idleKickSec`: 60

### 6.3 인터랙션 규칙
1. 툴 전환 시 프리뷰 커서 즉시 변경
2. 입력 종료 후 300ms 디바운스로 메쉬 갱신
3. Undo/Redo 최대 100 스텝
4. Mirror on 시 대응 좌표에 같은 델타 적용
5. Starter 템플릿 삽입 후 500ms 내 조작 가능
6. Starter Part Snap 시 결합 포인트 하이라이트
7. Multi-view Overlay는 메인뷰 조작 중 동기화
8. Import 직후 자동 정렬(recenter, unit normalize)
9. 파츠 브라우저에서 적용 전 ghost preview 표시
10. 실시간 편집 중 메시 변경은 lock 소유자만 가능
11. lock은 lease 기반 자동 만료, heartbeat로 갱신
12. 잠긴 메시는 다른 사용자에게 read-only highlight 표시
13. lock 경합 시 대기열 없이 즉시 실패(`LOCK_HELD_BY_OTHER`) 응답
14. 세션 호스트는 비활성 사용자 lock 강제 해제 가능

---

## 7. Starter Scaffold 상세

### 7.1 Start 모드
1. `Blank`: 빈 씬에서 시작
2. `Free Draw First`: 3D 펜 느낌 자유선부터 시작
3. `Starter Scaffold`: 템플릿 기반 즉시 시작

### 7.2 Starter 카탈로그 최소 구성(MVP)
1. 팩 8개 이상
2. 템플릿 40개 이상
3. 파츠 220개 이상

필수 팩:
1. `nendo_core`
2. `mome_soft`
3. `minecraft_blocky`
4. `roblox_blocky`
5. `animal_friends`
6. `robot_toy`
7. `fantasy_mini`
8. `accessory_booster`

### 7.3 Starter 템플릿 요구 필드
1. `pack_slug`
2. `template_slug`
3. `preview_image_path`
4. `base_scene_path`
5. `default_proportion`(head/body/leg)
6. `part_slots`(face, hair, outfit, accessory)
7. `difficulty`(easy/normal/advanced)
8. `target_style`(`nendo`, `moe`, `minecraft`, `roblox`, ...)

### 7.4 빠른 스캐폴딩 규칙
1. 템플릿 적용 시 기본 레이어 자동 생성
2. 좌우 대칭 파츠는 auto-mirror 기본 ON
3. 초등 저학년 모드에서 고급 파라미터 숨김
4. 첫 60초 안에 베이스 완성 가능한 UX 우선

---

## 8. Part Library 상세

### 8.1 라이브러리 구성
1. `Official Parts`: 운영팀 제공 프리셋
2. `Community Parts`: 유저 공개 파츠
3. `My Parts`: 내 private/unlisted/public 파츠

### 8.2 카테고리 체계(MVP)
1. Head
2. Face
3. Hair
4. Torso
5. Arm/Hand
6. Leg/Foot
7. Outfit
8. Props
9. Joint/Snap
10. Voxel Blocks(Minecraft/Roblox)

### 8.3 필터/정렬
1. 스타일: Nendo/Moe/Minecraft/Roblox/Animal/Robot/Fantasy
2. 난이도: easy/normal/advanced
3. 작성자: official/community/me
4. 정렬: 최신/인기/다운로드수/좋아요
5. 검색: 이름/태그/full-text

### 8.4 파츠 가시성
1. `private`: 본인만 조회/사용
2. `unlisted`: URL 보유자 조회 가능, 브라우저 기본 목록 비노출
3. `public`: 브라우저 노출 + URL 조회 가능

### 8.5 파츠 게시 규칙
1. 기본 저장은 `private`
2. 게시 전 필수 메타 입력(이름, 카테고리, 썸네일)
3. `public` 전환 시 자동 검사(형상/폴리곤/금칙어) 통과 필요
4. 게시 후에도 `private`로 되돌릴 수 있음

---

## 9. 공유/리믹스 상세

### 9.1 공유 대상
1. Project Share
2. Part Share

### 9.2 공유 정책
1. 공유 타입: `public`, `unlisted`, `private`
2. 프로젝트 공유 기본값: `unlisted`
3. 파츠 공유 기본값: `private`
4. 공유 시 썸네일 자동 생성(또는 수동 선택)
5. 공유 해제 시 URL 접근 차단

### 9.3 공유 페이지 요구사항
1. URL만으로 로그인 없이 결과물 확인 가능(`public`, `unlisted`)
2. 3D 뷰어에서 회전/확대/축소 가능
3. CTA 항상 표시(`이걸 이용해서 고쳐보시겠어요?`)
4. CTA 클릭 시 로그인 유도 후 clone/import 실행
5. 작성자/작성 시각/사용 파츠 정보 표시

### 9.4 Remix/Clone 규칙
1. Project clone: 원본 프로젝트 사본 생성
2. Part remix: 원본 파츠를 내 파츠로 복제 후 편집
3. clone/remix 결과물 소유자는 수행 사용자
4. 원본 링크/원본 ID를 메타데이터로 기록
5. 원본 변경이 복제본에 자동 반영되지는 않음

### 9.5 OG(미리보기) 요구사항
1. `og:title`: 작품명 또는 파츠명 + `made with IPCHAE`
2. `og:description`: 요약 + `이걸 이용해서 고쳐보시겠어요?`
3. `og:image`: 1200x630 PNG(WebP 허용)
4. `twitter:card`: `summary_large_image`
5. project/part share slug별 동적 메타 생성

### 9.6 바이럴 측정 이벤트
1. `share_view`
2. `share_cta_click`
3. `share_clone_success`
4. `part_share_view`
5. `part_import_success`
6. `part_remix_success`

### 9.7 게이미피케이션 명세

#### 9.7.1 핵심 메커니즘
1. 행동 이벤트를 점수화해 XP를 적립한다.
2. XP 누적치로 레벨을 계산한다.
3. 업적 조건 달성 시 배지 + 보너스 XP를 지급한다.
4. 공유 자산이 타인에게 재사용될 때 제작자에게 추가 보상을 지급한다.

#### 9.7.2 XP 지급 트리거(MVP)
1. `tool_first_use`(툴별 최초 1회): +10 XP
2. `tool_usage_milestone`(툴별 10/50/100회): +15/+30/+50 XP
3. `project_share_created`: +25 XP
4. `part_share_created`: +20 XP
5. `project_clone_received`(타인이 내 공유 프로젝트를 clone): +40 XP
6. `part_import_received`(타인이 내 공유 파츠를 import): +35 XP
7. `part_remix_received`(타인이 내 공유 파츠를 remix): +45 XP
8. `export_success`: +20 XP

#### 9.7.3 레벨 규칙
1. 시작 레벨: 1
2. 레벨업 필요 XP: `nextLevelXp = floor(100 * 1.22^(level-1))`
3. 레벨업 시 초과 XP는 다음 레벨로 이월
4. 최대 레벨 제한은 MVP에서 두지 않음

#### 9.7.4 업적 정의 방식
1. 업적은 `metric_key + threshold + xp_reward` 조합으로 정의
2. 업적 유형: `tool`, `project`, `part`, `share`, `community`, `export`, `starter`
3. 희귀도: `common`, `rare`, `epic`, `legendary`
4. 기본은 1회성 업적, 일부는 반복 업적(`is_repeatable=true`) 허용

#### 9.7.5 기본 업적 예시(MVP)
1. `first_line`: Free Draw 최초 사용
2. `blob_builder_50`: Add Blob 50회
3. `smooth_master_100`: Smooth 100회
4. `first_project_share`: 프로젝트 첫 공유
5. `first_part_share`: 파츠 첫 공유
6. `community_pick_10`: 내 공유 결과물이 10회 clone/import/remix됨
7. `export_beginner`: STL/PLY 첫 export 완료

#### 9.7.6 악용 방지 규칙
1. 본인 공유물을 본인 계정이 clone/import/remix한 경우 XP 미지급
2. 동일 사용자-동일 share 조합은 24시간 내 1회만 수익 이벤트 인정
3. 익명 트래픽은 fingerprint/hash + rate limit으로 중복 억제
4. XP 지급은 `event_key` 기반 idempotency 보장

#### 9.7.7 UI 요구사항
1. Top Bar에 `Lv.{n}` + `현재 XP/다음 레벨 XP` 표시
2. 업적 해금 시 토스트 노출(희귀도 `epic` 이상은 강조 애니메이션)
3. `/account` 내 `Achievements` 탭에서 진행도/히스토리 조회
4. 아동 모드에서는 복잡한 수치보다 진행바/배지 중심으로 표시

### 9.8 실시간 협업 명세

#### 9.8.1 역할(Role)
1. `owner`: 프로젝트 소유자, 세션 생성/종료, collaborator 권한 관리, lock 강제 해제 가능
2. `editor`: 편집 가능, lock 획득/해제 가능
3. `viewer`: 읽기 전용, 편집/lock 불가

#### 9.8.2 세션 정책
1. 기본 최대 동시 editor 수: 4명
2. 세션 상태: `active`, `ended`
3. 세션 종료 시 1회 이상 checkpoint 저장
4. 세션이 없어도 프로젝트 단독 편집은 가능

#### 9.8.3 메시 점유(락) 정책
1. lock 단위: `mesh_node_id`(필요 시 submesh 확장)
2. lock 획득 시 `lease_expires_at` 발급(기본 20초)
3. lock 소유자는 heartbeat(기본 8초)로 lease 연장
4. lease 만료 시 lock 자동 해제
5. lock 1개당 점유자 1명 원칙(동시 점유 금지)
6. 오너는 `force_release`로 lock 강제 해제 가능

#### 9.8.4 동기화/충돌 정책
1. operation patch는 `base_version`, `op_seq`를 포함
2. 서버는 lock 소유 여부 + base_version 검증 후 patch 반영
3. base_version 불일치 시 `CONFLICT_STALE_BASE` 반환
4. 클라이언트는 최신 상태 pull 후 patch 재적용
5. 반복 실패 patch는 conflict queue로 이동 후 사용자 확인

#### 9.8.5 Presence 정책
1. 각 사용자 커서/카메라/선택 mesh를 실시간 송신
2. heartbeat 미수신 30초 초과 시 offline 처리
3. offline 사용자 lock은 lease 만료 시 자동 회수

#### 9.8.6 감사/추적
1. 협업 patch는 actor/user/time 기반으로 audit log 저장
2. lock 획득/해제/강제해제 이벤트를 별도 기록
3. conflict 발생 내역을 `project_collab_conflicts`에 저장

---

## 10. 레이어/색상 명세

### 10.1 레이어
1. Add Layer
2. Rename Layer
3. Toggle visibility
4. Delete Layer
5. Reorder

기본 생성 레이어:
1. Base
2. Body
3. Face
4. Hair
5. Accessory

### 10.2 색상
1. 기본 팔레트 16색
2. 피부톤/머리색 추천 팔레트 제공
3. Color Pick 툴로 활성 레이어 도포
4. PLY export 시 vertex color 포함 옵션

---

## 11. Import/Export 명세

### 11.1 Import
1. 지원 포맷: `stl`, `ply`, `obj`, `glb`
2. 최대 용량: 25MB
3. 최대 삼각형 수: 300k
4. import 시 단위/원점 정규화 옵션 제공
5. 실패 시 에러 코드(`UNSUPPORTED_FORMAT`, `TOO_LARGE`, `BROKEN_MESH`) 반환

### 11.2 Export
1. 지원 포맷: `stl`, `ply`
2. 로컬 다운로드 필수
3. 선택적으로 Storage 업로드
4. PLY는 vertex color 옵션 제공

---

## 12. Validation 규칙

### 12.1 검사 항목
1. `thin_wall`: 최소 두께 1.2mm
2. `non_manifold`: 비다양체 검사
3. `open_edges`: 오픈 경계 검사
4. `self_intersection`: 자기교차 검사
5. `joint_clearance`: 결합부 간격 최소 0.3mm(스냅핏 모드)

### 12.2 심각도
1. `warning`
2. `error`

### 12.3 Export 정책
1. error > 0: Export 버튼 비활성
2. warning만 존재: 확인 체크박스 후 진행

---

## 13. 데이터 모델

### 13.1 클라이언트 타입
```ts
export type Project = {
  id: string
  ownerId?: string
  name: string
  updatedAt: number
  thumbnailPath?: string
  starterTemplateId?: string
  sourceShareId?: string
}

export type SceneState = {
  projectId: string
  version: number
  strokes3d: Stroke3D[]
  volumes: VolumeBlob[]
  layers: Layer[]
  meshParams: MeshParams
  validation: ValidationReport
  starterInstance?: StarterInstance
  usedPartIds: string[]
}

export type StarterPack = {
  id: string
  slug: string
  name: string
  isActive: boolean
}

export type StarterTemplate = {
  id: string
  packId: string
  slug: string
  name: string
  targetStyle: 'nendo' | 'moe' | 'minecraft' | 'roblox' | 'generic'
  baseScenePath: string
  previewImagePath?: string
  defaultProportion: {
    headRatio: number
    bodyRatio: number
    legRatio: number
  }
}

export type PartPreset = {
  id: string
  ownerId?: string
  name: string
  category: string
  styleFamily: string
  visibility: 'private' | 'unlisted' | 'public'
  meshPath: string
  previewImagePath?: string
  tags: string[]
}

export type ShareLink = {
  id: string
  shareSlug: string
  targetType: 'project' | 'part'
  targetId: string
  visibility: 'public' | 'unlisted' | 'private'
  allowClone: boolean
  ogImagePath?: string
}

export type SyncMetadata = {
  status: 'local' | 'syncing' | 'synced' | 'failed'
  lastSyncedAt?: number
  remoteVersion?: number
}

export type GamificationProfile = {
  userId: string
  level: number
  totalXp: number
  currentLevelXp: number
  nextLevelXp: number
  streakDays: number
}

export type AchievementDefinition = {
  id: string
  code: string
  name: string
  category: 'tool' | 'project' | 'part' | 'share' | 'community' | 'export' | 'starter'
  metricKey: string
  thresholdValue: number
  xpReward: number
  rarity: 'common' | 'rare' | 'epic' | 'legendary'
  isRepeatable: boolean
}

export type AchievementProgress = {
  userId: string
  achievementId: string
  progressValue: number
  isUnlocked: boolean
  unlockedAt?: number
  unlockCount: number
}

export type XpEvent = {
  id: string
  userId: string
  sourceType:
    | 'tool_first_use'
    | 'tool_usage_milestone'
    | 'project_share_created'
    | 'part_share_created'
    | 'project_clone_received'
    | 'part_import_received'
    | 'part_remix_received'
    | 'achievement_unlock'
    | 'export_success'
  xpDelta: number
  sourceRef?: string
  createdAt: number
}

export type ProjectCollaborator = {
  projectId: string
  userId: string
  role: 'owner' | 'editor' | 'viewer'
  status: 'invited' | 'active' | 'revoked'
}

export type CollabSession = {
  id: string
  projectId: string
  hostUserId: string
  status: 'active' | 'ended'
  maxEditors: number
  startedAt: number
  endedAt?: number
}

export type MeshLock = {
  id: string
  projectId: string
  sessionId: string
  meshNodeId: string
  ownerUserId: string
  leaseExpiresAt: number
  isActive: boolean
}

export type PresenceState = {
  sessionId: string
  userId: string
  selectedMeshNodeId?: string
  cursorWorld?: [number, number, number]
  cameraState?: {
    position: [number, number, number]
    target: [number, number, number]
  }
  heartbeatAt: number
}

export type OperationPatch = {
  id: string
  projectId: string
  sessionId: string
  actorUserId: string
  baseVersion: number
  opSeq: number
  meshNodeId?: string
  opType: 'draw' | 'blob_add' | 'push_pull' | 'smooth' | 'carve' | 'color' | 'transform' | 'delete'
  payload: Record<string, unknown>
  createdAt: number
}
```

### 13.2 저장 규칙
1. 로컬은 IndexedDB 우선
2. 씬 전체 스냅샷은 JSON/binary blob 저장
3. 서버는 version 증가 방식
4. Starter/Part 카탈로그는 로컬 캐시 + 원격 동기화
5. 공유 메타데이터는 프로젝트/파츠 메타와 분리 저장
6. 게이미피케이션 진행도는 서버 정본 + 로컬 읽기 캐시로 운영
7. 협업 편집은 patch event log + 주기적 checkpoint를 함께 저장

---

## 14. 클라이언트 아키텍처

### 14.1 권장 폴더 구조
```text
src/
  app/
    routes/
  pages/
    HomePage.tsx
    StudioPage.tsx
    PartsPage.tsx
    SharePage.tsx
    PartSharePage.tsx
    HelpPage.tsx
  features/
    starter/
    parts/
    collab/
    gamification/
    draw/
    build/
    polish/
    import/
    export/
    share/
    validation/
    sync/
  core/
    store/
    rendering/
    persistence/
    catalog/
    realtime/
    gamification/
    supabase/
    og/
  ui/
    components/
```

### 14.2 상태관리
1. 전역 상태: Zustand 또는 Redux Toolkit
2. 렌더링 상태: Three.js scene manager 분리
3. 동기화 상태: sync queue manager 분리
4. Starter 카탈로그 상태: pack/template/part store 분리
5. Part 라이브러리 상태: categories/filter/pagination state 분리
6. Share 상태: share link/view/clone/remix state 분리
7. Gamification 상태: level/xp/progress/toast queue 분리
8. Collaboration 상태: presence/locks/ops/pending-conflicts 분리

### 14.3 동기화 큐
1. 변경 이벤트를 queue에 적재
2. 디바운스(2초) 후 배치 업로드
3. 실패 시 exponential backoff 재시도
4. 일정 횟수 실패 시 `failed` 전환
5. 카탈로그는 프로젝트 데이터와 별도 갱신
6. 협업 patch queue는 일반 sync queue와 분리 처리
7. 협업 연결 복구 시 누락 op를 version 기반으로 재수신

---

## 15. Supabase 연동 계약

### 15.1 인증
1. 이메일 OTP 또는 OAuth
2. 세션 만료 시 자동 refresh
3. 비로그인 상태에서 로컬 편집 허용

### 15.2 데이터 접근
1. 메타데이터는 Postgres CRUD
2. 씬/Export 파일은 Storage
3. Starter/Part 카탈로그 메타데이터는 Postgres
4. 공유 링크/이벤트/리믹스 매핑은 Postgres
5. Starter 프리뷰/기본 씬 파일은 `starter-assets` 버킷 public read
6. Part 공개 에셋은 `part-files`의 `public/*` 경로 read
7. 공유 OG 이미지는 `share-og`, `part-og` 버킷 public read
8. 업적/진행도/XP/레벨 데이터는 `gamification_*`, `xp_events` 테이블 사용
9. 협업 세션/락/presence/op 데이터는 `project_collab_*`, `project_mesh_locks`, `project_ops` 테이블 사용
10. 실시간 브로드캐스트는 Supabase Realtime 채널(`project:{id}:collab`) 사용
11. 민감 작업(대용량 처리, OG 생성, 파츠 publish 변환, XP 지급, lock 강제해제)은 Edge Functions

### 15.3 권한
1. 사용자 데이터 테이블 RLS 활성화
2. owner_id = auth.uid() 정책 기본
3. Storage도 사용자 경로 제한
4. Starter 공식 카탈로그는 anon/auth read 허용
5. 유저 파츠는 visibility 기반 접근 제어
6. `private` 파츠는 소유자만 read/write
7. XP/업적 쓰기 작업은 클라이언트 직접 쓰기 금지, server-side만 허용
8. 협업 권한은 role 기반(`owner/editor/viewer`)으로 검증
9. `viewer`는 presence/read만 허용, patch/lock 불가

---

## 16. API/동작 계약

### 16.1 프로젝트 생성
1. 로컬 ID 생성
2. 로그인 상태면 서버 row 생성
3. 실패 시 로컬만 유지

### 16.2 씬 저장
1. `scene_json` Storage 업로드
2. `project_versions` row insert
3. `projects.updated_at/latest_version` update

### 16.3 Import 처리
1. 파일 파싱
2. 단위/원점 정규화
3. 유효성 검사(손상 메쉬/면수)
4. 내부 씬 구조로 변환

### 16.4 Export 생성
1. STL/PLY 생성
2. 로컬 다운로드
3. 선택적으로 Storage 업로드

### 16.5 Starter/Part 카탈로그 로드
1. 앱 시작 시 로컬 캐시 확인
2. 원격 버전이 더 최신이면 Supabase에서 갱신
3. 실패 시 로컬 번들 카탈로그 사용

### 16.6 파츠 저장/게시
1. `Save Part`로 내 파츠 row 생성(visibility=`private`)
2. publish 시 `private` -> `unlisted/public` 전환
3. 공개 경로 `part-files/public/{partId}` 에셋 준비
4. part share slug 생성

### 16.7 프로젝트 Share 생성
1. 공유 범위 설정
2. `project_shares` row 생성
3. 공유 slug URL 반환

### 16.8 파츠 Share 생성
1. 공유 범위 설정
2. `part_shares` row 생성
3. 공유 slug URL 반환

### 16.9 Share 페이지 조회
1. slug로 project/part share 조회
2. visibility 확인
3. viewer asset 로드
4. OG 메타 동적 응답

### 16.10 Remix(Clone)
1. project clone: source snapshot 복제
2. part remix: source part 복제
3. 새 row 생성 + source 추적 메타 저장

### 16.11 Tool Usage 이벤트 처리
1. 툴 종료 시 `tool_used` 이벤트 전송(`toolId`, `projectId`, `countDelta`)
2. 서버에서 `tool_usage_stats` 누적
3. 툴별 첫 사용/마일스톤 조건을 평가
4. 조건 충족 시 `xp_events`와 업적 진행도 업데이트

### 16.12 Share 성과 이벤트 처리
1. `share_clone_success`, `part_import_success`, `part_remix_success` 발생 시 owner 조회
2. `viewer_id != owner_id` 조건 검증
3. `event_key` 중복 검사 후 1회만 XP 지급
4. 지급 결과를 `xp_events`에 기록

### 16.13 업적 평가/해금
1. 이벤트 발생 시 `achievement_catalog(metric_key)` 기준으로 진행도 증가
2. threshold 충족 시 `is_unlocked=true`, `unlocked_at` 기록
3. 업적 보상 XP를 추가 지급하고 레벨 재계산
4. 클라이언트는 폴링 또는 실시간 구독으로 토스트 표시

### 16.14 XP/레벨 조회
1. `GET /api/gamification/me`로 프로필/레벨/현재 XP 조회
2. `GET /api/gamification/achievements`로 업적 목록/진행도 조회
3. `GET /api/gamification/xp-events`로 최근 적립 내역 조회
4. 응답 캐시는 짧게(예: 5~15초) 유지

### 16.15 협업 세션 시작/참가
1. `POST /api/collab/session/start` input: `projectId`, `maxEditors`
2. `POST /api/collab/session/{sessionId}/join` input: `inviteCode(optional)`
3. output: `sessionId`, `role`, `realtimeChannel`, `checkpointVersion`

### 16.16 Presence heartbeat
1. `POST /api/collab/session/{sessionId}/presence`
2. input: `cursorWorld`, `cameraState`, `selectedMeshNodeId`
3. 서버는 `heartbeat_at` 갱신 후 broadcast

### 16.17 Lock 획득/갱신/해제
1. `POST /api/collab/session/{sessionId}/lock/acquire`
2. `POST /api/collab/session/{sessionId}/lock/renew`
3. `POST /api/collab/session/{sessionId}/lock/release`
4. input: `meshNodeId`, `lockScope`, `lockId`
5. 실패 코드: `LOCK_HELD_BY_OTHER`, `LOCK_NOT_FOUND`, `LOCK_EXPIRED`

### 16.18 Patch 제출
1. `POST /api/collab/session/{sessionId}/ops`
2. input: `baseVersion`, `opSeq`, `meshNodeId`, `opType`, `payload`
3. 서버 검증: role/editor + lock ownership + version
4. output: `appliedVersion` 또는 `CONFLICT_STALE_BASE`

### 16.19 Conflict 조회/해결
1. `GET /api/collab/session/{sessionId}/conflicts`
2. `POST /api/collab/session/{sessionId}/conflicts/{conflictId}/resolve`
3. resolve 방식: `pull_latest`, `reapply`, `discard`

### 16.20 Checkpoint 저장
1. `POST /api/collab/session/{sessionId}/checkpoint`
2. trigger: 30초 주기 또는 op 100건 누적
3. 결과: `project_versions` 최신 버전 갱신

---

## 17. 성능 목표
1. 기본 작업 시 30fps 이상
2. 입력 후 프리뷰 반영 300ms 내
3. Validation 1차 결과 2초 내
4. 프로젝트 로드 3초 내
5. Starter/Part 카탈로그 최초 표시 1초 내(캐시 기준)
6. 템플릿 적용 후 조작 가능 상태 0.5초 내
7. Share 페이지 최초 렌더 2초 내
8. Part Browser 검색 결과 첫 응답 400ms 내(캐시/인덱스 기준)
9. XP 적립 이벤트 처리 후 UI 반영 700ms 내(네트워크 정상 시)
10. 협업 presence 지연 250ms 내(평균)
11. lock 획득 왕복 지연 200ms 내(평균)
12. patch 브로드캐스트 반영 300ms 내(평균)

---

## 18. 접근성/안전성
1. 큰 아이콘 + 텍스트 라벨
2. 색상 외 아이콘/문구로 상태 표시
3. 키보드 단축키 제공
4. 아동 사용자 오작동 방지(위험 버튼 확인 다이얼로그)
5. 저학년 모드에서 고급 옵션 최소화
6. 커뮤니티 공개 파츠에 신고/차단 진입 제공

---

## 19. 테스트 계획

### 19.1 단위 테스트
1. 브러시 계산
2. mesh validation rules
3. sync queue retry logic
4. starter proportion 변환 계산
5. share visibility 권한 판단 함수
6. part visibility 전환 상태머신(private/unlisted/public)
7. 레벨 계산 함수(nextLevelXp, carry-over) 검증
8. 업적 threshold 판정/반복 업적 판정 검증
9. XP 중복 지급 차단(event_key idempotency) 검증
10. lock lease 만료/갱신 로직 검증
11. collaborator role 권한 분기 검증(editor/viewer)

### 19.2 통합 테스트
1. Start -> Draw -> Build -> Polish -> Export 성공
2. Starter 선택 후 즉시 편집 가능
3. Mesh import -> 편집 -> export 성공
4. 프로젝트 공유 URL 접속 -> clone 성공
5. 파츠 공유 URL 접속 -> import/remix 성공
6. private 파츠 비소유자 접근 차단
7. error 발생 시 export 차단
8. 툴 첫 사용 시 업적 해금 + XP 적립
9. 공유 결과물의 타인 사용 시 제작자 XP 적립
10. 본인 self-clone/self-import는 XP 미적립
11. 동일 mesh lock 경합 시 한 사용자만 편집 가능
12. stale base patch 제출 시 conflict 처리 정상

### 19.3 E2E
1. Starter 기반 프로젝트 생성/저장/재진입
2. 로그인 후 클라우드 업로드
3. 다른 브라우저에서 동일 프로젝트 복원
4. 카탈로그 네트워크 실패 시 로컬 fallback 동작
5. Slack/Kakao 미리보기에서 project/part OG 정상 표시
6. 업적 해금 토스트 표시 및 `/account` 진행도 반영
7. 레벨업 직후 Top Bar 배지/XP 바 반영
8. 2~4명 동시편집에서 presence/lock/patch 동기화 정상
9. 강제 해제 후 lock 재획득 및 편집 재개 정상

---

## 20. 마일스톤
1. Week 1: Studio 뼈대 + Starter 카탈로그/삽입
2. Week 2: Free Draw + Build 기본 툴 + Import
3. Week 3: Part Browser + 내 파츠 저장 + 카테고리 필터
4. Week 4: Validation + Export + 파츠 게시 흐름
5. Week 5: Supabase Auth + Sync + Share/Remix + OG
6. Week 6: Real-time Collaboration(Session/Presence/Lock/Patch)
7. Week 7: Gamification + 협업/보상 통합 QA
8. Week 8: 배포/안정화

---

## 21. Done 기준
1. 초등학생 테스트에서 60초 내 Starter 베이스 생성 성공
2. 초등학생 테스트에서 10분 내 캐릭터 베이스 완성 성공
3. 프로젝트 공유 URL로 로그인 없이 결과물 조회 가능
4. 파츠 공유 URL로 로그인 없이 결과물 조회 가능
5. 공유 페이지 CTA로 clone/import 후 편집 성공
6. private 파츠는 소유자 외 접근 불가
7. OG 미리보기(제목/설명/이미지) 검증 통과
8. Validation/Export 루프 정상 동작
9. Supabase 동기화와 RLS 정책 검증 통과
10. 업적 해금/XP 적립/레벨업이 실사용 시나리오에서 정상 동작
11. self-action 중복 적립 방지 규칙 검증 통과
12. 2~4명 동시편집에서 lock 기반 충돌 제어가 정상 동작
13. 협업 세션 종료 시 checkpoint/version 무결성 검증 통과
14. Cloudflare Pages 또는 GitHub Pages 배포 완료
