import { describe, expect, it } from 'vitest';
import { MeshImportError, parseMeshBytes } from '$lib/core/import/mesh-import-service';

function toBytes(text: string) {
	return new TextEncoder().encode(text);
}

function makeBinaryStl(triangleCount: number) {
	const bytes = new Uint8Array(84 + triangleCount * 50);
	const view = new DataView(bytes.buffer);
	view.setUint32(80, triangleCount, true);
	return bytes;
}

describe('parseMeshBytes', () => {
	it('parses OBJ vertex and face counts', () => {
		const obj = ['v 0 0 0', 'v 1 0 0', 'v 0 1 0', 'f 1 2 3'].join('\n');
		const summary = parseMeshBytes('sample.obj', toBytes(obj));
		expect(summary.format).toBe('obj');
		expect(summary.vertexCount).toBe(3);
		expect(summary.faceCount).toBe(1);
		expect(summary.triangleCount).toBe(1);
	});

	it('parses ASCII PLY header counts', () => {
		const ply = [
			'ply',
			'format ascii 1.0',
			'element vertex 4',
			'property float x',
			'property float y',
			'property float z',
			'element face 2',
			'property list uchar int vertex_indices',
			'end_header',
			'0 0 0',
			'1 0 0',
			'1 1 0',
			'0 1 0',
			'3 0 1 2',
			'3 0 2 3'
		].join('\n');
		const summary = parseMeshBytes('sample.ply', toBytes(ply));
		expect(summary.format).toBe('ply');
		expect(summary.vertexCount).toBe(4);
		expect(summary.faceCount).toBe(2);
		expect(summary.triangleCount).toBe(2);
	});

	it('parses binary STL triangle count', () => {
		const summary = parseMeshBytes('sample.stl', makeBinaryStl(12));
		expect(summary.format).toBe('stl');
		expect(summary.faceCount).toBe(12);
		expect(summary.vertexCount).toBe(36);
		expect(summary.triangleCount).toBe(12);
	});

	it('parses GLB magic header', () => {
		const bytes = new Uint8Array(20);
		const view = new DataView(bytes.buffer);
		view.setUint32(0, 0x46546c67, true);
		view.setUint32(4, 2, true);
		view.setUint32(8, bytes.byteLength, true);
		const summary = parseMeshBytes('sample.glb', bytes);
		expect(summary.format).toBe('glb');
		expect(summary.warnings.length).toBeGreaterThan(0);
	});

	it('throws on unsupported format', () => {
		expect(() => parseMeshBytes('sample.xyz', toBytes('hello'))).toThrowError(MeshImportError);
	});
});
