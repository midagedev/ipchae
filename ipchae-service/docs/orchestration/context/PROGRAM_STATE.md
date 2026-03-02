# Program State

Updated: 2026-03-02 (Loop #017)

## Mission
Apple-native-first(iPhone/iPad)로 IPCHAE Studio를 재구축하고, Android는 iOS Gate D 완료 후 후행한다.

## Current Phase
- Phase A (Weeks 1-2): Foundations and Risk Spikes

## Active Tracks
1. W0 Program Control: in_progress
2. W1 Editor Kernel Spike: in_progress (실험 코드 + 자동 수집 스크립트 완료, 실기기 수치 대기 / 드로잉 입력 파이프라인 v1 반영)
3. W2 Domain Port (Swift CoreDomain): done (Loop #001-003) / Editing Commands: done (transform v1 + group transform 정합성 완료)
4. W3 Data/Supabase Native Proof: in_progress (deep-link lifecycle + pricing telemetry adapter 완료, local autosave 복구 경로 연결)
5. W4 App Shell: in_progress (인증 + pricing gate demo + iPhone/iPad 네이티브 편집 레이아웃 + PIP 카메라 + 축 드로잉 + iPhone quick control + guest auto-start + slice lock/visibility + PIP 이동 복원 반영)
6. W5 QA/Perf: in_progress (기본 CI/통합 체크 + 렌더링 스냅샷 자동 수집 완료)
7. W6 Android Readiness: pending
8. W7 Product Growth/Pricing: in_progress (Free-first v1 + telemetry adapter 완료)

## This Week Goals
1. CoreDomain Swift package 생성 및 계약 포팅
2. Editor spike benchmark CLI 추가
3. 루프 기반 컨텍스트 문서 체계 정착
4. 기본 CI에서 Node + Swift 테스트 동시 실행
5. Free-first 가격정책 초안과 KPI 계측 규칙 확정
6. AppShell 인증 스캐폴드 + Supabase 연동 시작
7. pricing telemetry 계약과 저장 스키마 초안 확정

## Risks
1. iOS 렌더링 스택 확정 전 편집기 커널 난이도 불확실
2. Supabase native auth/session edge case 미검증
3. 웹 1:1 스펙 대비 정밀 camera rig/고급 히스토리/실기기 성능 튜닝이 아직 미완료

## Recovery (중단 후 재개 순서)
1. `docs/orchestration/context/BACKLOG.md`에서 `ready` 항목 상단 1~2개 선택
2. `docs/orchestration/context/DECISIONS.md`의 최신 ADR 확인
3. `docs/orchestration/context/LOOP_LOG.md` 마지막 loop의 `Next` 실행
4. 구현 후 테스트 실행 및 LOOP_LOG append

## Next 3 Actions
1. iPad 실측 렌더링 수치 수집 (MOB-015)
2. pricing gate demo 액션을 실제 Studio 액션 경로로 점진 치환
3. Slice/Layer 동작을 실제 레이어별 stroke 소유 모델로 확장할지 설계 확정
