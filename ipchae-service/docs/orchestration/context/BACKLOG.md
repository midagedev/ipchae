# Backlog

## Priority Queue
| ID | Track | Title | Status | Priority | Notes |
|---|---|---|---|---|---|
| MOB-001 | W2 | Swift CoreDomain 계약 모델 포팅 | done | P0 | StudioSnapshot/Validation/SyncQueue |
| MOB-002 | W1 | Editor Spike CLI 벤치 하니스 | done | P0 | draw/undo 처리량 측정 |
| MOB-003 | W0 | 장기 오케스트레이션 운영 문서 고정 | done | P0 | playbook + context set |
| MOB-004 | W5 | Node+Swift 기본 CI 워크플로 추가 | done | P1 | macOS runner |
| MOB-005 | W3 | Native Supabase auth proof scaffold | done | P1 | AppShell package + SupabaseAuthService |
| MOB-006 | W1 | iOS 렌더링 스택 스파이크(선택지 비교) | done | P1 | 의사결정 문서 + 실험 뷰 baseline 완료 |
| MOB-007 | W6 | Android readiness 인터페이스 체크리스트 | pending | P2 | iOS Gate D 이후 |
| MOB-008 | W7 | Free/Plus/Team 가격정책 스펙 v1 | done | P0 | 사용자 성장 가드레일 포함 |
| MOB-009 | W7 | 과금 실험 KPI 이벤트 계약 정의 | done | P1 | PricingPolicy event/decision code 추가 |
| MOB-010 | W4 | AppShell 최소 인증 화면 구축 | done | P0 | AuthScreen/HomeScreen/RootAppView |
| MOB-011 | W1 | MetalKit vs RealityKit 스파이크 구현/측정 | in_progress | P0 | 실험 뷰 구현 완료, 실제 측정값 수집 대기 |
| MOB-012 | W3 | Auth callback/session restore 구현 | done | P0 | handleOpenURL + refresh snapshot scaffold |
| MOB-013 | W3 | iOS app lifecycle에 deep link 연결 | done | P0 | URL scheme 등록 + simctl openurl E2E 통과 |
| MOB-014 | W7 | Pricing telemetry 계약 + SQL 스키마 | done | P1 | CoreDomain telemetry + docs/07_PRICING_EVENTS.sql |
| MOB-015 | W1/W5 | iPad 실측 렌더링 벤치 수집 | in_progress | P0 | 자동 수집 스크립트 + 1차 JSON snapshot 생성, 실기기 수치 대기 |
| MOB-016 | W3/W7 | Pricing telemetry Supabase adapter 구현 | done | P1 | Supabase sink + paywall/upgrade UI 경로 연결 완료 |
| NATIVE-001 | W4 | iPhone 캔버스 우선 편집 화면 전환(샌드박스 교체) | done | P0 | `StudioSandboxView`를 실편집 캔버스 중심 UI로 교체 |
| NATIVE-002 | W4 | iPad 3패널 레이아웃(`NavigationSplitView` 대응 구조) | done | P0 | 좌 Tools / 중앙 Canvas / 우 Inspector 고정 패널 구성 |
| NATIVE-003 | W1 | 실제 Stroke 입력 파이프라인(Pencil/Touch 기반) | done | P0 | Drag gesture 기반 stroke 생성/erase + mirror draw 지원 |
| NATIVE-004 | W2 | Command stack(v1): undo/redo/select | done | P0 | undo/redo + select/all/clear + duplicate/delete + group/copy/cut/paste baseline 연결 완료 |
| NATIVE-005 | W2 | 변형 명령(translate/rotate/scale) 인터페이스 | done | P1 | nudge/scale/rotate + pivot mode + grid/angle snap + grouped-stroke transform 정합성 완료 |
| NATIVE-006 | W3 | autosave + reopen 복구 경로 구현 | done | P0 | UserDefaults snapshot autosave/restore 연결 |
| NATIVE-009 | W8 | 편집 루프 스모크 UI 테스트 자동화 | done | P1 | guest auto-open + draw + PIP move + 재진입 경로 XCUITest 고정 |
| NATIVE-011 | W1/W4 | PIP 미니뷰 + 카메라 오빗/줌/팬 | done | P0 | 메인/보조 카메라 상태 + PIP drag orbit + zoom + apply-to-main 구현 |
| NATIVE-012 | W1/W4 | 축 기반 드로잉(X/Y/Z) + 뷰 모드 연동 | done | P0 | Draw Axis picker + View preset 연동 + 축별 scene mapping 반영 |
| NATIVE-013 | W4 | 게스트 첫 세션 즉시 편집 진입 UX | done | P0 | HomeScreen 게스트 첫 실행 시 Studio 자동 오픈(1회) + CTA 문구 정렬 |
| NATIVE-014 | W4 | Slice layer lock/visibility + PIP 위치 이동 UX | done | P1 | lock/hidden 드로잉 차단 + Slice->View 동기화 + PIP drag 위치 autosave 복원 |

## Status Definition
1. pending: 착수 전
2. ready: 바로 수행 가능
3. in_progress: 현재 루프에서 수행 중
4. blocked: 외부 의존성으로 정지
5. done: 완료
