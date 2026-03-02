# Decisions (ADR-lite)

## ADR-001 Apple Native First
- Date: 2026-03-01
- Status: accepted
- Context: 제품 핵심이 실시간 3D 편집기이며 Flutter 단독 3D 커널 리스크가 높음.
- Decision: iOS/iPadOS 네이티브 우선 개발 후 Android 후행.
- Consequence: 초기 속도는 느릴 수 있으나 편집기 품질 리스크를 조기에 줄임.

## ADR-002 Context as Files
- Date: 2026-03-01
- Status: accepted
- Context: 장기 작업에서 채팅 컨텍스트만으로는 상태 유실이 잦음.
- Decision: 상태/결정/백로그/루프로그를 레포 파일로 유지.
- Consequence: 재개 시간 단축, 온보딩 비용 감소.

## ADR-003 Contract-First Merge Rule
- Date: 2026-03-01
- Status: accepted
- Context: 병렬 트랙에서 계약 불일치로 충돌 가능성 큼.
- Decision: 모델/스키마 변경은 기능 구현보다 먼저 반영.
- Consequence: 초기 오버헤드 증가, 통합 리스크 감소.

## ADR-004 Rewrite > Port
- Date: 2026-03-01
- Status: accepted
- Context: 목표가 단순 이식이 아니라 다수가 잘 쓰는 서비스 완성임.
- Decision: 기존 웹 동작을 맹목적으로 포팅하지 않고, UX/기능/아키텍처 재설계를 허용한다.
- Consequence: 범위 관리 난이도는 증가하지만 사용자 가치 중심 최적화 가능.

## ADR-005 Free-first Pricing
- Date: 2026-03-01
- Status: accepted
- Context: 사용자 성장 우선, 초기 진입장벽 최소화가 핵심 전략.
- Decision: 무료 코어(제작 루프)는 넓게 제공하고, 유료는 파워 기능/협업/대용량에서 과금한다.
- Consequence: 단기 ARPU보다 장기 MAU/리텐션 중심 운영이 필요.

## ADR-006 Editor Renderer: MetalKit First
- Date: 2026-03-01
- Status: accepted
- Context: 핵심 제품은 실시간 편집기이며 프레임/메모리/입력 지연에 대한 저수준 제어가 필요함.
- Decision: 편집기 주 렌더러는 MetalKit(MTKView) 기반으로 설계하고 RealityKit은 보조/프리뷰 경로로 제한한다.
- Consequence: 초기 개발 난이도는 증가하지만 편집기 성능 제어권을 확보할 수 있다.

## ADR-007 Native Auth Baseline = Supabase Swift SDK
- Date: 2026-03-02
- Status: accepted
- Context: Apple-native-first 앱에서 웹과 동일한 auth backend를 유지해야 하며 구현 리드타임을 줄여야 함.
- Decision: native auth baseline은 Supabase 공식 Swift SDK를 사용하고, AppShell에서 service protocol로 감싼다.
- Consequence: 구현 속도는 빨라지며, 테스트는 protocol/mock 기반으로 유지한다.

## ADR-008 Pricing Telemetry Write Path
- Date: 2026-03-02
- Status: accepted
- Context: Free-first 실험을 위해 paywall/upgrade 이벤트를 앱에서 즉시 적재할 경로가 필요함.
- Decision: AppShell에 `SupabasePricingTelemetrySink`를 두고, CoreDomain `PricingTelemetryEvent`를 `pricing_events` 테이블 row로 직접 매핑한다.
- Consequence: 실험 속도는 빨라지며, user UUID 유효성 검증 실패 시 이벤트 적재는 명시적으로 실패 처리된다.

## ADR-009 Deep-Link E2E Gate
- Date: 2026-03-02
- Status: accepted
- Context: callback 처리 코드는 존재했지만 앱 lifecycle 수준의 실제 openURL 경로 검증이 필요했음.
- Decision: 샘플 앱 Info.plist에 `ipchae` URL scheme를 등록하고, `simctl openurl` 기반 E2E 검증을 Gate 체크에 포함한다.
- Consequence: CI/수동 루프에서 deep-link 회귀를 빠르게 감지할 수 있다.

## ADR-010 Pricing Gate First Integration
- Date: 2026-03-02
- Status: accepted
- Context: telemetry adapter만으로는 제품 경로에서 이벤트가 발생하지 않아 실험 신뢰도가 낮음.
- Decision: AppShell HomeScreen에 pricing gate demo UI를 넣고 `PricingGateViewModel`로 paywall/upgrade 이벤트를 sink에 연결한다.
- Consequence: 실험 데이터의 end-to-end 경로가 확보되지만, 추후 실제 Studio 액션 경로로 재배선이 필요하다.

## ADR-011 Guest-First Canvas Layout Baseline
- Date: 2026-03-02
- Status: accepted
- Context: 기존 iOS 샌드박스 화면은 실사용 편집 흐름을 제공하지 못했고, 사용자 테스트에서 "어디를 눌러야 되는지" 혼란이 발생함.
- Decision: Studio 진입 시 iPhone은 풀스크린 캔버스+하단 툴바, iPad는 좌/중앙/우 3패널 레이아웃을 기본으로 채택하고, 로그인 없이 즉시 편집 가능하도록 guest-first 흐름을 유지한다.
- Consequence: 첫 세션 UX가 단순해지고 테스트 가능성이 높아지지만, 고급 편집(selection/group/transform) 패널의 후속 구현이 필수 선행 조건이 된다.

## ADR-012 Selection-First Command Baseline
- Date: 2026-03-02
- Status: accepted
- Context: 고급 편집 기능을 한 번에 완성하기보다, 실제 사용자 테스트 가능한 최소 명령 집합부터 안정화할 필요가 있음.
- Decision: command stack v1의 1차 범위를 `select/all/clear + duplicate/delete + nudge`로 고정하고, transform/그룹 명령은 2차 루프로 분리한다.
- Consequence: 사용성 검증은 빨라지지만, 최종 스펙(`group/transform/cut`) 완료 전까지는 고급 편집 KPI를 제한적으로 해석해야 한다.

## ADR-013 Transform v1 Uses Selection Centroid
- Date: 2026-03-02
- Status: accepted
- Context: transform 기능을 빠르게 실사용 수준으로 올리기 위해 pivot 체계를 단순화할 필요가 있음.
- Decision: scale/rotate 기본 동작의 pivot은 selection centroid를 사용하고, object/world pivot 및 snap 옵션은 NATIVE-005 후속 범위로 분리한다.
- Consequence: 초기 동작 일관성은 확보되지만, 정밀 CAD 편집 요구에 맞춘 고급 pivot/snap UX는 추가 구현이 필요하다.

## ADR-014 Camera Baseline with PIP
- Date: 2026-03-02
- Status: accepted
- Context: 웹 에디터의 다중 시점 사용성(PIP/보조 뷰) 없이 iOS 편집 UX를 1:1에 가깝게 맞추기 어려움.
- Decision: AppShell 편집기 baseline에 메인 카메라와 PIP 카메라를 분리 도입하고, PIP 드래그 오빗/줌과 `Use PIP View` 동작을 기본 제공한다.
- Consequence: 사용자 관찰/시점 전환 UX는 즉시 개선되지만, CAD급 정확도를 위한 camera rig(orbit target, snap, inertia)는 후속 고도화가 필요하다.

## ADR-015 Command Baseline Includes Group/Clipboard
- Date: 2026-03-02
- Status: accepted
- Context: 1:1 스펙 접근을 위해 selection 기반 명령이 변형 이전에도 실사용 가능한 수준이어야 함.
- Decision: command baseline에 `group/ungroup/select-group/copy/cut/paste`를 포함하고, 데이터 모델은 stroke 단위 `groupID`를 사용한다.
- Consequence: 명령 커버리지는 확대되지만, 다중 그룹 트리/히스토리 정합성/정밀 충돌 처리 등은 후속 단계에서 강화해야 한다.

## ADR-016 Axis-Plane Drawing Baseline
- Date: 2026-03-02
- Status: accepted
- Context: 사용자 피드백에서 "축별 드로잉과 뷰 선택 모드"가 핵심 검증 항목으로 확인됨.
- Decision: 편집기 baseline에 `Draw Axis (X/Y/Z)`를 도입하고, view preset 선택 시 대응 축을 자동 반영하며, summary/export 좌표 생성도 동일 축 매핑을 사용한다.
- Consequence: 사용자가 축 기반 작업을 즉시 테스트할 수 있지만, 정밀 CAD 수준의 plane snapping/constraint solver는 후속 구현이 필요하다.

## ADR-017 Transform Pivot/Snap Baseline
- Date: 2026-03-02
- Status: accepted
- Context: 웹 에디터 대비 transform 조작 정밀도가 낮아 보이고, iPhone에서는 관련 제어를 찾기 어려운 UX 문제가 보고됨.
- Decision: transform baseline에 `Pivot(Object/Selection/World)`와 `Grid Snap/Angle Snap`을 도입하고, iPhone compact toolbar에 view/axis/input quick control을 추가한다.
- Consequence: 축/뷰/변형 테스트의 접근성이 개선되지만, 그룹 단위 transform 정책(선택/pivot 일관성)은 후속으로 마무리해야 한다.

## ADR-018 Group-Consistent Transform Policy
- Date: 2026-03-02
- Status: accepted
- Context: grouped stroke 일부만 선택한 상태에서 transform 시 그룹이 깨지는 동작이 발생해 편집 정합성이 떨어짐.
- Decision: transform 명령은 group-aware target 집합을 사용한다. 선택된 stroke가 group에 속하면 동일 `groupID` 전부를 함께 변형하며, `Pivot:Object`에서는 group centroid를 pivot으로 사용한다.
- Consequence: 그룹 유지 편집은 일관되지만, 그룹 내부 일부만 정밀 수정하려면 `Ungroup` 또는 별도 edit mode가 필요하다.

## ADR-019 Guest First-Session Auto-Start
- Date: 2026-03-02
- Status: accepted
- Context: 사용자 테스트에서 홈 화면 진입 후 "어디를 눌러야 바로 써볼 수 있는지" 혼란이 반복 보고됨.
- Decision: 게스트 세션 첫 실행 시 홈 화면에서 Studio를 자동 오픈(1회)하고, CTA는 즉시 실행 의도가 분명한 문구(`지금 바로 스튜디오 시작`)로 고정한다.
- Consequence: 첫 세션 완주율은 개선되지만, 홈에서 다른 경로(가격정책 데모 등) 탐색은 첫 진입 시점에는 후순위가 된다.

## ADR-020 Slice Interaction Gating + Draggable PIP
- Date: 2026-03-02
- Status: accepted
- Context: Slice 레이어의 visible/locked 상태가 UI에만 존재하면 실제 편집 동작과 불일치가 발생하고, PIP는 고정 위치일 때 작은 화면에서 가림/조작성 이슈가 발생함.
- Decision: Slice 레이어 상태를 입력 제어에 연결한다(locked/hidden일 때 draw/erase 차단, hidden이면 guide 미표시). 동시에 PIP는 이동 가능한 `Move` 핸들을 제공하고, 위치를 autosave로 복원한다.
- Consequence: 편집 동작의 의미 일관성과 실사용 조작성은 개선되지만, 향후 레이어별 stroke 소유 모델을 도입하지 않으면 visibility가 완전한 레이어 필터링으로 해석되지는 않는다.
