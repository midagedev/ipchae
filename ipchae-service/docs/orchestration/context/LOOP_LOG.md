# Loop Log

## Loop #001 (2026-03-01)
### Goal
1. 오케스트레이션 운영 체계 파일 생성
2. Swift CoreDomain 포팅 시작
3. Editor spike benchmark CLI 뼈대 작성

### Work
1. Playbook 문서 작성
2. Context 4종 파일 생성
3. CoreDomain(계약/검증/SyncQueue) 구현
4. EditorSpikeCLI 구현 + 벤치 출력 확보
5. GitHub Actions 워크플로(`orchestration-phase-a.yml`) 추가
6. Free-first 가격정책 문서 작성

### Verification
1. `npm run test` 통과 (15 tests)
2. `npm run check` 통과 (0 errors / 0 warnings)
3. `swift test --package-path ios-app/CoreDomain` 통과 (7 tests)
4. `swift run --package-path ios-app/CoreDomain EditorSpikeCLI --strokes 120 --points 120 --undo-ratio 0.25` 실행 성공
5. 통합 체크 스크립트 `./scripts/orchestration/run_loop_checks.sh` 통과
6. PricingPolicy 계약/테스트 추가 후 `swift test` 10 tests 통과

### Result
- done

### Next
1. Native Supabase auth/session proof scaffold (MOB-005)
2. iOS 렌더링 스택 스파이크 비교(MetalKit vs RealityKit) (MOB-006)
3. AppShell 최소 인증 화면과 CoreDomain 연결 (MOB-010)

## Loop #002 (2026-03-02)
### Goal
1. Supabase native auth scaffold 코드 반영
2. AppShell 최소 인증 UI 구성
3. 렌더링 스택 의사결정 문서 고정

### Work
1. `ios-app/AppShell` Swift package 생성 및 Supabase SDK 연동
2. `SupabaseAuthService`, `AuthViewModel`, `AuthScreen/HomeScreen/RootAppView` 구현
3. auth callback/session restore scaffold(`handleOpenURL`, `refreshAuthSnapshot`) 구현
4. AppShell 테스트 추가 (`AuthViewModelTests`, `AppEnvironmentLoaderTests`)
5. 렌더링 의사결정 문서 작성 (`RENDERING_STACK_DECISION_2026_03.md`)
6. `NATIVE_SUPABASE_AUTH_SPIKE_2026_03.md` 작성
7. 오케스트레이션 체크 스크립트/CI에 AppShell 테스트 추가

### Verification
1. `swift test --package-path ios-app/AppShell` 통과 (5 tests)
2. `swift test --package-path ios-app/CoreDomain` 통과 (10 tests)
3. `./scripts/orchestration/run_loop_checks.sh` 통과
4. Node test/check 모두 통과

### Result
- done

### Next
1. Auth deep-link callback + session restore 구현
2. MetalKit/RealityKit 코드 스파이크 측정값 확보
3. pricing 이벤트 계측 스키마를 backend 이벤트 수집 경로와 연결

## Loop #003 (2026-03-02)
### Goal
1. Auth callback/session restore를 코드에 연결
2. Pricing 이벤트를 계약/코드/SQL로 고정
3. 검증 루프 재실행

### Work
1. `SupabaseAuthService`에 `refreshAuthSnapshot`/`handleOpenURL` 구현
2. `RootAppView`에 `onOpenURL` 연결
3. CoreDomain에 `PricingTelemetry` 계약/빌더 추가
4. `docs/contracts/pricing-event-v1.md` + `docs/07_PRICING_EVENTS.sql` 작성
5. AppShell/CoreDomain 테스트 확장

### Verification
1. `swift test --package-path ios-app/AppShell` 통과 (5 tests)
2. `swift test --package-path ios-app/CoreDomain` 통과 (12 tests)
3. `./scripts/orchestration/run_loop_checks.sh` 통과
4. Node test/check 통과

### Result
- done

### Next
1. MetalKit vs RealityKit 코드 스파이크 구현 및 측정값 수집 (MOB-011)
2. 실제 iOS app target 생성 후 deep-link lifecycle 연결 (MOB-013)
3. pricing telemetry를 Supabase 수집 파이프라인으로 push하는 adapter 추가

## Loop #004 (2026-03-02)
### Goal
1. 렌더링 스파이크를 코드로 가시화
2. iOS lifecycle 연결 가능한 sample app target 준비
3. 전체 검증 루프 재통과

### Work
1. AppShell에 렌더링 실험 코드 추가 (`RendererBackend`, `RendererExperimentView`)
2. 렌더러 추천 로직 테스트 추가 (`RendererRecommendationTests`)
3. `IPCHAEAppSample` 최소 iOS 앱 스캐폴드 + `xcodegen` 스크립트 추가
4. AppShell/CoreDomain/Node 전체 테스트 재실행

### Verification
1. `swift test --package-path ios-app/AppShell` 통과 (7 tests)
2. `swift test --package-path ios-app/CoreDomain` 통과 (12 tests)
3. `./scripts/orchestration/run_loop_checks.sh` 통과

### Result
- done

### Next
1. iPad 실측 렌더링 수치(FPS/latency/memory) 수집 (MOB-015)
2. sample app 실제 xcodeproj 생성/실행 확인 및 deep link end-to-end 검증 (MOB-013)
3. pricing telemetry Supabase adapter 구현 (MOB-016)

## Loop #005 (2026-03-02)
### Goal
1. pricing telemetry를 Supabase insert 경로로 연결
2. iOS deep-link lifecycle을 시뮬레이터에서 end-to-end 검증
3. 전체 테스트/빌드 루프 재검증

### Work
1. AppShell에 `SupabasePricingTelemetrySink`/`SupabasePricingEventsStore` 추가
2. `PricingEventInsertRow` 매핑 및 user/project UUID 검증 로직 추가
3. AppShell 테스트에 `PricingTelemetrySinkTests` 추가 (3 cases)
4. `IPCHAEAppSample` Info.plist에 `ipchae` URL scheme 등록
5. `simctl launch/openurl`로 deep-link E2E 검증 실행

### Verification
1. `swift test --package-path ios-app/AppShell` 통과 (10 tests)
2. `swift test --package-path ios-app/CoreDomain` 통과 (12 tests)
3. `./scripts/orchestration/run_loop_checks.sh` 통과
4. `xcodebuild -project ios-app/IPCHAEAppSample/IPCHAEAppSample.xcodeproj -scheme IPCHAEApp -destination 'platform=iOS Simulator,name=iPhone 17' build` 성공
5. `xcrun simctl openurl <UDID> ipchae://auth-callback...` 성공

### Result
- done

### Next
1. iPad 실측 렌더링 수치(FPS/latency/memory) 수집 (MOB-015)
2. paywall/upgrade 트리거 화면에 telemetry sink 연결
3. 실측 리포트 자동 수집 스크립트 작성

## Loop #006 (2026-03-02)
### Goal
1. deep-link E2E를 재실행 가능한 스크립트로 고정
2. 렌더링 수치 수집 루프를 자동화
3. MOB-015 진행 상태를 evidence 기반으로 업데이트

### Work
1. `scripts/ios/verify_deeplink_e2e.sh` 추가
2. `scripts/ios/capture_render_spike_metrics.sh` 추가
3. 렌더링 스냅샷 파일 생성:
   - `docs/orchestration/metrics/render/editor-spike-20260302-080820.json`
   - `docs/orchestration/metrics/render/render-metrics-20260302-080820.md`
4. `IPCHAEAppSample/README.md`에 deep-link simulator 명령 추가

### Verification
1. `./scripts/ios/verify_deeplink_e2e.sh 'iPhone 17'` 통과
2. `./scripts/ios/capture_render_spike_metrics.sh` 실행 성공
3. 생성된 metrics JSON/MD 파일 확인 완료

### Result
- done

### Next
1. iPad 실기기에서 FPS/latency/memory 수치 채우기 (MOB-015 마감)
2. pricing telemetry sink를 paywall/upgrade UI 이벤트에 연결
3. deep-link E2E 스크립트를 CI nightly lane으로 편입 검토

## Loop #007 (2026-03-02)
### Goal
1. pricing telemetry를 문서/어댑터 수준이 아니라 UI 경로까지 연결
2. paywall/upgrade 이벤트가 실제 사용자 액션에서 발생하도록 구현
3. 회귀 없이 통합 테스트/검증 루프 통과

### Work
1. `PricingGateViewModel` 추가 (`attemptAction`, `tapUpgrade`, `dismissPaywall`)
2. `HomeScreen`에 Free-tier pricing gate demo 버튼 + paywall sheet 연결
3. `RootAppView`에서 authenticated userID를 HomeScreen에 전달
4. `IPCHAEAppSample`에서 `SupabasePricingTelemetrySink` 주입 경로 추가
5. `PricingGateViewModelTests` 추가 (3 cases)

### Verification
1. `swift test --package-path ios-app/AppShell` 통과 (13 tests)
2. `swift test --package-path ios-app/CoreDomain` 통과 (12 tests)
3. `./scripts/orchestration/run_loop_checks.sh` 통과
4. `./scripts/ios/verify_deeplink_e2e.sh 'iPhone 17'` 통과

### Result
- done

### Next
1. iPad 실기기 렌더 수치 입력으로 MOB-015 마감
2. pricing gate demo를 실제 Studio 액션(내보내기/공유/협업)과 연결
3. iOS Gate A 보고서 초안 작성

## Loop #008 (2026-03-02)
### Goal
1. 샌드박스 데모 화면을 실제 편집 가능한 네이티브 에디터 골격으로 교체
2. iPhone/iPad 레이아웃 분기를 적용해 캔버스 우선 UX를 구현
3. 드로잉 입력/undo/redo/autosave 복구 루프를 작동시키고 빌드 검증 통과

### Work
1. `StudioSandboxView`를 전면 재작성:
   - iPhone: 풀스크린 캔버스 + 하단 툴바 + Inspector sheet
   - iPad: 좌 Tools / 중앙 Canvas / 우 Inspector 3패널
2. `StudioEditorViewModel` 추가:
   - stroke 입력/erase/mirror draw
   - undo/redo/clear
   - slice layer 추가/삭제/축/깊이 제어
3. 검증/내보내기 경로 연결:
   - `ValidationService`와 `DraftSummary` 생성 연결
   - export payload(JSON) 프리뷰 sheet
4. local autosave/restore 추가:
   - UserDefaults snapshot 저장/복구
   - 편집 설정/캔버스 변경 디바운스 autosave
5. macOS 패키지 테스트 호환을 위한 SwiftUI toolbar/navigation/platform color 분기 추가

### Verification
1. `swift test --package-path ios-app/AppShell` 통과 (13 tests)
2. `xcodebuild -project ios-app/IPCHAEAppSample/IPCHAEAppSample.xcodeproj -scheme IPCHAEApp -destination 'platform=iOS Simulator,name=iPhone 17' build` 성공
3. `./scripts/ios/verify_deeplink_e2e.sh 'iPhone 17'` 통과

### Result
- done

### Next
1. selection/multi-select + transform command stack(v1) 구현 (NATIVE-004)
2. iPad 실기기 성능 수치(FPS/latency/memory) 채워 MOB-015 마감
3. guest-first 편집 경로 XCUITest 자동화 (NATIVE-009)

## Loop #009 (2026-03-02)
### Goal
1. NATIVE-004의 선택/명령 계층을 데모가 아닌 편집 동작 수준으로 확장
2. 캔버스 상 선택 가시화와 기본 편집 명령(복제/삭제/이동) 연결
3. autosave에 선택 상태를 포함해 재진입 연속성 확보

### Work
1. `StudioEditorViewModel`에 selection 상태/명령 추가:
   - `selectedStrokeIDs`, `multiSelectEnabled`
   - `selectLast`, `selectAll`, `clearSelection`
   - `duplicateSelected`, `deleteSelected`, `nudgeSelected`
2. Pan 모드 드래그 종료 시 nearest stroke 선택 로직 추가
3. 캔버스에 선택 stroke 하이라이트(yellow overlay) 추가
4. autosave snapshot에 `selectedStrokeIDs`, `multiSelectEnabled` 포함
5. Tools 패널에 selection control UI 추가

### Verification
1. `swift test --package-path ios-app/AppShell` 통과 (13 tests)
2. `xcodebuild -project ios-app/IPCHAEAppSample/IPCHAEAppSample.xcodeproj -scheme IPCHAEApp -destination 'platform=iOS Simulator,name=iPhone 17' build` 성공

### Result
- done (partial for NATIVE-004)

### Next
1. transform(translate/scale/rotate) 명령을 selection 대상에 연결해 NATIVE-004 마감
2. iPad 실기기 성능 수치(FPS/latency/memory) 채워 MOB-015 마감
3. guest-first 편집 경로 XCUITest 자동화 (NATIVE-009)

## Loop #010 (2026-03-02)
### Goal
1. 선택 대상에 기본 변형 명령(scale/rotate)을 연결
2. NATIVE-004를 완료 처리 가능한 수준까지 명령 계층 확장
3. 빌드/테스트 무회귀 확인

### Work
1. Tool panel에 변형 액션 버튼 추가:
   - `Scale +/-`
   - `Rotate +/-15`
2. `StudioEditorViewModel`에 변형 명령 추가:
   - `scaleSelected(by:)`
   - `rotateSelected(degrees:)`
   - selection centroid 계산기
3. 백로그 상태 갱신:
   - `NATIVE-004` done
   - `NATIVE-005` in_progress

### Verification
1. `swift test --package-path ios-app/AppShell` 통과 (13 tests)
2. `xcodebuild -project ios-app/IPCHAEAppSample/IPCHAEAppSample.xcodeproj -scheme IPCHAEApp -destination 'platform=iOS Simulator,name=iPhone 17' build` 성공

### Result
- done

### Next
1. transform command(v1) 고도화(pivot/axis snap/정밀 입력)로 NATIVE-005 마감
2. iPad 실기기 성능 수치(FPS/latency/memory) 채워 MOB-015 마감
3. guest-first 편집 경로 XCUITest 자동화 (NATIVE-009)

## Loop #011 (2026-03-02)
### Goal
1. 웹 에디터 구조와의 갭 중 PIP 영역과 카메라 조작 경로를 우선 이식
2. 메인 뷰/보조 뷰 카메라 상태를 분리하고 상호 적용 가능하게 구성
3. autosave에 카메라/PIP 상태까지 포함해 재진입 연속성 확보

### Work
1. Tool panel에 Camera 섹션 추가:
   - `Zoom +/-`, `Reset Cam`, `Use PIP View`, `Show PIP`
2. `EditorCanvasView`를 메인 카메라 렌더 + PIP 렌더 구조로 확장
3. `PIPPreviewView` 추가:
   - 드래그 오빗(`orbitPIP`)
   - PIP zoom + reset 버튼
4. `StudioEditorViewModel`에 카메라 상태/투영 로직 추가:
   - `mainCameraState`, `pipCameraState`, `showPIP`
   - `projectScenePoint`, `projectedPoints`
   - `applyViewPreset`, `zoomMain`, `panMain`, `applyPIPCameraToMain`
5. autosave snapshot에 카메라/PIP 상태 필드 추가 + 하위 호환 decode 처리

### Verification
1. `swift test --package-path ios-app/AppShell` 통과 (13 tests)
2. `xcodebuild -project ios-app/IPCHAEAppSample/IPCHAEAppSample.xcodeproj -scheme IPCHAEApp -destination 'platform=iOS Simulator,name=iPhone 17' build` 성공
3. `./scripts/orchestration/run_loop_checks.sh` 통과
4. `./scripts/ios/verify_deeplink_e2e.sh 'iPhone 17'` 통과

### Result
- done (PIP/camera baseline)

### Next
1. transform command(v1) 고도화(pivot/axis snap/정밀 입력 + group transform)로 NATIVE-005 마감
2. iPad 실기기 성능 수치(FPS/latency/memory) 채워 MOB-015 마감
3. guest-first 편집 경로 XCUITest 자동화 (NATIVE-009)

## Loop #012 (2026-03-02)
### Goal
1. 웹 편집기 명령 체계와의 갭 축소를 위해 그룹/클립보드 계열 명령 추가
2. 선택 워크플로우를 `select-group / group / ungroup / copy / cut / paste`까지 확장
3. 무회귀 빌드/테스트 확인

### Work
1. Tools > Selection 패널에 그룹/클립보드 버튼 추가
2. `StudioEditorViewModel`에 명령 추가:
   - `selectStrokeGroup`
   - `groupSelected`, `ungroupSelected`
   - `copySelected`, `cutSelected`, `pasteCopied`
3. `EditorStroke`에 `groupID` 필드 추가

### Verification
1. `swift test --package-path ios-app/AppShell` 통과 (13 tests)
2. `xcodebuild -project ios-app/IPCHAEAppSample/IPCHAEAppSample.xcodeproj -scheme IPCHAEApp -destination 'platform=iOS Simulator,name=iPhone 17' build` 성공

### Result
- done (command baseline 확장)

### Next
1. transform command(v1) 고도화(pivot/axis snap/정밀 입력 + group transform)로 NATIVE-005 마감
2. iPad 실기기 성능 수치(FPS/latency/memory) 채워 MOB-015 마감
3. guest-first 편집 경로 XCUITest 자동화 (NATIVE-009)

## Loop #013 (2026-03-02)
### Goal
1. "각 축별 드로잉 + 뷰 선택 모드" 동작을 baseline으로 완성
2. 드로잉 평면을 X/Y/Z 축으로 명시 선택 가능하게 하고 뷰 프리셋과 연동
3. autosave와 export 요약에서도 축 매핑 결과가 반영되도록 정합성 확보

### Work
1. Tools > View 섹션에 `Draw Axis` segmented picker 추가
2. `StudioEditorViewModel`에 `drawPlaneAxis` 추가 및 `applyViewPreset`에서 view->axis 연동
3. scene mapping 재구성:
   - `effectiveDrawAxis` 기반으로 stroke point를 X/Y/Z 평면으로 투영
   - `makeSummary` dot 생성도 같은 축 매핑 로직 사용
4. autosave snapshot에 `drawPlaneAxis` 필드 추가 + decode default 처리

### Verification
1. `swift test --package-path ios-app/AppShell` 통과 (13 tests)
2. `xcodebuild -project ios-app/IPCHAEAppSample/IPCHAEAppSample.xcodeproj -scheme IPCHAEApp -destination 'platform=iOS Simulator,name=iPhone 17' build` 성공

### Result
- done (axis/view drawing baseline)

### Next
1. transform command(v1) 고도화(pivot/axis snap/정밀 입력 + group transform)로 NATIVE-005 마감
2. iPad 실기기 성능 수치(FPS/latency/memory) 채워 MOB-015 마감
3. guest-first 편집 경로 XCUITest 자동화 (NATIVE-009)

## Loop #014 (2026-03-02)
### Goal
1. 변형 명령에서 pivot/snap 설정을 실제 동작으로 연결
2. iPhone에서도 축/뷰/입력모드를 inspector 진입 없이 빠르게 전환 가능하게 개선
3. autosave에 transform 설정을 포함해 재진입 연속성 확보

### Work
1. `StudioSandboxView` compact toolbar 확장:
   - `Mode: Draw/Select` 토글
   - `View` quick menu
   - `Axis` quick menu
2. Selection > Transform 섹션 추가:
   - `Pivot (Object/Selection/World)`
   - `Grid Snap` + step 조절
   - `Angle Snap` + degrees 조절
3. `StudioEditorViewModel` transform 고도화:
   - `transformPivotMode`, `gridSnapEnabled/gridSnapStep`, `angleSnapEnabled/angleSnapDegrees`
   - `nudgeSelected`, `scaleSelected`, `rotateSelected`에 pivot/snap 적용
4. autosave snapshot 스키마 확장:
   - pivot/snap 필드 저장/복원 + 하위 호환 default decode 처리

### Verification
1. `swift test --package-path ios-app/AppShell` 통과 (13 tests)
2. `xcodebuild -project ios-app/IPCHAEAppSample/IPCHAEAppSample.xcodeproj -scheme IPCHAEApp -destination 'platform=iOS Simulator,name=iPhone 17' build` 성공

### Result
- done (transform pivot/snap baseline + iPhone quick controls)

### Next
1. group transform 정합성(그룹 단위 pivot 동작/선택 정책) 마감으로 NATIVE-005 완료
2. iPad 실기기 성능 수치(FPS/latency/memory) 채워 MOB-015 마감
3. guest-first 편집 경로 XCUITest 자동화 (NATIVE-009)

## Loop #015 (2026-03-02)
### Goal
1. grouped stroke 선택 상태에서 transform 동작 정합성 확보
2. `Pivot: Object` 모드에서 그룹을 하나의 오브젝트처럼 처리
3. NATIVE-005 완료 기준 충족

### Work
1. transform 대상 확장 로직 추가:
   - 선택된 stroke가 group에 속하면 동일 `groupID` 전체를 `effectiveTransformStrokeIDs`로 포함
2. centroid 계산 로직 확장:
   - `centroid(forStrokeIDs:)`
   - `groupCentroids(forStrokeIDs:)`
3. transform pivot 로직 보강:
   - `Object` 모드에서 grouped stroke는 group centroid를 pivot으로 사용
4. 변형 명령(nudge/scale/rotate) 연결 업데이트:
   - 선택 ID 대신 group-aware target ID 집합 기준으로 변형

### Verification
1. `swift test --package-path ios-app/AppShell` 통과 (13 tests)
2. `xcodebuild -project ios-app/IPCHAEAppSample/IPCHAEAppSample.xcodeproj -scheme IPCHAEApp -destination 'platform=iOS Simulator,name=iPhone 17' build` 성공

### Result
- done (group transform consistency)

### Next
1. iPad 실기기 성능 수치(FPS/latency/memory) 채워 MOB-015 마감
2. guest-first 편집 경로 XCUITest 자동화 (NATIVE-009)
3. 홈→스튜디오 첫 진입 UX 단순화(게스트 즉시 진입 옵션) 검토

## Loop #016 (2026-03-02)
### Goal
1. 미가입 사용자 첫 세션에서 핵심 편집 기능 진입 마찰 최소화
2. 홈 화면에서 스튜디오 진입 발견성 개선
3. 회귀 없는 빌드/테스트 확인

### Work
1. `HomeScreen` 게스트 CTA 문구를 `지금 바로 스튜디오 시작`으로 조정
2. 게스트 첫 실행 시 Studio 자동 오픈(1회) 로직 추가:
   - `@AppStorage("ipchae.guest.did-autostart-studio.v1")`
   - `onAppear`에서 미실행 시 `showStudioSandbox = true`
3. 기존 guest-first 구조(`fullScreenCover` 기반 Studio 진입)는 유지

### Verification
1. `swift test --package-path ios-app/AppShell` 통과 (13 tests)
2. `xcodebuild -project ios-app/IPCHAEAppSample/IPCHAEAppSample.xcodeproj -scheme IPCHAEApp -destination 'platform=iOS Simulator,name=iPhone 17' build` 성공

### Result
- done (guest first-session auto-start baseline)

### Next
1. iPad 실기기 성능 수치(FPS/latency/memory) 채워 MOB-015 마감
2. guest-first 편집 경로 XCUITest 자동화 (NATIVE-009)
3. pricing gate demo 액션을 실제 Studio 액션 경로로 점진 치환

## Loop #017 (2026-03-02)
### Goal
1. Slice 레이어 lock/visibility를 실제 편집 입력 제어로 연결
2. PIP 미니뷰를 이동 가능한 형태로 개선하고 위치 복원을 지원
3. guest-first 편집 UI 테스트를 PIP 이동까지 포함해 고정

### Work
1. `StudioSandboxView` Slice 패널 확장:
   - 활성 레이어 `Visible/Hidden`, `Lock/Unlock` 토글 추가
   - 레이어 리스트에 show/hide, lock/unlock 액션 추가
2. `StudioEditorViewModel` Slice 정합성 보강:
   - `canDrawOnActiveSlice`, `shouldShowSliceGuide` 계산 속성 추가
   - Slice hidden/locked 상태에서 draw/erase 입력 차단
   - `selectSliceLayer`, `updateActiveSliceAxis`에서 Slice->View preset 동기화
3. PIP 이동 UX 추가:
   - PIP 상단 `Move` 핸들 drag로 위치 이동
   - 캔버스 경계 clamp
   - `pipOffset` autosave 저장/복원
4. XCUITest 보강:
   - guest auto-open + draw + Done/reopen 경로에 `Move` 핸들 drag 검증 추가

### Verification
1. `swift test --package-path ios-app/AppShell` 통과 (13 tests)
2. `xcodebuild -project ios-app/IPCHAEAppSample/IPCHAEAppSample.xcodeproj -scheme IPCHAEApp -destination 'platform=iOS Simulator,name=iPhone 17' test` 통과 (1 UI test)
3. `./scripts/orchestration/run_loop_checks.sh` 통과

### Result
- done (slice-layer interaction + draggable PIP + UI test 강화)

### Next
1. iPad 실기기 성능 수치(FPS/latency/memory) 채워 MOB-015 마감
2. pricing gate demo 액션을 실제 Studio 액션 경로로 점진 치환
3. Slice 레이어별 stroke 소유/필터링 모델 도입 여부 설계 확정
