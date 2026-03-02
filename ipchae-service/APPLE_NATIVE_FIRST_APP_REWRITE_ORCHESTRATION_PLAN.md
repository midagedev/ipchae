# IPCHAE Apple-Native-First Mobile Rewrite Orchestration Plan

Baseline date: 2026-03-01  
Repository: `/Users/hckim/repo/ipchae/ipchae-service`

## 1. Decision Lock
1. Build iPhone and iPad app first with Apple-native stack.
2. Do not start full Android implementation until iOS/iPadOS editor quality is proven.
3. Keep backend contracts stable so Android can follow with lower risk.
4. Treat this as a product rewrite, not a mechanical port: redesign and spec updates are allowed when they improve usability and growth.
5. Pricing policy is Free-first: core creation loop must remain broadly usable at zero cost.

## 2. Why This Path
1. Current editor is tightly coupled to web runtime and WebGL stack.
2. Product core is real-time 3D editing, not just model viewing.
3. Editor performance and input fidelity are easier to de-risk on one platform first.
4. Early optimization on Apple GPUs reduces uncertainty before cross-platform expansion.

## 3. Scope and Non-Goals
## 3.1 In Scope
1. New native iOS/iPadOS app with full Studio-first workflow.
2. Supabase backend reuse (auth, share, parts, collab, events).
3. Migration of domain contracts and core logic into platform-neutral model layer, with controlled spec evolution where needed.
4. Production release candidate for iOS/iPadOS.
5. Free-first monetization design and rollout experiments (without blocking early growth).

## 3.2 Out of Scope (for this plan window)
1. Full Android app implementation.
2. Desktop native app.
3. New backend schema overhaul unless blocked by editor behavior.
4. Ad-driven monetization in the initial launch window.

## 4. Architecture Target (Apple First, Android Ready)
1. `AppShell` (SwiftUI): navigation, account, parts, share, settings.
2. `Editor3D` (MetalKit + custom scene pipeline; RealityKit/SceneKit only where pragmatic).
3. `CoreDomain` (Swift package): snapshot contract, validation rules, sync queue policy, share/collab rules.
4. `DataLayer`:
   1. Local: SQLite/SwiftData (replace IndexedDB assumptions).
   2. Remote: Supabase client + repository layer.
5. `Interop Contracts`: keep JSON payload shape compatible with current docs and tables.

## 5. Reuse Plan from Current Repo
Direct reuse candidates (logic-first, UI-agnostic):
1. `src/lib/core/contracts/studio.ts`
2. `src/lib/core/contracts/editor-stage.ts`
3. `src/lib/core/sync/sync-queue.ts`
4. `src/lib/core/validation/validation-service.ts`
5. `src/lib/core/share/share-service.ts` (business rules, not browser glue)
6. `src/lib/core/collab/collab-service.ts` (session and lock policy, not storage adapters)

Rewrite candidates (platform-bound):
1. `src/lib/stage/FixedDraftStage.svelte`
2. `src/routes/studio/[projectId]/+page.svelte`
3. Browser-bound IO (`document`, `navigator`, `localStorage`, `idb-keyval` paths)

## 6. Parallel Agent Orchestration Model
## 6.1 Workstreams
| Track | Goal | Main Outputs | Depends On |
|---|---|---|---|
| W0 Program Control | contracts, milestones, merge rules | plan updates, decision records, weekly gates | none |
| W1 Editor Kernel | 3D draw/build/polish runtime | Metal scene graph, brush pipeline, undo/redo | W0 |
| W2 Domain Port | move core rules to Swift package | snapshot models, validation, sync queue | W0 |
| W3 Data + Supabase | auth/sync/share/collab integration | repositories, mappers, retry policies | W2 |
| W4 App Shell | non-editor app surfaces | home, parts, account, share/collab screens | W2, W3 |
| W5 QA + Perf | reliability and frame/input targets | test matrix, perf dashboards, release gates | W1, W3, W4 |
| W6 Android Readiness | future-proof boundary design | portability checklist, API contract freeze | W1, W2, W3 |
| W7 Product Growth + Pricing | free-first pricing and conversion design | package limits, trial logic, KPI experiments | W4, W5 |

## 6.2 Execution Rules
1. One track per branch: `codex/w{n}-{topic}`.
2. Contract-first merges: model/schema changes land before feature UI.
3. Daily integration window: merge only after smoke + contract tests pass.
4. No shared-file edits outside ownership window unless coordinated in W0.
5. Every merged PR updates risk log and gate status.

## 7. Phase Plan (Long-Running)
## Phase A (Weeks 1-2): Foundations and Risk Spikes
1. Freeze v1 domain contracts for snapshot/sync/share/collab.
2. Build two editor spikes:
   1. Spike A: high-frequency draw stroke pipeline.
   2. Spike B: selection + transform + undo/redo transaction path.
3. Confirm Supabase session/auth flow in native app.

Gate A:
1. 30+ FPS on baseline iPad for representative draw scenario.
2. Input-to-render latency target met in spike test.
3. Contract mapping from current TS models to Swift models validated.

## Phase B (Weeks 3-6): Core Editor MVP
1. Implement Draw/Fill/Erase, mirror, selection, transform, grouping.
2. Implement snapshot save/load + local autosave.
3. Implement validation and export baseline.
4. Implement minimal Studio shell around editor.

Gate B:
1. End-to-end loop works: start project -> edit -> save -> reopen -> export.
2. Undo/redo consistency passes regression suite.

## Phase C (Weeks 7-10): Product Features Around Editor
1. Parts browser, save part, visibility controls.
2. Share clone/import flows.
3. Collab session basics: join, heartbeat, lock acquire/release.
4. Account and gamification baseline view.
5. Free-first pricing instrumentation (upgrade triggers, trial hooks, KPI events).

Gate C:
1. Share and part flows function against Supabase with RLS.
2. Collab lock conflict path is deterministic and test-covered.

## Phase D (Weeks 11-14): Hardening and Release Candidate
1. Reliability and offline recovery hardening.
2. Perf tuning for memory, frame pacing, thermal stability.
3. Accessibility and iPad layout polish.
4. TestFlight release candidate.

Gate D:
1. Crash-free and performance targets hit on test device matrix.
2. Release checklist complete for iOS/iPadOS launch.

## 8. Definition of Done (iOS/iPadOS)
1. New user can complete Draw -> Build -> Polish -> Export loop.
2. Local-first persistence is stable; cloud sync works when authenticated.
3. Share/part/collab critical paths are production-usable.
4. Core regression suite is green (domain, integration, perf smoke).
5. Architecture boundaries are documented for Android follow-up.
6. Pricing package rules are user-friendly, measurable, and do not degrade first-session completion.

## 9. Risk Register and Mitigations
1. Risk: 3D kernel complexity exceeds estimate.
   Mitigation: keep weekly spike benchmarks and cut scope early where needed.
2. Risk: contract drift between old web and new native.
   Mitigation: single source of truth for models and serialization tests.
3. Risk: Supabase real-time/collab edge cases.
   Mitigation: deterministic lock/heartbeat tests with forced timeout scenarios.
4. Risk: memory pressure on lower-end devices.
   Mitigation: fixed scene budget and telemetry alarms in perf suite.

## 10. Android Follow-Up Strategy (After iOS Gate D)
1. Reuse `CoreDomain` rules and API contracts.
2. Keep editor protocol and data layer interfaces platform-neutral.
3. Start Android with the same phased model:
   1. editor kernel spike first,
   2. then shell and data integration.

## 11. Immediate Next 10 Working Days
1. Create `ios-app` workspace and CI lane.
2. Extract and freeze shared contracts from current TS core.
3. Implement editor spike benchmark harness.
4. Implement native Supabase auth/session proof.
5. Publish first Gate A status report with measured numbers.
6. Draft Free/Plus/Team package spec and event instrumentation contract.

## 12. Tracking Template
Use this section as rolling log updates.

| Date | Track | Update | Gate Impact | Owner |
|---|---|---|---|---|
| 2026-03-01 | W0 | Plan created and decision locked to Apple first | Enables Phase A kickoff | TBD |
| 2026-03-02 | W2/W5 | CoreDomain Swift package + tests + CI loop checks landed | Gate A contract/quality baseline established | Codex |
| 2026-03-02 | W3/W4 | AppShell auth scaffold + minimal SwiftUI auth/home screens landed | Gate A native auth path started | Codex |
| 2026-03-02 | W1 | Rendering stack decision fixed to MetalKit-first with documented rationale | Reduces architecture ambiguity before spike code | Codex |
| 2026-03-02 | W3/W7 | Auth callback/session scaffold + pricing telemetry contracts landed | Gate A auth and growth instrumentation baseline established | Codex |
| 2026-03-02 | W3 | Sample iOS app deep-link E2E validated via `simctl openurl` | Gate A lifecycle risk reduced | Codex |
| 2026-03-02 | W3/W7 | Supabase pricing telemetry adapter + tests landed in AppShell | Enables Gate C pricing funnel instrumentation path | Codex |
| 2026-03-02 | W1/W5 | Render metric capture scripts + first snapshot artifacts generated | Gate A perf evidence loop became repeatable | Codex |
| 2026-03-02 | W4/W7 | Pricing gate demo UI wired to telemetry sink (paywall/upgrade events) | Converts pricing instrumentation from contract to user-flow path | Codex |
| 2026-03-02 | W1/W3/W4 | StudioSandbox를 실제 편집 가능한 캔버스 중심 레이아웃으로 교체(iPhone/iPad 분기 + 드로잉/undo/redo/autosave) | Gate B 선행조건(핵심 편집 루프) 착수 완료 | Codex |
| 2026-03-02 | W2/W4 | selection command baseline(select/all/duplicate/delete/nudge) + canvas highlight 반영 | NATIVE-004를 부분 완료 상태로 전진 | Codex |
| 2026-03-02 | W2/W4 | selection 대상 scale/rotate 변형 명령 연결 + centroid pivot baseline 도입 | NATIVE-004 완료, NATIVE-005 고도화 단계로 전환 | Codex |
| 2026-03-02 | W1/W4 | PIP 미니뷰 + 카메라 상태 분리(main/pip) + 오빗/줌/메인 적용 동작 반영 | 웹 에디터 시점 워크플로우와의 갭 축소 | Codex |
| 2026-03-02 | W2/W4 | 그룹/클립보드 명령(group/ungroup/select-group/copy/cut/paste) baseline 반영 | command parity 갭 추가 축소 | Codex |
| 2026-03-02 | W1/W4 | 축 기반 드로잉(X/Y/Z) + 뷰 preset 연동 + export 좌표 축 매핑 통일 | "축 드로잉/뷰 모드" 요구사항 baseline 충족 | Codex |
| 2026-03-02 | W2/W4 | Transform pivot(Object/Selection/World) + grid/angle snap 도입, iPhone view/axis/input quick control 추가 | 변형 정밀도/발견성 개선으로 NATIVE-005 마감 범위 축소 | Codex |
| 2026-03-02 | W2/W4 | grouped stroke transform 정합성 반영(group-aware target + group centroid pivot) | NATIVE-005 완료, transform v1 기능 잠금 | Codex |
| 2026-03-02 | W4 | 게스트 첫 실행 Studio 자동 진입(1회) + CTA 문구 정렬 | 첫 세션 핵심 기능 체험 마찰 감소 | Codex |
| 2026-03-02 | W4/W8 | Slice lock/visibility를 편집 입력에 연결 + PIP 이동/위치복원 + guest flow XCUITest(PIP move 포함) 고정 | NATIVE-009 완료 및 모바일 편집 조작성 개선 | Codex |
