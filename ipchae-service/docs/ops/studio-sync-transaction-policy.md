# Studio Transaction Sync Policy

기준일: 2026-03-01  
대상: `/Users/hckim/repo/ipchae/ipchae-service`

## 목적
Studio 편집 동작을 autosave/sync로 반영할 때, 어떤 이벤트를 `트랜잭션 경계`로 보는지 고정한다.

## 트랜잭션 경계 정의
1. `FixedDraftStage`의 히스토리 스택에 entry가 push될 때 1개 트랜잭션으로 본다.
2. Undo/Redo도 각각 1개 트랜잭션으로 본다.
3. 트랜잭션 발생 시 Stage는 `historycommit` 이벤트를 발생시킨다.

## 현재 코드 경로
1. Stage: `historycommit` 이벤트를 `pushHistory`, `undoLastStroke`, `redoLastStroke`에서 emit한다.
2. Studio page: `on:historycommit` 수신 시 `editCommitToken`을 갱신한다.
3. `autosaveSignal`에 `editCommitToken`이 포함되어 autosave debounce가 재시작된다.
4. debounce 만료 시 로컬 snapshot 저장 후 원격 sync queue enqueue를 수행한다.

## 큐 정책
1. Sync queue coalesce key는 `projectId`다.
2. 같은 프로젝트의 연속 편집은 최신 snapshot 기준으로 압축 전송한다.
3. 목적은 네트워크 부하를 줄이면서 최신 상태를 안정적으로 반영하는 것이다.

## 제한과 후속
1. 현재는 command patch 단위(예: primitive_insert, geometry_cut)를 서버에 개별 저장하지 않는다.
2. 서버는 프로젝트 메타 갱신 중심이며, 완전한 협업 command log는 후속 범위다.
3. 필요 시 Phase C에서 `command envelope` 기반 상세 sync로 확장한다.
