import { describe, expect, it } from 'vitest';
import { validateDraftSummary } from '$lib/core/validation/validation-service';
import type { DraftSummary } from '$lib/core/contracts/editor-stage';

function makeSummary(overrides?: Partial<DraftSummary>): DraftSummary {
	return {
		strokeCount: 1,
		dotCount: 24,
		averageRadius: 0.12,
		averageDepositAmount: 0.08,
		bounds: {
			minX: -1,
			minY: -1,
			minZ: -1,
			maxX: 1,
			maxY: 1,
			maxZ: 1
		},
		dots: [],
		...overrides
	};
}

describe('validateDraftSummary', () => {
	it('blocks export for empty mesh', () => {
		const report = validateDraftSummary(makeSummary({ dotCount: 0 }));
		expect(report.exportAllowed).toBe(false);
		expect(report.errors.some((item) => item.code === 'empty_mesh')).toBe(true);
	});

	it('allows export for stable summary', () => {
		const report = validateDraftSummary(makeSummary());
		expect(report.exportAllowed).toBe(true);
	});
});

