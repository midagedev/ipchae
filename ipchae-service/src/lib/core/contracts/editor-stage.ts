export type DraftExportDot = {
	x: number;
	y: number;
	z: number;
	radius: number;
	depositAmount: number;
	colorHex: string;
};

export type DraftBounds = {
	minX: number;
	minY: number;
	minZ: number;
	maxX: number;
	maxY: number;
	maxZ: number;
};

export type DraftSummary = {
	strokeCount: number;
	dotCount: number;
	averageRadius: number;
	averageDepositAmount: number;
	bounds: DraftBounds | null;
	dots: DraftExportDot[];
};

export type EditorStageHandle = {
	updateMainView: (view: 'front' | 'back' | 'left' | 'right' | 'top') => void;
	setInputMode: (mode: 'draw' | 'pan') => void;
	zoomMain: (zoomFactor: number) => void;
	resetMainView: () => void;
	undoLastStroke: () => void;
	redoLastStroke: () => void;
	clearAllStrokes: () => void;
	getDraftSummary: (maxDots?: number) => DraftSummary;
	getSelectedStrokeId: () => string | null;
	selectLastStroke: () => boolean;
	clearStrokeSelection: () => boolean;
	copySelectedStroke: () => boolean;
	cutSelectedStroke: () => boolean;
	deleteSelectedStroke: () => boolean;
	pasteCopiedStroke: () => boolean;
	duplicateSelectedStroke: () => boolean;
	insertPrimitiveMesh: (kind: 'sphere' | 'box' | 'cylinder') => boolean;
	translateSelectedStroke: (dx: number, dy: number, dz: number) => boolean;
	nudgeSelectedStroke: (deltaU: number, deltaV: number, deltaN?: number) => boolean;
	scaleSelectedStroke: (scaleFactor: number) => boolean;
	rotateSelectedStroke: (degrees: number) => boolean;
	resetSelectedStrokeTransform: () => boolean;
	sliceCutSelectedStroke: () => boolean;
};
