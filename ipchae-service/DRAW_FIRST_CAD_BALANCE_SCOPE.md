# IPCHAE Draw-First x CAD Balance Scope

기준일: 2026-03-01  
대상: `/Users/hckim/repo/ipchae/ipchae-service`

## 1. 목표
이 문서는 IPCHAE의 핵심 컨셉을 `2D 드로잉 기반 3D 펜 모델링`으로 유지하면서, 필요한 CAD 기본기를 어디까지 구현할지 범위를 고정하기 위한 기준 문서다.

핵심 문장:
1. 기본 경험은 펜처럼 빠르고 직관적이어야 한다.
2. 정밀 기능은 필요할 때만 열리는 CAD 보정 레이어로 제공한다.
3. 기능 추가가 첫 30초의 그리기 성공률을 떨어뜨리면 기본 노출에서 제외한다.

## 2. 제품 원칙 (80/20)
1. 80%: Draw-First 루프  
`그리기 -> 선택 -> 이동/크기/회전 -> 묶기 -> 내보내기`
2. 20%: CAD 보강  
정렬, 스냅, 수치 입력, 컷팅, 그룹 정리

운영 규칙:
1. 초등 모드는 Draw-First 루프만 상시 노출한다.
2. 고급 모드는 CAD 보강 기능을 열되, 기본 루프를 덮어쓰지 않는다.
3. 동일 액션이라도 라벨은 초등/고급 문맥에 맞게 분리한다.

## 3. UX 계층
## 3.1 Beginner (기본)
상시 노출:
1. Draw/Fill/Erase
2. Select, Duplicate, Undo/Redo
3. Move/Scale/Rotate(버튼 기반)
4. Group/Ungroup(버튼 기반)
5. Export

숨김:
1. Import/검증 상세
2. 고급 컷팅 모드 세부 옵션
3. 수치 기반 패널

## 3.2 Advanced
추가 노출:
1. Multi-select, Select Group, Group/Ungroup
2. Primitive Insert (Sphere/Box/Cylinder)
3. Slice Cut, Layer/Slice 상세 제어
4. Import/Share/Validate

## 4. 구현 범위 고정 (Scope Lock)
## 4.1 Scope A: Draw-First Core (고정, 현재 진행 완료 범위)
1. 자유 드로잉 + Fill/Erase + Mirror
2. 선택/복사/붙여넣기/잘라내기/복제/삭제
3. Undo/Redo
4. Move/Rotate/Scale/Reset Transform
5. Multi-select + batch 편집
6. Group/Ungroup + Select Group
7. Primitive Insert (Sphere/Box/Cylinder)
8. Slice Cut(기본)

## 4.2 Scope B: CAD Baseline (다음 우선순위)
1. 수치 입력 Transform (이동/회전/스케일 숫자 입력)
2. Selection Pivot 모드 토글 (Object / Selection / World)
3. Grid Snap + Angle Snap
4. Plane Cut 모드 분리 (현재 Slice Cut과 분리된 Geometry Cut)
5. Selection/Layer/Slice 충돌 시 안내 문구 표준화
6. 배치 액션 Transaction 단위 원격 Sync 정책 확정

## 4.3 Scope C: CAD Extended (후순위)
1. Knife Cut
2. Boolean Subtract/Union/Intersect
3. Pen Profile + Extrude
4. 정렬/분배(Align/Distribute)

## 4.4 Out of Scope (현 단계 제외)
1. 파라메트릭 치수 구속
2. 기계 CAD 수준 Feature Tree
3. 고급 히스토리 브랜칭(노드 그래프형)

## 4.5 진행 현황 (2026-03-01)
완료:
1. Scope A 전체(드로잉/선택/복제/트랜스폼/그룹/프리미티브/기본 컷)
2. 배치 편집 트랜잭션 undo/redo 1회 처리
3. 그룹 ID 안전 복제/붙여넣기

진행(부분 완료):
1. Scope B-1 수치 Transform 패널: 완료
2. Scope B-2 Pivot 모드(Object/Selection/World): 완료
3. Scope B-3 Grid/Angle Snap: 기본 완료(Transform 단계)
4. Scope B-4 Plane Cut 독립 툴: 기본 완료(keep side 옵션)

남은 Scope B:
1. Snap의 드로잉 경로 적용 범위 확대 여부 결정
2. Selection/Layer/Slice 충돌 문구 표준화 최종안
3. Transaction 단위 원격 Sync 정책 문서/코드 일치화

## 5. 기능 게이팅 기준
새 기능은 아래를 모두 통과해야 기본 노출 가능:
1. 첫 드로잉 시작 시간(TTFD) 악화 없음
2. 초등 모드 첫 세션에서 도움말 없이 실행 가능
3. Undo/Redo 일관성 보장
4. Layer/Slice/Selection 게이트와 충돌 없음

하나라도 실패하면:
1. Advanced 전용으로 격리
2. 실험 플래그 상태로 유지
3. 용어/버튼 재설계 후 재평가

## 6. 구현 단계(실행 순서)
## Phase 1. Draw-First 안정화
1. 현재 구현 액션 회귀 테스트 강화
2. 배치 편집 Transaction undo/redo 안정성 검증

## Phase 2. CAD Baseline A
1. 수치 입력 Transform 패널
2. Pivot 모드 전환 UI

## Phase 3. CAD Baseline B
1. Grid/Angle Snap
2. Plane Cut 독립 툴

## Phase 4. Extended 후보 검증
1. Knife/Boolean의 초등 UX 영향 실험
2. 영향 크면 Advanced 전용 유지

## 7. 품질 기준 (DoD)
1. Draw-First 루프가 마우스 5클릭 이내로 완결된다.
2. 배치 편집은 항상 undo 1회로 되돌아간다.
3. 그룹 복제/붙여넣기 시 원본 그룹과 ID 충돌이 없다.
4. Layer/Slice 잠금 상태에서 편집은 전부 차단되고 이유를 UI에 표시한다.
5. e2e smoke + 타입체크 + 단위테스트가 모두 통과한다.

## 8. 의사결정 체크리스트
기능 추가 요청이 오면 다음 순서로 판단한다.
1. Draw-First 루프를 직접 강화하는가?
2. CAD 정확도를 실질적으로 개선하는가?
3. 초등 모드 기본 노출이 필요한가?
4. Advanced 격리만으로도 목적을 달성하는가?
5. Sync/Undo/Selection 모델 충돌 없이 구현 가능한가?

모든 답이 명확하지 않으면:
1. Scope B 이후로 이관
2. 문서에 보류 근거를 기록
