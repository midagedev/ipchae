# IPCHAE Native Editor Full-Scope Orchestration Master Plan

기준일: 2026-03-02  
대상 레포: `/Users/hckim/repo/ipchae/ipchae-service`  
비교 기준 레포: `/Users/hckim/repo/ipchae/app`

## 1. 문서 목적
이 문서는 단순 포팅이 아니라, iPhone/iPad 네이티브 앱에서 에디터 핵심 기능을 실사용 가능한 수준으로 재구축하기 위한 단일 실행 계획이다.

포함 범위:
1. `~/repo/ipchae`(레퍼런스 웹) 대비 현재 iOS 구현 갭 분석
2. Spectrum 기반 웹 UX를 네이티브 UX로 재설계하는 원칙
3. 장기 병렬 오케스트레이션(트랙/루프/게이트) 계획
4. Free-first 성장 + 부분 유료화 정책의 제품 반영 원칙

### 1.1 최신 구현 스냅샷 (2026-03-02 업데이트)
`/Users/hckim/repo/ipchae/ipchae-service/ios-app/AppShell/Sources/AppShell/UI/StudioSandboxView.swift` 기준으로 아래 항목이 반영되었다.

1. 캔버스 풀영역 편집 + PIP 카메라 프리뷰(이동/줌/리셋)
2. 뷰별 스트로크 적층(빈 공간 드로잉 + 기존 스트로크 위 적층)
3. 제스처 입력
   1. 두 손가락 탭 Undo
   2. 세 손가락 탭 Redo
   3. 길게 누르기 Quick Eyedropper(지연 시간 설정)
4. 선 보정(Stabilizer)
   1. 실시간 보정 모드
   2. 사후 보정 모드
   3. 보정 강도(0~1) 조절
5. Stylus 기반 Palm Rejection
   1. Pencil 전용 그리기 토글 제공
   2. 활성 시 드로잉 입력을 Apple Pencil 터치 타입으로 제한
6. 위 입력/보정 설정의 autosave 복구 연동

## 2. 기준 비교 요약

### 2.1 비교 대상 파일
1. 레퍼런스 웹(`~/repo/ipchae/app`)
   1. `/Users/hckim/repo/ipchae/app/src/routes/studio/[projectId]/+page.svelte`
   2. `/Users/hckim/repo/ipchae/app/src/lib/stage/FixedDraftStage.svelte`
2. 현재 서비스 웹(`ipchae-service/src`)
   1. `/Users/hckim/repo/ipchae/ipchae-service/src/routes/studio/[projectId]/+page.svelte`
   2. `/Users/hckim/repo/ipchae/ipchae-service/src/lib/core/contracts/editor-stage.ts`
3. 현재 iOS(`ipchae-service/ios-app`)
   1. `/Users/hckim/repo/ipchae/ipchae-service/ios-app/AppShell/Sources/AppShell/UI/RootAppView.swift`
   2. `/Users/hckim/repo/ipchae/ipchae-service/ios-app/AppShell/Sources/AppShell/UI/HomeScreen.swift`
   3. `/Users/hckim/repo/ipchae/ipchae-service/ios-app/AppShell/Sources/AppShell/UI/StudioSandboxView.swift`

### 2.2 기능 갭 매트릭스 (2026-03-02 최신)
| 영역 | `~/repo/ipchae/app` | `ipchae-service/web` | `ipchae-service/ios` | 판단 |
|---|---|---|---|---|
| 스튜디오 풀스크린 편집 레이아웃 | 있음(상단 앱바 + 좌/우/하단 패널) | 있음(고도화 버전) | 있음(캔버스 풀영역 + 상/하 오버레이) | iOS v1 완료, iPad 3패널은 남음 |
| 드로잉 기본 도구(그리기/채우기/지우기) | 있음 | 있음 | 있음 | 완료 |
| 뷰/입력 제어(Front/Right/Top, Draw/Pan, Zoom) | 있음 | 있음 | 있음(PIP 포함) | 완료 |
| 슬라이스 레이어 편집 | 있음 | 있음(고도화) | 있음(v1) | 고도화 필요 |
| 고급 편집(선택/그룹/변형/컷) | 없음 또는 부분 | 계약/구현 모두 존재 | 부분(선택/그룹/스케일/회전/2D 이동) | 컷/리셋/3D 이동 남음 |
| 스냅샷 저장/로드 + 오토세이브 | 없음 또는 약함 | 있음 | 있음(UserDefaults autosave) | 완료(로컬 기준) |
| import/export(STL/PLY) | 제한적 UI | 있음 | 부분(JSON 미리보기만) | STL/PLY 남음 |
| Parts/Share/Collab/Gamification/i18n | 없음 | 있음 | 부분(한글화/아이콘화 일부) | 대부분 남음 |
| 인증/세션 | 별도 | 있음 | 있음(게스트 퍼스트 + Supabase 스캐폴드) | 유지/연결 작업 필요 |
| 과금 계측/게이트 데모 | 없음 | 있음(정책/이벤트) | 있음(데모 + sink) | 실제 정책 연동 남음 |

### 2.3 에디터 핸들 API 정량 비교
1. `editor-stage.ts`의 `EditorStageHandle` 메서드 수: 29개
2. `~/repo/ipchae/app` 구현 흔적: 기본 6개 중심 (`updateMainView`, `setInputMode`, `zoomMain`, `resetMainView`, `undoLastStroke`, `clearAllStrokes`)
3. 현재 iOS 코드에서 대응 상태 (2026-03-02):
   1. 구현: 20개
   2. 부분 구현: 2개 (`nudgeSelectedStroke`의 `deltaN`, `translateSelectedStroke`의 3D 축 이동)
   3. 미구현: 7개 (`insertPrimitiveMesh`, `getSelectedStrokeId(s)` API 노출, `resetSelectedStrokeTransform`, `planeCutSelectedStroke`, `sliceCutSelectedStroke`)

의미:
1. iOS는 샌드박스 단계를 넘어 핵심 편집 루프는 동작하는 단계다.
2. 다음 작업의 중심은 "컷/메시/입출력/협업" 같은 미구현 기능의 제품화다.

## 3. 제품 방향 결정 (Native First)
1. 1차 목표는 iPhone/iPad 네이티브 완성도 확보다.
2. Android는 iOS Gate D 이후 동일 스펙으로 후행한다.
3. Spectrum은 iOS에서 컴포넌트 직접 재사용이 아니라 디자인 토큰/정보구조를 이식한다.

## 4. 네이티브 UX 재설계 원칙
1. 로그인 강제 금지: 비가입 상태에서 핵심 제작 루프를 바로 실행 가능해야 한다.
2. 캔버스 우선: 모든 기기에서 “첫 화면은 편집”이 기본이다.
3. 학습 최소화: 첫 세션에서 Draw -> Validate -> Export(기본)까지 완료 가능해야 한다.
4. 패널은 맥락형: 고정 패널 남용 대신, 현재 도구/선택 상태에 맞춰 정보만 노출한다.

### 4.1 iPhone 레이아웃
1. 기본: 풀스크린 캔버스
2. 하단: 드로잉 툴바(아이콘 + 1줄 텍스트)
3. 보조 패널: Bottom Sheet(도구/브러시/슬라이스/선택 inspector 탭)
4. 상단: 최소 액션(Undo/Redo/Export/계정)

### 4.2 iPad 레이아웃
1. 기본: 3영역
   1. 좌측: Tool Rail + Project/Layer mini list
   2. 중앙: Canvas
   3. 우측: Inspector(브러시/선택/변형/슬라이스)
2. 구조: `NavigationSplitView` + `inspector` 중심
3. 포인터/키보드 단축키/Pencil 입력 우선 최적화

## 5. 기술 스택 결정
1. UI: SwiftUI 중심, 복잡 제스처/렌더 루프는 UIKit 브릿지 허용
2. 렌더링: MetalKit 우선(RealityKit은 보조)
3. 입력: Apple Pencil + 손가락 제스처를 분리 처리
4. 도메인: `CoreDomain` Swift Package 단일 원천
5. 데이터: Local-first(로컬 스냅샷/큐) + Supabase 동기화
6. 디자인 시스템: Spectrum 토큰 매핑(컬러/간격/타이포 스케일), 컴포넌트는 네이티브 재구성

## 6. 목표 기능 범위 (포팅이 아닌 완성)
아래 항목을 모두 지원하는 것을 목표로 한다.

1. 편집 코어
   1. draw/fill/erase
   2. undo/redo
   3. selection(single/multi), group/ungroup
   4. translate/rotate/scale/reset transform
   5. plane cut / slice cut
2. 씬/프로젝트
   1. autosave + snapshot load
   2. crash/relaunch 복구
3. 입출력
   1. mesh import
   2. STL/PLY export
4. 제품 기능
   1. parts 저장/재사용
   2. share link
   3. collab lock/session
   4. i18n(ko/en/ja)
5. 비즈니스/성장
   1. guest-first onboarding
   2. free-first pricing gate
   3. KPI 이벤트 계측

## 7. 장기 오케스트레이션 모델

### 7.1 병렬 트랙
| Track | 목표 | 핵심 산출물 |
|---|---|---|
| W0 Program | 운영/결정/우선순위 통제 | ADR, 상태 문서, 게이트 판정 |
| W1 Editor Kernel | 렌더/입력/브러시 파이프라인 | 캔버스 엔진, 프레임/지연 지표 |
| W2 Editing Commands | 선택/변형/히스토리 명령 모델 | Command stack, undo/redo 일관성 |
| W3 Persistence/Sync | 로컬 저장 + 서버 동기화 | autosave, sync queue, 충돌 처리 |
| W4 Shell UX | 네이티브 스튜디오 레이아웃 | iPhone/iPad UI, inspector, 접근성 |
| W5 IO/Parts/Share | import/export + 파츠/공유 | 파일 IO, 링크/파츠 흐름 |
| W6 Collab | 협업 세션/락 제어 | lock/heartbeat, 재접속 정책 |
| W7 Pricing/Growth | 무료 성장 + 유료 전환 | policy 적용, paywall UX, KPI |
| W8 QA/Perf | 품질 게이트 자동화 | CI, 성능 리포트, 회귀 테스트 |
| W9 Android Readiness | 후속 이식 준비 | 플랫폼 중립 경계/문서 |

### 7.2 루프 프로토콜 (멈춤 없는 실행 기준)
루프 단위(1일 또는 1작업 묶음)로 아래 순서를 반복한다.

1. Context Load: `PROGRAM_STATE`, `BACKLOG`, `DECISIONS`, `LOOP_LOG` 로드
2. Work Select: `ready` 상위 1~3개 선택(트랙당 동시 1개)
3. Contract First: 인터페이스 변경 시 계약/ADR 선반영
4. Build: 코드 + 테스트 + 스크립트 + 문서 동시 갱신
5. Verify: Node/Swift/시뮬레이터 스모크/성능 수집 실행
6. Record: `LOOP_LOG`와 `PROGRAM_STATE` 업데이트
7. Reorder: 다음 루프 우선순위 재정렬

실행 규칙:
1. 병렬 가능한 트랙은 동시 실행하되, 공통 계약 파일은 W0 승인 후 병합
2. 테스트 실패 상태로 루프 종료 금지
3. 데모 전용 우회 코드는 TODO 태그와 제거 조건을 반드시 기록

## 8. 단계별 계획과 게이트

### Phase A (주 1-2): 에디터 골격 전환
1. iPhone/iPad 스튜디오 레이아웃 뼈대 완성
2. 실제 드로잉 입력 + undo/redo + 카메라 조작 구현
3. 기존 Mock Editor Controls 제거

Gate A:
1. 미가입 사용자 첫 실행 후 3분 내 기본 드로잉 완료율 90%+
2. iPad 기준 기본 시나리오 55fps+
3. 앱 재실행 후 로컬 복구 성공

### Phase B (주 3-6): 편집 핵심 기능
1. 선택/멀티선택/그룹/변형 도구
2. 슬라이스 레이어 조작 + 컷 연산
3. autosave/snapshot/reopen 일관성 보장

Gate B:
1. Draw -> Select -> Transform -> Save -> Reopen 경로 통과
2. undo/redo 회귀 테스트 통과

### Phase C (주 7-10): 제품 기능 통합
1. import/export(STL/PLY)
2. parts/share/collab 기본 플로우
3. i18n/접근성/에러 처리 고도화

Gate C:
1. share/part/collab 핵심 경로 E2E 통과
2. 성능 회귀 없음(기준 시나리오)

### Phase D (주 11-14): 릴리즈 하드닝
1. 크래시/메모리/열 안정화
2. 온보딩/튜토리얼/가격정책 UX 확정
3. TestFlight RC 배포 준비

Gate D:
1. crash-free/성능/접근성 기준 충족
2. 출시 체크리스트 완료

## 9. Free-first 가격 정책 반영 원칙
1. 무료에서 절대 막지 않는 것
   1. 핵심 편집 루프(그리기/수정/저장/기본 내보내기)
   2. 초반 프로젝트 경험(가입 없이)
2. 유료화 후보(사용자 친화 우선)
   1. 고급 export 포맷/품질 옵션
   2. 협업 좌석/동시 세션 한도 확장
   3. 고급 공유 옵션(권한/만료/브랜딩)
3. 금지 원칙
   1. 첫 세션 즉시 paywall 노출 금지
   2. 학습 단계의 핵심 도구 차단 금지

## 10. 즉시 실행 백로그 (다음 10 작업)
| ID | Track | 작업 | 우선순위 | 상태 |
|---|---|---|---|---|
| NATIVE-001 | W4 | iPhone 캔버스 우선 편집 화면 전환(샌드박스 교체) | P0 | done |
| NATIVE-002 | W4 | iPad 3패널 레이아웃(`NavigationSplitView` + inspector) | P0 | in_progress |
| NATIVE-003 | W1 | 실제 Stroke 입력 파이프라인(Pencil/Touch) | P0 | done |
| NATIVE-004 | W2 | Command stack(v1): undo/redo/select | P0 | done |
| NATIVE-005 | W2 | 변형 명령(translate/rotate/scale) 인터페이스 | P1 | in_progress |
| NATIVE-006 | W3 | autosave + reopen 복구 경로 구현 | P0 | done |
| NATIVE-007 | W5 | STL/PLY export mock 제거, 실제 exporter 연결 | P1 | ready |
| NATIVE-008 | W5 | import 진입점 + 오류 상태 UX | P1 | ready |
| NATIVE-009 | W8 | 편집 루프 스모크 UI 테스트 자동화 | P1 | ready |
| NATIVE-010 | W7 | 게스트 세션 KPI 이벤트(완료율/이탈률) 고정 | P1 | in_progress |

## 11. 완료 정의 (Definition of Done)
아래가 모두 충족되면 “데모”가 아니라 “실사용 가능”으로 본다.

1. 미가입 사용자도 핵심 제작 루프를 완주할 수 있다.
2. `EditorStageHandle` 29개 기능군 중 제품 MVP 범위가 iOS에서 동작한다.
3. 저장/복구/내보내기/공유 경로가 실제 데이터로 검증된다.
4. iPhone/iPad 모두에서 레이아웃/입력/성능 기준을 만족한다.
5. Free-first 정책이 사용자 성장 저해 없이 적용된다.

## 13. 남은 작업 우선순위 (현재 기준)
1. P0
   1. iPad 전용 3패널 레이아웃 완성 (`NavigationSplitView` 기반)
   2. 컷 기능 2종 구현 (`planeCutSelectedStroke`, `sliceCutSelectedStroke`)
   3. 선택 스트로크 변형 리셋 + 3D 축 이동(translate/nudge `deltaN`) 지원
2. P1
   1. STL/PLY 내보내기 실구현 + 검증
   2. mesh import 진입/에러 UX
   3. 제스처/보정 회귀 테스트(UI + 입력 시나리오) 자동화
3. P2
   1. Parts/Share/Collab 기능 이식
   2. i18n 언어팩 정리(ko/en/ja)
   3. 가격 정책 실연동(현재 데모 게이트 -> 실제 정책)

## 12. 참고 링크 (스택/디자인 결정 근거)
1. Flutter iOS Platform Views: [https://docs.flutter.dev/platform-integration/ios/platform-views](https://docs.flutter.dev/platform-integration/ios/platform-views)
2. Flutter Fragment Shaders: [https://docs.flutter.dev/ui/design/graphics/fragment-shaders](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)
3. React Spectrum: [https://github.com/adobe/react-spectrum](https://github.com/adobe/react-spectrum)
4. Spectrum Web Components: [https://opensource.adobe.com/spectrum-web-components/](https://opensource.adobe.com/spectrum-web-components/)
5. Spectrum Design Tokens: [https://github.com/adobe/spectrum-design-data](https://github.com/adobe/spectrum-design-data)
6. Apple SwiftUI Inspector: [https://developer.apple.com/videos/play/wwdc2023/10161/](https://developer.apple.com/videos/play/wwdc2023/10161/)
7. Apple NavigationSplitView: [https://developer.apple.com/documentation/swiftui/navigationsplitviewvisibility/detailonly](https://developer.apple.com/documentation/swiftui/navigationsplitviewvisibility/detailonly)
8. RealityKit: [https://developer.apple.com/augmented-reality/realitykit/](https://developer.apple.com/augmented-reality/realitykit/)
9. PencilKit: [https://developer.apple.com/documentation/pencilkit/pkinkingtool-swift.struct](https://developer.apple.com/documentation/pencilkit/pkinkingtool-swift.struct)
