import type { DraftSummary } from '$lib/core/contracts/editor-stage';

export type ValidationSeverity = 'error' | 'warning';

export type ValidationIssue = {
	code: 'thin_wall' | 'non_manifold' | 'open_edges' | 'self_intersection' | 'empty_mesh';
	severity: ValidationSeverity;
	message: string;
};

export type ValidationReport = {
	errors: ValidationIssue[];
	warnings: ValidationIssue[];
	all: ValidationIssue[];
	exportAllowed: boolean;
};

export function validateDraftSummary(summary: DraftSummary): ValidationReport {
	const issues: ValidationIssue[] = [];

	if (summary.dotCount === 0) {
		issues.push({
			code: 'empty_mesh',
			severity: 'error',
			message: '조형 데이터가 없습니다. 먼저 Draw/Build 단계에서 형태를 만들어 주세요.'
		});
	}

	if (summary.dotCount > 0 && summary.dotCount < 18) {
		issues.push({
			code: 'open_edges',
			severity: 'error',
			message: '표면이 충분히 닫히지 않은 것으로 보입니다. 스트로크를 더 추가해 주세요.'
		});
	}

	if (summary.averageRadius > 0 && summary.averageRadius < 0.08) {
		issues.push({
			code: 'thin_wall',
			severity: 'warning',
			message: '벽 두께가 얇을 수 있습니다. 브러시 크기 또는 빌드 레이어를 늘려 주세요.'
		});
	}

	if (summary.strokeCount > 0 && summary.dotCount / Math.max(1, summary.strokeCount) > 420) {
		issues.push({
			code: 'non_manifold',
			severity: 'warning',
			message: '중첩/겹침이 많아 비다양체(non-manifold) 가능성이 있습니다.'
		});
	}

	if (summary.bounds) {
		const spanX = summary.bounds.maxX - summary.bounds.minX;
		const spanY = summary.bounds.maxY - summary.bounds.minY;
		const spanZ = summary.bounds.maxZ - summary.bounds.minZ;
		const minSpan = Math.min(spanX, spanY, spanZ);
		const maxSpan = Math.max(spanX, spanY, spanZ);
		if (minSpan > 0 && maxSpan / minSpan > 20 && summary.dotCount > 80) {
			issues.push({
				code: 'self_intersection',
				severity: 'warning',
				message: '형태 비율이 극단적이라 자기교차 가능성이 있습니다. 일부 영역을 정리해 주세요.'
			});
		}
	}

	const errors = issues.filter((item) => item.severity === 'error');
	const warnings = issues.filter((item) => item.severity === 'warning');

	return {
		errors,
		warnings,
		all: issues,
		exportAllowed: errors.length === 0
	};
}

