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

