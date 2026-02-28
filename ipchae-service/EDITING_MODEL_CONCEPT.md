# IPCHAE Editing Model Concept (Mesh-Centric)

기준일: 2026-02-28  
대상: `/Users/hckim/repo/ipchae/ipchae-service`

## 1. 문제 정의
현재 스트로크 중심 모델은 다음 한계가 있다.
1. 복사/붙여넣기/잘라내기/복제의 단위가 불명확하다.
2. 프리미티브 메쉬와 드로잉 결과를 같은 수준에서 다루기 어렵다.
3. 슬라이스/레이어와 선택 상태를 함께 제어하기 어렵다.

해결 방향:
1. 편집의 기본 단위를 `스트로크`가 아니라 `메시 노드`로 전환한다.
2. 스트로크와 프리미티브는 메시 노드를 만드는 입력/피처로 취급한다.

## 2. 핵심 추상화
## 2.1 MeshNode (기본 편집 단위)
1. 실제 기하 데이터(또는 그에 대한 참조)를 가진 객체
2. 선택/복제/삭제/잠금/가시성의 주체
3. 협업 lock의 기본 대상 (`mesh_node_id`)

## 2.2 GroupNode (구조 단위)
1. 여러 MeshNode를 묶는 계층
2. 일괄 이동/숨김/잠금에 사용
3. 초등 모드에서는 기본 숨김 가능

## 2.3 Layer (의미/출력 단위)
1. Body/Hair/Accessory 같은 의미 분류
2. 가시성/잠금/정렬/필터 단위
3. 메시 노드는 정확히 1개 레이어에 속한다(초기 규칙)

## 2.4 SliceMask (편집 마스크 단위)
1. 화면/편집 범위를 제한하는 마스크
2. 데이터 소유 단위가 아니라, "편집 허용 범위" 단위
3. 활성화 시 브러시/조형 오퍼레이션이 마스크 내부에만 적용

## 2.5 SelectionSet (선택 상태)
1. 현재 선택된 MeshNode 집합
2. 초등 모드: 단일 선택만 허용
3. 고급 모드: 다중 선택 허용

## 2.6 EditContext (실행 컨텍스트)
1. `tool`
2. `selectionSet`
3. `activeLayer`
4. `activeSliceMask`
5. `mode` (`beginner`/`advanced`)

## 3. 브러시/조형 적용 규칙
편집 가능 영역은 다음 교집합으로 정의한다.

`WritableTargets = SelectedMeshNodes ∩ VisibleUnlockedLayers ∩ ActiveSliceMask`

세부 규칙:
1. 선택 메시가 없으면 브러시는 적용되지 않는다.
2. 선택 메시가 잠겨 있으면 적용되지 않는다.
3. 레이어가 잠겨/숨김이면 적용되지 않는다.
4. 슬라이스가 켜져 있으면 슬라이스 범위 밖 적용은 차단된다.

## 4. 액션 단위 정의
기본 액션은 모두 MeshNode 단위다.
1. Select
2. Copy
3. Paste
4. Cut
5. Duplicate
6. Delete
7. Merge (옵션)

클립보드 규칙:
1. 클립보드는 MeshNode 배열 스냅샷을 저장한다.
2. 붙여넣기는 새 node id를 가진 복제본을 만든다.
3. 기본 붙여넣기 오프셋은 카메라/뷰 기반으로 자동 적용한다.

## 5. 스트로크/프리미티브와의 관계
1. Stroke는 `MeshNode`의 geometry를 변형하는 `FeatureOp`다.
2. Primitive Insert는 새 `MeshNode`를 생성하는 `FeatureOp`다.
3. Pen/Extrude도 동일하게 새 `MeshNode` 생성 또는 기존 `MeshNode` 변형으로 통일한다.

즉:
1. 입력 방식은 다를 수 있지만 결과 조작 단위는 항상 MeshNode다.

## 6. UX 원칙 (초등 사용자 기준)
## 6.1 기본(초등) 모드
1. 자동으로 "최근 만든 메시"를 선택 상태로 유지
2. 단일 선택만 노출
3. 슬라이스 기본 OFF
4. 상단에 항상 현재 대상 표시: `대상: 머리 메시 / 레이어: Body / 슬라이스: OFF`
5. 액션 버튼은 최소 4개: `선택`, `복제`, `실행취소`, `내보내기`

## 6.2 고급 모드
1. 다중 선택, 그룹, 슬라이스 편집, 상세 lock 상태 표시
2. Layer/Slice/Selection 패널 전체 노출

## 7. 레이어 + 슬라이스 결합 정책
1. Layer는 "무엇을 편집하는가"
2. Slice는 "어디까지 편집하는가"
3. Selection은 "어떤 메시를 편집하는가"

우선순위:
1. Selection 체크
2. Layer 잠금/가시성 체크
3. SliceMask 포함 체크
4. 통과 시에만 tool op 적용

## 8. 협업/동기화 연계
1. lock 단위는 `mesh_node_id`를 유지한다.
2. op payload는 `target_mesh_node_ids`를 포함한다.
3. stale-base 충돌은 `node version` 기준으로 판단한다.
4. sync queue coalescing은 `projectId` + `nodeId` 단위 확장을 고려한다.

## 9. 데이터 계약 초안
```ts
type MeshNodeId = string;
type LayerId = string;
type SliceMaskId = string;

type MeshNode = {
  id: MeshNodeId;
  name: string;
  layerId: LayerId;
  visible: boolean;
  locked: boolean;
  transform: {
    position: [number, number, number];
    rotation: [number, number, number];
    scale: [number, number, number];
  };
  geometryRef: string; // or inline geometry payload
  version: number;
};

type SelectionSet = {
  nodeIds: MeshNodeId[];
  activeNodeId: MeshNodeId | null;
};

type EditContext = {
  mode: 'beginner' | 'advanced';
  tool: string;
  selection: SelectionSet;
  activeLayerId: LayerId | null;
  activeSliceMaskId: SliceMaskId | null;
};
```

## 10. 단계적 전환 계획
## Phase 1
1. MeshNode/SelectionSet 계약 추가
2. 기존 스트로크를 단일 MeshNode 아래에 묶어 호환 유지
3. 선택 없는 편집 금지 + 안내 메시지 추가

## Phase 2
1. Copy/Paste/Cut/Duplicate를 MeshNode 단위로 구현
2. Layer 잠금/가시성 게이트를 tool 적용 경로에 강제

## Phase 3
1. SliceMask 게이트를 tool 적용 경로에 강제
2. Primitive/Pen/Extrude를 MeshNode 생성 파이프라인으로 통합

## 11. 성공 기준
1. 사용자가 "지금 어느 메시에 그려지는지" 항상 이해 가능
2. 복사/붙여넣기/잘라내기/복제가 일관된 단위로 동작
3. 레이어/슬라이스/선택 충돌 시 예측 가능한 결과를 제공
4. 협업 lock 충돌이 메시 단위로 명확히 설명 가능
