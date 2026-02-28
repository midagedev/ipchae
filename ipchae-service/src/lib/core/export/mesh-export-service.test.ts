import { describe, expect, it } from 'vitest';
import { buildAsciiPly, buildAsciiStl } from '$lib/core/export/mesh-export-service';
import type { DraftSummary } from '$lib/core/contracts/editor-stage';

const summary: DraftSummary = {
	strokeCount: 2,
	dotCount: 12,
	averageRadius: 0.18,
	averageDepositAmount: 0.1,
	bounds: {
		minX: -1,
		minY: -2,
		minZ: -3,
		maxX: 2,
		maxY: 3,
		maxZ: 4
	},
	dots: [
		{
			x: 0,
			y: 0,
			z: 0,
			radius: 0.2,
			depositAmount: 0.1,
			colorHex: '#3b82f6'
		}
	]
};

describe('mesh export service', () => {
	it('builds ascii stl', () => {
		const stl = buildAsciiStl(summary, 'ipchae');
		expect(stl.startsWith('solid ipchae')).toBe(true);
		expect(stl.includes('facet normal')).toBe(true);
	});

	it('builds ascii ply', () => {
		const ply = buildAsciiPly(summary);
		expect(ply.startsWith('ply')).toBe(true);
		expect(ply.includes('element vertex 8')).toBe(true);
		expect(ply.includes('end_header')).toBe(true);
	});
});

