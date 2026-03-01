# SceneState Contract v1

## Purpose
Shared contract between editor runtime, local persistence, sync queue, and server bridge.

## StudioSnapshotV1
```ts
type StudioSnapshotV1 = {
  schemaVersion: 1;
  projectId: string;
  mode: 'blank' | 'free-draw' | 'starter';
  starterTemplateId?: string;
  starterProportion?: {
    headRatio: number;
    bodyRatio: number;
    legRatio: number;
  };
  brushSize: number;
  brushStrength: number;
  brushColorHex: string;
  drawTool: 'free-draw' | 'fill' | 'erase';
  mirrorDraw: boolean;
  smoothMeshView: boolean;
  autoFillClosedStroke: boolean;
  activeView: 'front' | 'right' | 'top' | 'left' | 'back';
  inputMode: 'draw' | 'pan';
  transformPivotMode?: 'object' | 'selection' | 'world';
  gridSnapEnabled?: boolean;
  gridSnapStep?: number;
  angleSnapEnabled?: boolean;
  angleSnapDegrees?: number;
  sliceEnabled: boolean;
  activeSliceLayerId: string;
  sliceLayers: Array<{
    id: string;
    name: string;
    axis: 'x' | 'y' | 'z';
    depth: number;
    visible: boolean;
    locked: boolean;
    colorHex: string;
  }>;
  updatedAt: number;
}
```

## Forward-compatibility rules
1. Unknown fields must be ignored by consumers.
2. Missing optional fields should fall back to safe defaults.
3. Breaking changes require `schemaVersion` increment.

## UI Locale note
1. UI 언어(`ko/en/ja`)는 `StudioSnapshotV1`이 아니라 별도 UI preference store로 관리한다.
2. Scene 계약은 기하/편집 상태 중심으로 유지하고, 표시 언어는 분리한다.
