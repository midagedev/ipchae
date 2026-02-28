import type { DraftBounds, DraftSummary } from '$lib/core/contracts/editor-stage';

type Vec3 = [number, number, number];

function toCubeBounds(bounds: DraftBounds | null): DraftBounds {
	if (bounds) {
		const padding = 0.24;
		return {
			minX: bounds.minX - padding,
			minY: bounds.minY - padding,
			minZ: bounds.minZ - padding,
			maxX: bounds.maxX + padding,
			maxY: bounds.maxY + padding,
			maxZ: bounds.maxZ + padding
		};
	}
	return {
		minX: -0.5,
		minY: -0.5,
		minZ: -0.5,
		maxX: 0.5,
		maxY: 0.5,
		maxZ: 0.5
	};
}

function cubeVertices(bounds: DraftBounds): Vec3[] {
	const { minX, minY, minZ, maxX, maxY, maxZ } = bounds;
	return [
		[minX, minY, minZ],
		[maxX, minY, minZ],
		[maxX, maxY, minZ],
		[minX, maxY, minZ],
		[minX, minY, maxZ],
		[maxX, minY, maxZ],
		[maxX, maxY, maxZ],
		[minX, maxY, maxZ]
	];
}

function cubeFaces(): Array<[number, number, number]> {
	return [
		[0, 1, 2],
		[0, 2, 3],
		[4, 6, 5],
		[4, 7, 6],
		[0, 4, 5],
		[0, 5, 1],
		[1, 5, 6],
		[1, 6, 2],
		[2, 6, 7],
		[2, 7, 3],
		[3, 7, 4],
		[3, 4, 0]
	];
}

function computeAverageColor(summary: DraftSummary) {
	if (summary.dots.length === 0) {
		return { r: 59, g: 130, b: 246 };
	}
	let r = 0;
	let g = 0;
	let b = 0;
	for (const dot of summary.dots) {
		const hex = dot.colorHex.replace('#', '');
		r += Number.parseInt(hex.slice(0, 2), 16);
		g += Number.parseInt(hex.slice(2, 4), 16);
		b += Number.parseInt(hex.slice(4, 6), 16);
	}
	const count = summary.dots.length;
	return {
		r: Math.round(r / count),
		g: Math.round(g / count),
		b: Math.round(b / count)
	};
}

export function buildAsciiStl(summary: DraftSummary, solidName = 'ipchae_model') {
	const bounds = toCubeBounds(summary.bounds);
	const vertices = cubeVertices(bounds);
	const faces = cubeFaces();

	const lines: string[] = [`solid ${solidName}`];
	for (const [a, b, c] of faces) {
		const va = vertices[a];
		const vb = vertices[b];
		const vc = vertices[c];
		lines.push('  facet normal 0 0 0');
		lines.push('    outer loop');
		lines.push(`      vertex ${va[0]} ${va[1]} ${va[2]}`);
		lines.push(`      vertex ${vb[0]} ${vb[1]} ${vb[2]}`);
		lines.push(`      vertex ${vc[0]} ${vc[1]} ${vc[2]}`);
		lines.push('    endloop');
		lines.push('  endfacet');
	}
	lines.push(`endsolid ${solidName}`);
	return lines.join('\n');
}

export function buildAsciiPly(summary: DraftSummary) {
	const bounds = toCubeBounds(summary.bounds);
	const vertices = cubeVertices(bounds);
	const faces = cubeFaces();
	const { r, g, b } = computeAverageColor(summary);

	const lines: string[] = [
		'ply',
		'format ascii 1.0',
		`element vertex ${vertices.length}`,
		'property float x',
		'property float y',
		'property float z',
		'property uchar red',
		'property uchar green',
		'property uchar blue',
		`element face ${faces.length}`,
		'property list uchar int vertex_indices',
		'end_header'
	];

	for (const vertex of vertices) {
		lines.push(`${vertex[0]} ${vertex[1]} ${vertex[2]} ${r} ${g} ${b}`);
	}

	for (const [a, bIdx, c] of faces) {
		lines.push(`3 ${a} ${bIdx} ${c}`);
	}

	return lines.join('\n');
}

export function downloadTextFile(content: string, filename: string, mimeType: string) {
	const blob = new Blob([content], { type: mimeType });
	const url = URL.createObjectURL(blob);
	const anchor = document.createElement('a');
	anchor.href = url;
	anchor.download = filename;
	anchor.click();
	URL.revokeObjectURL(url);
}

