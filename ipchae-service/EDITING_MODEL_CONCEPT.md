# IPCHAE Editing Model Playbook (Mesh-Centric CAD-Lite)

기준일: 2026-02-28  
대상: `/Users/hckim/repo/ipchae/ipchae-service`

## 1. 목표와 원칙
이 문서는 에디터 편집 모델을 일관되게 유지하기 위한 기준 문서다.

핵심 목표:
1. 편집 단위를 `스트로크`가 아닌 `메시`로 통일한다.
2. `복사/붙여넣기/잘라내기/복제/트랜스폼/컷팅` 같은 CAD 기본 액션을 예측 가능하게 만든다.
3. `선택`, `레이어`, `슬라이스`를 동시에 적용해도 동작이 명확해야 한다.
4. 초등 사용자 UX와 고급 UX가 같은 데이터 모델 위에서 공존해야 한다.

핵심 원칙:
1. 입력 방식은 다양해도 결과 조작 단위는 항상 `MeshNode`.
2. 모든 편집은 Command로 기록되고 Undo/Redo 가능해야 한다.
3. "지금 어디에 편집되는지"를 화면에 항상 노출한다.

## 2. 범위와 비범위
범위:
1. Mesh/Group/Layer/Slice/Selection 모델
2. Clipboard 액션 (copy/paste/cut/duplicate)
3. Transform 액션 (move/rotate/scale/pivot)
4. Geometry 액션 (brush/primitive/pen-extrude/geometry cut)
5. 협업 lock/sync 충돌 처리 기준

비범위:
1. 고급 파라메트릭 제약 솔버(치수 구속 방정식)
2. 완전한 기계 CAD feature tree 재생산

## 3. 핵심 도메인 모델
## 3.1 Scene Graph
1. `Scene`
2. `GroupNode` (선택 가능, 트랜스폼 가능)
3. `MeshNode` (기본 편집 단위)

규칙:
1. 브러시/조형/컷팅은 MeshNode에만 적용한다.
2. GroupNode는 구조/정리/일괄 변환 용도다.

## 3.2 Layer
Layer는 의미적 분류와 가시성/잠금 제어를 담당한다.
1. 예: `Body`, `Face`, `Hair`, `Accessory`
2. 모든 MeshNode는 1개의 Layer를 가진다.
3. Layer는 데이터 소유 단위다.

## 3.3 SliceMask
Slice는 편집 범위 마스크다.
1. Slice는 데이터 소유 단위가 아니다.
2. Slice ON일 때는 마스크 내부만 편집 허용된다.
3. Slice는 여러 Layer에 동시에 작동할 수 있다.

## 3.4 SelectionSet
1. `activeNodeId` (주 대상)
2. `nodeIds` (다중 선택 집합)
3. `mode`: single/multi

초등 모드:
1. single only
2. 자동 active 유지(최근 생성 메시)

## 3.5 EditContext
EditContext는 매 오퍼레이션 평가 컨텍스트다.
1. tool
2. selection
3. activeLayer
4. activeSliceMask
5. uiMode(beginner/advanced)
6. transformSpace(local/world)
7. pivotMode(object/selection/world-origin/custom)

## 4. 편집 가능 대상 계산
편집 가능 대상은 다음 교집합으로 계산한다.

`WritableTargets = SelectedMeshNodes ∩ VisibleUnlockedLayers ∩ SliceMaskPass`

평가 순서:
1. Selection 존재 여부
2. Node lock/visibility
3. Layer lock/visibility
4. Slice 마스크 포함 여부
5. Tool별 추가 조건(예: closed sketch 필요)

## 5. 액션 모델 (Command 기준)
모든 액션은 Command로 기록한다.

공통 필드:
1. `commandId`
2. `type`
3. `targetNodeIds`
4. `timestamp`
5. `actorId`
6. `baseVersion`
7. `forwardPatch`
8. `inversePatch`

Undo/Redo:
1. Undo는 inversePatch 적용
2. Redo는 forwardPatch 재적용
3. 멀티 스텝 액션은 Transaction으로 묶는다

## 6. Clipboard 액션 정의
## 6.1 Copy
1. SelectionSet의 MeshNode 스냅샷을 clipboard에 저장
2. 원본은 변경하지 않음
3. clipboard payload는 geometry + transform + material + layer ref 포함

## 6.2 Paste
1. clipboard payload로 새 MeshNode 생성
2. 새 node id 부여
3. 기본 오프셋 적용
4. pasted 노드들을 자동 선택

Paste 오프셋 규칙:
1. 기본: 카메라 우상향 소량 이동
2. 연속 붙여넣기: 누적 오프셋 증가
3. 같은 위치 붙여넣기 옵션은 고급 모드에서만 노출

## 6.3 Cut (Clipboard Cut)
1. SelectionSet을 clipboard에 복사
2. 원본 MeshNode 삭제
3. Undo 시 삭제 복원

## 6.4 Duplicate
1. Copy + Paste를 한 Transaction으로 실행
2. clipboard를 덮어쓰지 않는 duplicate 모드 지원

## 6.5 Delete
1. 선택 MeshNode 제거
2. clipboard는 건드리지 않음

## 7. Transform 액션 정의
기본 변환:
1. Move
2. Rotate
3. Scale (uniform/non-uniform)
4. Reset Transform
5. Freeze Transform (옵션)

트랜스폼 공간:
1. Local
2. World

피벗 모드:
1. Object pivot
2. Selection center
3. World origin
4. Custom pivot

스냅:
1. Grid snap
2. Angle snap
3. Surface/vertex snap(고급)

규칙:
1. 초등 모드는 Move/Scale 중심
2. Rotate와 Custom pivot은 고급 모드

## 8. Geometry 액션 정의
## 8.1 Brush Sculpt
1. 대상: active MeshNode
2. Slice/Layers/Lock 게이트 통과 시에만 적용

## 8.2 Primitive Insert
1. Sphere/Box/Cylinder/Cone/Torus는 새 MeshNode 생성
2. 생성 즉시 active selection으로 전환

## 8.3 Pen + Extrude
1. Pen sketch는 2D profile 데이터 생성
2. Closed profile이면 Extrude로 MeshNode 생성/변형
3. Open profile은 경고 후 적용 금지

## 8.4 Geometry Cut (형상 컷팅)
`Cut`을 두 종류로 분리해 용어 충돌을 방지한다.
1. Clipboard Cut: 선택 객체 이동용
2. Geometry Cut: 기하 분할/절단용

Geometry Cut 세부:
1. Plane Cut: 메시를 절단면 기준 분할
2. Knife Cut: 경로 기반 분할
3. Boolean Subtract: 도형으로 깎기

결과 정책:
1. 기본: `원본 대체`
2. 옵션: `양쪽 파트 분리 생성` (advanced)

## 9. Layer/Slice/Selection 조합 정책
정책:
1. Layer는 "무엇을 편집하는가"
2. Slice는 "어디까지 편집하는가"
3. Selection은 "어떤 메시를 편집하는가"

권장 UX 표시:
1. `대상 메시: ...`
2. `활성 레이어: ...`
3. `슬라이스: OFF/ON(axis, depth)`

예외 처리:
1. 선택 없음: 편집 차단 + "최근 메시 선택" CTA
2. Layer 잠금: 편집 차단 + 잠금 해제 CTA
3. Slice 바깥: 커서 경고 표시

## 10. 초등 모드/고급 모드 UX 가이드
## 10.1 Beginner
1. 단일 선택 자동 유지
2. 최소 버튼: 선택, 복제, 실행취소, 내보내기
3. 고급 컷팅/불리언/다중선택 숨김
4. 실수 방지: 위험 액션 확인 단계

## 10.2 Advanced
1. 다중 선택 + 그룹
2. full transform/gizmo
3. geometry cut/boolean/snap/pivot 노출

## 11. 협업/동기화 관점
협업 lock:
1. lock granularity = `mesh_node_id`
2. geometry cut/boolean 중엔 lock 필수

충돌 처리:
1. `baseVersion` 불일치 시 `CONFLICT_STALE_BASE`
2. 최신 노드 pull 후 command 재평가

동기화:
1. sync queue coalescing key: `projectId + nodeId + commandType`
2. 트랜잭션 단위 커밋 보장

## 12. 데이터 계약 초안
```ts
type MeshNodeId = string;
type GroupNodeId = string;
type LayerId = string;
type SliceMaskId = string;

type MeshNode = {
  id: MeshNodeId;
  groupId: GroupNodeId | null;
  layerId: LayerId;
  name: string;
  visible: boolean;
  locked: boolean;
  transform: {
    position: [number, number, number];
    rotation: [number, number, number];
    scale: [number, number, number];
  };
  geometryRef: string;
  materialRef: string | null;
  version: number;
};

type SelectionSet = {
  activeNodeId: MeshNodeId | null;
  nodeIds: MeshNodeId[];
};

type ClipboardPayload = {
  sourceProjectId: string;
  nodes: MeshNode[];
  copiedAt: string;
  mode: 'copy' | 'cut';
};

type EditCommand = {
  commandId: string;
  type:
    | 'node_copy'
    | 'node_paste'
    | 'node_cut'
    | 'node_duplicate'
    | 'node_delete'
    | 'transform_apply'
    | 'brush_apply'
    | 'primitive_insert'
    | 'pen_extrude'
    | 'geometry_cut'
    | 'boolean_subtract';
  targetNodeIds: MeshNodeId[];
  baseVersion: number;
  forwardPatch: unknown;
  inversePatch: unknown;
  actorId: string;
  createdAt: string;
};
```

## 13. 구현 전환 로드맵
## Phase A: 모델 고정
1. MeshNode/Selection/Layer/Slice 타입 고정
2. 스트로크를 `default MeshNode` 아래에 임시 수용

## Phase B: Clipboard + Transform
1. Copy/Paste/Cut/Duplicate/Delete 명령 구현
2. Move/Rotate/Scale + pivot + snap 도입

## Phase C: Geometry Cut
1. Plane Cut/Knife Cut/Boolean Subtract 순차 구현
2. Undo/Redo와 협업 lock 연동

## Phase D: UX 수렴
1. Beginner/Advanced 분기 마무리
2. 도움말/온보딩/에러 문구 정리

## 14. 품질 기준 (DoD)
1. 복사/붙여넣기/잘라내기/복제가 MeshNode 단위로 100% 일관 동작
2. Transform 액션이 Undo/Redo에서 오차 없이 복원
3. Geometry Cut이 lock/sync/undo와 충돌 없이 동작
4. 레이어/슬라이스/선택 충돌 시 결과가 항상 예측 가능
5. 초등 모드에서 첫 편집 성공률을 저해하지 않음

## 15. 테스트 체크리스트
1. 단일 선택 복제 -> 위치 오프셋 검증
2. 다중 선택 잘라내기/붙여넣기 -> 레이어 유지 검증
3. 잠금 Layer에서 brush/transform/cut 차단 검증
4. Slice ON/OFF에 따른 편집 범위 검증
5. 협업 2인 동시 편집에서 node lock 충돌 검증
6. Undo/Redo 50회 반복 안정성 검증
