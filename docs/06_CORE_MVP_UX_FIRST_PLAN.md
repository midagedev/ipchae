# 입채 Core MVP (UX First) 실행안

문서 기준일: 2026-02-28

## 1. 목표 재정의
이번 MVP의 최우선은 "누구나 3D 모델링을 쉽게 시작하고, 끝까지 완주"하게 만드는 것이다.

핵심 성공 조건:
1. 첫 진입 사용자가 60초 안에 캐릭터 베이스를 만든다.
2. 첫 진입 사용자가 10분 안에 간단 캐릭터를 완성해 export까지 간다.
3. 툴 학습 없이도 Draw -> Build -> Polish 루프를 1회 이상 완주한다.

## 2. 이번에 만들 범위 (Core MVP)
아래가 동작하면 이번 단계는 성공으로 본다.

1. 시작 경험
1. 홈에서 `Blank` / `Free Draw First` / `Starter` 선택
2. Starter는 최소 데이터셋으로 시작(팩 2+, 템플릿 8+, 공식 파츠 40+)

2. 편집기 최소 구조
1. 단일 3D Stage
2. Stepper(`Start`, `Draw`, `Build`, `Polish`, `Export`)
3. 기본 툴 패널 + 브러시 크기/강도 조절

3. 조형 핵심 툴
1. `Free Draw`
2. `Add Blob`
3. `Push/Pull`
4. `Smooth`
5. `Mirror(x)` 토글
6. `Undo/Redo`(최소 50 step)

4. 완주 기능
1. Validation 최소 세트(`non_manifold`, `open_edges`, `self_intersection`)
2. `STL/PLY` 로컬 export
3. 로컬 자동저장(2초 디바운스) + 재진입 복원

## 3. 이번에 제외 (Later)
Core UX 검증 전에는 아래를 구현하지 않는다.

1. Share/Remix URL, OG
2. Part 게시(public/unlisted/private 전환)
3. Supabase Auth/Sync
4. 실시간 협업(session/presence/lock/patch)
5. 업적/XP/레벨
6. 고급 필터/분석 지표 대시보드

## 4. 수용 기준 (Acceptance)
1. 초등 사용자 테스트에서 5명 중 4명 이상이 60초 내 Starter 베이스 생성
2. 5명 중 4명 이상이 도움 없이 10분 내 export 버튼까지 도달
3. 주요 툴 전환/입력 반영이 체감 지연 없이 동작(입력 후 300ms 내 반영 목표)
4. 새로고침 후 직전 프로젝트가 자동 복구

## 5. 구현 순서 (Sprint 0~1)
1. Day 1: 앱 부트스트랩 + 라우트(`/`, `/studio/:projectId`) + Studio 레이아웃 뼈대
2. Day 2: 3D Stage + 카메라 컨트롤 + Starter 삽입 + Stepper 연결
3. Day 3: Free Draw / Add Blob / Push-Pull / Smooth + Undo/Redo
4. Day 4: Validation 최소 세트 + STL/PLY export + Local-first 저장/복원
5. Day 5: 아동 사용자 시나리오 테스트 + UX 마찰 제거(툴 노출/문구/기본값 조정)

## 6. 즉시 착수 TODO
1. React + TypeScript + Vite 프로젝트 생성
2. Studio 핵심 레이아웃 컴포넌트 생성(TopBar/ToolDock/MainStage/Inspector/Stepper)
3. Three.js Stage 초기화와 툴 이벤트 파이프라인 연결
4. Starter 최소 카탈로그 JSON 번들(로컬) 추가

