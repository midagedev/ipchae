# Native Editor Implementation Status (2026-03-02)

기준 경로:
- iOS 구현: `/Users/hckim/repo/ipchae/ipchae-service/ios-app/AppShell/Sources/AppShell/UI/StudioSandboxView.swift`
- 계약: `/Users/hckim/repo/ipchae/ipchae-service/src/lib/core/contracts/editor-stage.ts`

## 1. 이번 반영 요약
1. Stabilizer 추가
2. Stylus Palm Rejection(Pencil 전용 그리기) 추가
3. 멀티터치 제스처(2-finger Undo, 3-finger Redo, Quick Eyedropper) 통합
4. 입력/보정 설정 autosave 복구 연동

## 2. EditorStageHandle 커버리지
- 전체: 29
- 구현: 20
- 부분 구현: 2
- 미구현: 7

### 구현됨 (핵심)
- 뷰 전환, 줌/리셋
- Undo/Redo/Clear
- 선택/다중선택/그룹/복제/삭제/복사/붙여넣기
- 스케일/회전/2D 이동(nudge)
- 요약 내보내기(`DraftSummary`)

### 부분 구현
1. `translateSelectedStroke(dx,dy,dz)`
: 현재는 2D 평면 이동 중심이며 `dz` 기반 이동은 미구현
2. `nudgeSelectedStroke(deltaU,deltaV,deltaN?)`
: `deltaU/deltaV`만 지원, `deltaN` 미지원

### 미구현
1. `insertPrimitiveMesh`
2. `getSelectedStrokeId`
3. `getSelectedStrokeIds`
4. `resetSelectedStrokeTransform`
5. `planeCutSelectedStroke`
6. `sliceCutSelectedStroke`
7. `translateSelectedStroke`의 완전한 3D 축 이동

## 3. 다음 실행 우선순위
1. P0
- 컷 기능 2종(`planeCut`, `sliceCut`) 구현
- 변형 리셋 + 3D 축 이동 지원
- iPad 3패널 레이아웃 완성
2. P1
- STL/PLY import/export 실구현
- 입력/보정 회귀 테스트 자동화
3. P2
- parts/share/collab
- i18n ko/en/ja 완성
- 가격정책 실연동
