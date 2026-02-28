# IPCHAE CAD-Lite Trajectory Plan (Primitive Mesh + Pen Tool)

기준일: 2026-02-28
대상: `/Users/hckim/repo/ipchae/ipchae-service`

## 0. 원 스펙 대비 정리
원 스펙(`../docs/00_MASTER_BUILD_SPEC.md`) 기준:
1. MVP 포함: `Add Blob`, `Push/Pull`, `Pinch/Inflate`, `Smooth`, `Carve`, `Import Mesh`
2. MVP 제외: `고급 파라메트릭 제약 CAD`

즉, 원 스펙에는 "조형 툴 기반 CAD-like 편집"은 포함되어 있었지만, 아래는 명시적 요구가 약하거나 빠져 있었다.
1. 프리미티브 생성 툴(구/박스/원통/원뿔/토러스)
2. 펜 기반 스케치 -> 돌출(Extrude) 워크플로우
3. 제약 기반(치수/구속) 풀 CAD

이 계획은 "풀 CAD"가 아니라, 원 스펙의 제품 성격을 유지하는 CAD-Lite 확장 궤적이다.

## 1. 목표
1. Free Draw 중심 UX를 유지하면서 프리미티브/펜 기반 조형을 추가한다.
2. 어린 사용자/초심자 흐름을 해치지 않도록 단계적 노출(기본/고급)한다.
3. 협업/동기화/검증/내보내기 파이프라인과 충돌 없이 통합한다.

## 2. 범위 정의
## 2.1 포함 (CAD-Lite)
1. Primitive Insert: `sphere`, `box`, `cylinder`, `cone`, `torus`
2. Pen Sketch: 화면 평면/슬라이스 평면에 폴리라인 작성
3. Pen Extrude: 닫힌 스케치의 높이 기반 돌출
4. Transform Gizmo: Move/Rotate/Scale(선택 오브젝트)
5. Grid/Snap: 기본 격자 스냅, 축 정렬 스냅
6. Operation History: primitive/pen/extrude/transform undo-redo

## 2.2 제외 (이번 트랙)
1. 제약 스케치 솔버(수평/수직/동심/치수 방정식)
2. 완전한 feature tree 편집기
3. 고급 boolean 커널(비정상 토폴로지 복구 자동화 포함)

## 3. 기술 방향
1. Geometry 표현은 기존 Stage와 호환되는 "dot/surface" 흐름을 유지
2. Primitive/Pen 결과는 공통 `operation patch`로 저장/동기화
3. Export/Validation은 동일 파이프라인 재사용
4. 협업 lock은 mesh node 단위 그대로 유지하고 opType만 확장

## 4. 병렬 트랙
| 트랙 | 내용 | 선행 |
|---|---|---|
| C1 Kernel | primitive 생성, pen path, extrude 메쉬 생성 | 없음 |
| C2 Editor UI | 툴바/인스펙터/단축키/선택상태 | C1 일부 |
| C3 Data/Sync | opType 확장, 스냅샷/큐/충돌 | C1 계약 |
| C4 Collab | lock/patch 권한 검증, stale-base 재적용 | C3 |
| C5 QA/Perf | 유닛/E2E/성능 프로파일링 | C1~C4 |

## 5. 단계별 궤적 (6주)
## Phase 0 (Week 1): 계약/모델 선고정
1. `DrawTool` 확장 계약 정의: `primitive-*`, `pen`, `extrude`, `transform`
2. `operation patch`에 `primitive_add`, `pen_commit`, `extrude_apply`, `transform_apply` 추가
3. Stage 내부 선택 상태 모델(`selectedNodeId`, `gizmoMode`) 정의

게이트:
1. 타입 계약이 고정되고 기존 기능과 타입 충돌 없음

## Phase 1 (Week 2): Primitive Insert MVP
1. Sphere/Box/Cylinder 생성
2. 기본 파라미터(반지름, 폭/높이/깊이, 세그먼트) UI
3. 생성 즉시 이동/스케일 가능(회전은 Phase 2)

게이트:
1. Primitive 3종 생성/삭제/undo 가능
2. 저장/복원 후 위치/스케일 유지

## Phase 2 (Week 3): Pen + Extrude MVP
1. Pen 툴로 폴리라인 입력(닫힘 판단 포함)
2. 닫힌 경로만 Extrude 허용
3. 슬라이스 평면 기준 Extrude 지원

게이트:
1. 닫힌 경로 -> 돌출 -> export 가능
2. 열린 경로는 명확한 에러 UX 제공

## Phase 3 (Week 4): Transform/Gizmo + Snap
1. Move/Rotate/Scale gizmo
2. Grid/축 스냅 토글
3. 수치 입력 박스(간단 단위: mm 가정)

게이트:
1. gizmo 조작 정확도/되돌리기 안정화
2. 모바일에서 최소 이동/스케일 조작 가능

## Phase 4 (Week 5): Sync/Collab 통합
1. 신규 opType에 대한 sync queue 병합 규칙 추가
2. collab lock 충돌 시 `CONFLICT_STALE_BASE` 처리 강화
3. 세션 참여자에게 primitive/pen 변경 실시간 반영

게이트:
1. 2인 편집에서 primitive 동시 작업 시 lock 규칙 정상
2. stale-base 재시도 루프 무한 반복 없음

## Phase 5 (Week 6): 품질/성능/릴리즈
1. E2E 확장(primitive 생성, pen extrude, collab lock)
2. 성능 기준 수립(중간 사양 장치 기준 입력 지연/프레임)
3. 문서/튜토리얼/온보딩 업데이트

게이트:
1. 주요 시나리오 E2E 통과
2. 크래시/데이터 유실 이슈 없음

## 6. 구체 백로그 (즉시 착수용)
1. `src/lib/core/contracts/studio.ts`에 도구 타입 확장
2. `src/lib/stage/FixedDraftStage.svelte`에 primitive factory 추가
3. `src/routes/studio/[projectId]/+page.svelte` 툴 패널 확장
4. `src/lib/core/sync/*` op payload 스키마 확장
5. `src/lib/core/collab/collab-service.ts` role/lock 검증에 신규 opType 연결
6. `e2e/smoke.spec.ts` + 신규 `e2e/cad-lite.spec.ts` 추가

## 7. 리스크와 대응
1. 리스크: 기존 free-draw 품질 하락
2. 대응: primitive/pen 코드를 draw 파이프라인과 분리하고 회귀 테스트 고정
3. 리스크: op payload 증가로 sync 지연
4. 대응: project 단위 coalescing + patch delta 축소
5. 리스크: 협업 충돌 증가
6. 대응: lock granularity를 node 단위로 유지하고 stale-base 재적용 횟수 제한

## 8. 완료 기준 (CAD-Lite)
1. Primitive 5종 생성/편집/저장/복원/내보내기 가능
2. Pen 스케치 + Extrude 루프 완주 가능
3. 신규 기능이 sync/collab/share 흐름을 깨지 않음
4. 모바일/데스크톱에서 핵심 조작 가능
