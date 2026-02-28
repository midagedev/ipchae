# 입채 (IPCHAE) Sharing and Remix Spec

## 1. 목표
1. 프로젝트와 파츠를 각각 URL로 공유 가능하게 한다.
2. 공유 페이지에서 즉시 Remix/Import를 유도한다.
3. OG 미리보기 품질로 바이럴 전파를 강화한다.
4. 공유 성과를 업적/XP/레벨 시스템과 연결한다.
5. 공유 프로젝트에서 실시간 동시편집 세션으로 전환 가능하게 한다.

---

## 2. 핵심 사용자 행동
1. 제작자가 프로젝트를 공유한다.
2. 제작자가 파츠를 공유한다.
3. 시청자가 URL로 결과물을 본다.
4. 시청자가 `이걸 이용해서 고쳐보시겠어요?`를 누른다.
5. 로그인 후 내 프로젝트/내 파츠로 클론하여 수정한다.
6. 시청자가 `같이 편집하기`로 협업 세션에 참여한다.

---

## 3. URL/라우팅
1. 프로젝트 공유 URL: `/share/{shareSlug}`
2. 파츠 공유 URL: `/part/{partShareSlug}`
3. 편집 URL: `/studio/{projectId}`
4. 파츠 브라우저: `/parts`
5. 협업 초대 URL: `/collab/{inviteCode}`

---

## 4. 공유 정책

### 4.1 Visibility
1. `public`: 누구나 접근 가능, 브라우저 노출 가능
2. `unlisted`: URL 아는 사람만 접근, 브라우저 비노출
3. `private`: 작성자만 접근

기본값:
1. 프로젝트: `unlisted`
2. 파츠: `private`

### 4.2 전환 규칙
1. 파츠는 `private -> unlisted/public` 전환 가능
2. 게시 이후 `public/unlisted -> private` 롤백 가능
3. `public` 전환 시 필수 메타(이름, 카테고리, 썸네일) 필요

### 4.3 협업 편집 규칙
1. 협업은 프로젝트 share에서만 허용한다(파츠 share 제외).
2. 협업 참여는 로그인 사용자만 가능하다.
3. 세션 역할은 `editor`/`viewer`로 구분한다.
4. 편집은 `mesh lock` 획득 사용자만 가능하다.
5. 세션 최대 editor 수는 기본 4명으로 제한한다.

---

## 5. 프로젝트 공유 페이지
1. 작품명, 작성자, 썸네일, 생성/업데이트 시각
2. Read-only 3D 뷰어(회전/확대/축소)
3. Primary CTA: `이걸 이용해서 고쳐보시겠어요?`
4. Secondary CTA: `입채로 새로 만들기`
5. Tertiary CTA: `같이 편집하기`

CTA 동작:
1. 비로그인: 로그인 모달 -> 성공 시 clone
2. 로그인: 즉시 clone
3. clone 성공: 새 프로젝트 편집기로 이동
4. `같이 편집하기` 클릭 시 협업 세션 참여/생성 모달 표시
5. 세션 참여 성공 시 `/studio/{projectId}?session={sessionId}` 이동

---

## 6. 파츠 공유 페이지
1. 파츠명, 작성자, 카테고리, 스타일, 사용 예시 썸네일
2. Read-only 3D 뷰어(파츠 단독 미리보기)
3. Primary CTA: `이걸 이용해서 고쳐보시겠어요?`
4. Secondary CTA: `내 파츠로 저장`

CTA 동작:
1. 비로그인: 로그인 모달 -> 성공 시 import/remix
2. 로그인: 즉시 import/remix
3. 성공 시 Parts Browser의 `My Parts` 또는 현재 프로젝트로 적용

---

## 7. OG 메타 사양

### 7.1 필수 메타
1. `og:title`
2. `og:description`
3. `og:image`
4. `og:type=website`
5. `twitter:card=summary_large_image`

### 7.2 값 생성 규칙
1. 프로젝트 제목: `{projectShare.title} | made with IPCHAE`
2. 파츠 제목: `{partShare.title} | made with IPCHAE`
3. 설명: `{description 또는 기본문구}` + `이걸 이용해서 고쳐보시겠어요?`
4. 이미지 우선순위:
5. 프로젝트: `share-og` -> 프로젝트 썸네일
6. 파츠: `part-og` -> 파츠 프리뷰 썸네일

### 7.3 렌더링 방식
1. `GET /share/:slug`, `GET /part/:slug`는 동적 HTML 반환
2. HTML head에 slug별 OG 메타 삽입
3. body에서 SPA 앱 로드

---

## 8. 데이터 모델

### 8.1 프로젝트 공유
1. `project_shares`
2. `project_remixes`
3. `share_events`

### 8.2 파츠 공유
1. `parts`
2. `part_shares`
3. `part_remixes`
4. `part_events`

### 8.3 게이미피케이션 연계
1. `gamification_profiles`
2. `achievement_catalog`
3. `user_achievement_progress`
4. `xp_events`
5. `gamification_event_dedup`

### 8.4 협업 연계
1. `project_collaborators`
2. `project_collab_invites`
3. `project_collab_sessions`
4. `project_presence`
5. `project_mesh_locks`
6. `project_ops`
7. `project_collab_conflicts`

---

## 9. 권한 규칙
1. 프로젝트 share owner만 share 수정/삭제 가능
2. 파츠 share owner만 share 수정/삭제 가능
3. `public/unlisted` share는 anon read 가능
4. clone은 `allow_clone=true`일 때만 가능
5. 파츠 import/remix는 `allow_import/allow_remix=true`일 때만 가능
6. `private` 파츠는 소유자만 조회/사용 가능
7. 협업 role이 `viewer`인 사용자는 lock/patch 요청 불가
8. 협업 role이 `editor`인 사용자만 lock/patch 요청 가능
9. 프로젝트 owner는 collaborator 권한 변경/강제 퇴장 가능

---

## 10. API 계약

### 10.1 프로젝트 Share 생성
1. `POST /api/share`
2. input: `projectId`, `title`, `description`, `visibility`, `allowClone`
3. output: `shareSlug`, `shareUrl`

### 10.2 프로젝트 Share 조회
1. `GET /api/share/{slug}`
2. output: share 메타 + viewer scene 경로 + 작성자 요약

### 10.3 프로젝트 Clone
1. `POST /api/share/{slug}/clone`
2. output: `newProjectId`

### 10.4 파츠 Share 생성
1. `POST /api/part/share`
2. input: `partId`, `title`, `description`, `visibility`, `allowImport`, `allowRemix`
3. output: `partShareSlug`, `partShareUrl`

### 10.5 파츠 Share 조회
1. `GET /api/part/share/{slug}`
2. output: part share 메타 + part mesh 경로 + 작성자 요약

### 10.6 파츠 Import/Remix
1. `POST /api/part/share/{slug}/import`
2. `POST /api/part/share/{slug}/remix`
3. output: `partId` 또는 `newProjectId`

### 10.7 이벤트 기록
1. `POST /api/share/{slug}/event`
2. `POST /api/part/share/{slug}/event`
3. input: `eventType`, `referrer`

### 10.8 공유 성과 XP 지급
1. `POST /api/gamification/share-conversion`
2. input: `eventType`, `shareSlug`, `viewerId(optional)`, `eventKey`
3. 동작:
4. share owner 조회
5. self-action 여부 검증(`viewerId != ownerId`)
6. `eventKey` 중복 검사
7. 조건 통과 시 XP 적립 + 업적 진행도 업데이트

### 10.9 협업 초대 생성
1. `POST /api/share/{slug}/collab-invite`
2. input: `role`, `expiresInMinutes`, `maxEditors(optional)`
3. output: `inviteCode`, `inviteUrl`, `sessionId(optional)`

### 10.10 협업 세션 참여
1. `POST /api/collab/join`
2. input: `inviteCode`
3. output: `sessionId`, `projectId`, `role`, `realtimeChannel`

### 10.11 lock/presence/ops
1. `POST /api/collab/session/{sessionId}/presence`
2. `POST /api/collab/session/{sessionId}/lock/acquire`
3. `POST /api/collab/session/{sessionId}/lock/release`
4. `POST /api/collab/session/{sessionId}/ops`
5. 실패 코드: `LOCK_HELD_BY_OTHER`, `CONFLICT_STALE_BASE`, `ROLE_FORBIDDEN`

---

## 11. 분석 지표

### 11.1 프로젝트 지표
1. share view 수
2. CTA 클릭률(CTR)
3. clone 전환율
4. clone 후 24시간 내 재공유율
5. clone 기반 제작자 XP 획득량
6. 협업 세션 참여 전환율(`같이 편집하기` CTR)

### 11.2 파츠 지표
1. part share view 수
2. import 전환율
3. remix 전환율
4. private -> public 전환율
5. import/remix 기반 제작자 XP 획득량

### 11.3 협업 지표
1. 동시 접속 editor 평균 수
2. lock 경합률
3. conflict 발생률
4. 세션당 평균 편집 시간

초기 목표:
1. 프로젝트 CTA CTR 15% 이상
2. 프로젝트 clone 전환율 6% 이상
3. 파츠 import 전환율 10% 이상
4. 공유 기반 XP 이벤트 중복률 1% 미만
5. 협업 세션 참여 전환율 8% 이상
6. lock 충돌률 5% 미만

---

## 12. 테스트 시나리오
1. `public` 프로젝트 URL 익명 접근 성공
2. `public` 파츠 URL 익명 접근 성공
3. `private` 파츠 비소유자 접근 차단
4. 프로젝트 CTA -> 로그인 -> clone -> 편집기 이동 성공
5. 파츠 CTA -> 로그인 -> import/remix 성공
6. `allow_clone=false`에서 clone 차단
7. `allow_import=false`에서 import 차단
8. Slack/Discord/Kakao 링크 미리보기 OG 노출 확인
9. 타인이 clone/import/remix 시 owner XP 적립 성공
10. self-action에서 XP 미적립
11. 동일 `eventKey` 재전송 시 중복 지급 차단
12. 협업 invite URL로 editor 참여 성공
13. 동일 mesh lock 경합 시 단일 사용자만 획득
14. viewer role의 patch 요청 차단
15. stale base patch에 `CONFLICT_STALE_BASE` 반환

---

## 13. 수용 기준(DoD)
1. 프로젝트/파츠 공유 URL 생성/조회/해제 동작
2. 공유 페이지 CTA 문구 및 clone/import 플로우 동작
3. project/part slug별 OG 메타 정확히 반영
4. clone/remix 결과에 source 추적 메타 저장
5. 핵심 이벤트 지표 대시보드 집계 가능
6. 공유 성과 기반 업적/XP/레벨 업데이트 동작
7. 공유 프로젝트 협업 세션 생성/참여/동시편집 동작
