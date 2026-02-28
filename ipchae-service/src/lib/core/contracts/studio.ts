export type StartMode = 'blank' | 'free-draw' | 'starter';
export type DrawTool = 'free-draw' | 'fill' | 'erase';
export type ViewId = 'front' | 'right' | 'top' | 'left' | 'back';
export type InputMode = 'draw' | 'pan';
export type SliceAxis = 'x' | 'y' | 'z';

export type SliceLayer = {
	id: string;
	name: string;
	axis: SliceAxis;
	depth: number;
	visible: boolean;
	locked: boolean;
	colorHex: string;
};

export type StudioSnapshotV1 = {
	schemaVersion: 1;
	projectId: string;
	mode: StartMode;
	starterTemplateId?: string;
	starterProportion?: {
		headRatio: number;
		bodyRatio: number;
		legRatio: number;
	};
	brushSize: number;
	brushStrength: number;
	brushColorHex: string;
	drawTool: DrawTool;
	mirrorDraw: boolean;
	smoothMeshView: boolean;
	autoFillClosedStroke: boolean;
	activeView: ViewId;
	inputMode: InputMode;
	sliceEnabled: boolean;
	activeSliceLayerId: string;
	sliceLayers: SliceLayer[];
	updatedAt: number;
};
