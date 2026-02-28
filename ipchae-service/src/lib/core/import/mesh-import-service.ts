const textDecoder = new TextDecoder();

export const MAX_IMPORT_FILE_SIZE_BYTES = 25 * 1024 * 1024;
export const MAX_IMPORT_TRIANGLES = 300_000;

export type MeshImportFormat = 'stl' | 'ply' | 'obj' | 'glb';
export type MeshImportErrorCode =
	| 'UNSUPPORTED_FORMAT'
	| 'FILE_TOO_LARGE'
	| 'TRIANGLE_LIMIT_EXCEEDED'
	| 'INVALID_FILE';

export type MeshImportSummary = {
	format: MeshImportFormat;
	fileName: string;
	byteSize: number;
	vertexCount: number;
	faceCount: number;
	triangleCount: number;
	normalization: {
		recenter: true;
		uniformScale: number;
	};
	warnings: string[];
};

export class MeshImportError extends Error {
	code: MeshImportErrorCode;

	constructor(code: MeshImportErrorCode, message: string) {
		super(message);
		this.name = 'MeshImportError';
		this.code = code;
	}
}

function extensionOf(fileName: string) {
	const tokens = fileName.toLowerCase().split('.');
	return tokens.length > 1 ? tokens.at(-1) ?? '' : '';
}

function detectStlType(bytes: Uint8Array): 'ascii' | 'binary' {
	if (bytes.length >= 84) {
		const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
		const triangleCount = view.getUint32(80, true);
		const expectedLength = 84 + triangleCount * 50;
		if (expectedLength === bytes.length) return 'binary';
	}

	const text = textDecoder.decode(bytes.slice(0, Math.min(bytes.length, 4096))).trimStart();
	if (text.startsWith('solid')) return 'ascii';
	return 'binary';
}

export function detectMeshFormat(fileName: string, bytes: Uint8Array): MeshImportFormat | null {
	const ext = extensionOf(fileName);
	if (ext === 'stl' || ext === 'ply' || ext === 'obj' || ext === 'glb') return ext;

	if (bytes.length >= 4) {
		const magic = String.fromCharCode(bytes[0], bytes[1], bytes[2], bytes[3]);
		if (magic === 'glTF') return 'glb';
		if (magic === 'ply\n' || magic === 'ply\r') return 'ply';
	}

	const sniff = textDecoder.decode(bytes.slice(0, Math.min(bytes.length, 1024))).trimStart();
	if (sniff.startsWith('solid')) return 'stl';
	if (sniff.startsWith('v ') || sniff.startsWith('o ') || sniff.startsWith('#')) return 'obj';
	return null;
}

function parseAsciiStl(fileName: string, bytes: Uint8Array): MeshImportSummary {
	const text = textDecoder.decode(bytes);
	const facetMatches = text.match(/facet\s+normal/gi);
	const faceCount = facetMatches?.length ?? 0;
	if (faceCount === 0) {
		throw new MeshImportError('INVALID_FILE', 'ASCII STL facet 정보를 찾을 수 없습니다.');
	}
	const vertexCount = faceCount * 3;
	return {
		format: 'stl',
		fileName,
		byteSize: bytes.byteLength,
		vertexCount,
		faceCount,
		triangleCount: faceCount,
		normalization: {
			recenter: true,
			uniformScale: recommendedScale(faceCount)
		},
		warnings: []
	};
}

function parseBinaryStl(fileName: string, bytes: Uint8Array): MeshImportSummary {
	if (bytes.length < 84) {
		throw new MeshImportError('INVALID_FILE', 'Binary STL 헤더가 손상되었습니다.');
	}
	const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
	const triangleCount = view.getUint32(80, true);
	const expectedLength = 84 + triangleCount * 50;
	if (expectedLength > bytes.length) {
		throw new MeshImportError('INVALID_FILE', 'Binary STL triangle 데이터가 불완전합니다.');
	}
	return {
		format: 'stl',
		fileName,
		byteSize: bytes.byteLength,
		vertexCount: triangleCount * 3,
		faceCount: triangleCount,
		triangleCount,
		normalization: {
			recenter: true,
			uniformScale: recommendedScale(triangleCount)
		},
		warnings: []
	};
}

function parsePly(fileName: string, bytes: Uint8Array): MeshImportSummary {
	const text = textDecoder.decode(bytes);
	const lines = text.split(/\r?\n/);

	let isAscii = false;
	let headerEndIndex = -1;
	let vertexCount = 0;
	let faceCount = 0;

	for (let index = 0; index < lines.length; index += 1) {
		const line = lines[index].trim();
		if (index === 0 && line !== 'ply') {
			throw new MeshImportError('INVALID_FILE', 'PLY 헤더가 올바르지 않습니다.');
		}
		if (line.startsWith('format ')) {
			isAscii = line.includes('ascii');
		}
		if (line.startsWith('element vertex ')) {
			vertexCount = Number.parseInt(line.split(/\s+/).at(-1) ?? '0', 10);
		}
		if (line.startsWith('element face ')) {
			faceCount = Number.parseInt(line.split(/\s+/).at(-1) ?? '0', 10);
		}
		if (line === 'end_header') {
			headerEndIndex = index + 1;
			break;
		}
	}

	if (!isAscii) {
		throw new MeshImportError('INVALID_FILE', '현재 ASCII PLY만 지원합니다.');
	}
	if (headerEndIndex < 0) {
		throw new MeshImportError('INVALID_FILE', 'PLY end_header를 찾을 수 없습니다.');
	}

	if (faceCount === 0) {
		for (const line of lines.slice(headerEndIndex + vertexCount)) {
			const trimmed = line.trim();
			if (!trimmed) continue;
			const count = Number.parseInt(trimmed.split(/\s+/)[0] ?? '0', 10);
			if (count >= 3) {
				faceCount += 1;
			}
		}
	}

	const triangleCount = faceCount;
	return {
		format: 'ply',
		fileName,
		byteSize: bytes.byteLength,
		vertexCount: Math.max(0, vertexCount),
		faceCount: Math.max(0, faceCount),
		triangleCount: Math.max(0, triangleCount),
		normalization: {
			recenter: true,
			uniformScale: recommendedScale(triangleCount)
		},
		warnings: []
	};
}

function parseObj(fileName: string, bytes: Uint8Array): MeshImportSummary {
	const text = textDecoder.decode(bytes);
	const lines = text.split(/\r?\n/);
	let vertexCount = 0;
	let faceCount = 0;
	let triangleCount = 0;

	for (const line of lines) {
		const trimmed = line.trim();
		if (trimmed.startsWith('v ')) {
			vertexCount += 1;
			continue;
		}
		if (!trimmed.startsWith('f ')) continue;
		const points = trimmed
			.split(/\s+/)
			.slice(1)
			.filter(Boolean);
		if (points.length >= 3) {
			faceCount += 1;
			triangleCount += points.length - 2;
		}
	}

	if (vertexCount === 0 || faceCount === 0) {
		throw new MeshImportError('INVALID_FILE', 'OBJ 정점/면 정보를 찾을 수 없습니다.');
	}

	return {
		format: 'obj',
		fileName,
		byteSize: bytes.byteLength,
		vertexCount,
		faceCount,
		triangleCount,
		normalization: {
			recenter: true,
			uniformScale: recommendedScale(triangleCount)
		},
		warnings: []
	};
}

function parseGlb(fileName: string, bytes: Uint8Array): MeshImportSummary {
	if (bytes.length < 12) {
		throw new MeshImportError('INVALID_FILE', 'GLB 헤더가 너무 짧습니다.');
	}
	const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
	const magic = view.getUint32(0, true);
	const version = view.getUint32(4, true);
	if (magic !== 0x46546c67) {
		throw new MeshImportError('INVALID_FILE', 'GLB 매직 넘버가 일치하지 않습니다.');
	}

	const warnings: string[] = [];
	if (version < 2) {
		warnings.push(`GLB version ${version} detected; v2 권장`);
	}
	warnings.push('GLB는 상세 정점/면 카운트 계산 없이 가져옵니다.');

	return {
		format: 'glb',
		fileName,
		byteSize: bytes.byteLength,
		vertexCount: 0,
		faceCount: 0,
		triangleCount: 0,
		normalization: {
			recenter: true,
			uniformScale: 1
		},
		warnings
	};
}

function recommendedScale(triangleCount: number) {
	if (triangleCount >= 180_000) return 0.35;
	if (triangleCount >= 100_000) return 0.5;
	if (triangleCount >= 50_000) return 0.75;
	return 1;
}

function assertLimits(fileSize: number, triangleCount: number) {
	if (fileSize > MAX_IMPORT_FILE_SIZE_BYTES) {
		throw new MeshImportError('FILE_TOO_LARGE', '파일 크기가 25MB 제한을 초과했습니다.');
	}
	if (triangleCount > MAX_IMPORT_TRIANGLES) {
		throw new MeshImportError('TRIANGLE_LIMIT_EXCEEDED', '삼각형 수가 300,000 제한을 초과했습니다.');
	}
}

export function parseMeshBytes(fileName: string, bytes: Uint8Array): MeshImportSummary {
	const format = detectMeshFormat(fileName, bytes);
	if (!format) {
		throw new MeshImportError('UNSUPPORTED_FORMAT', '지원되지 않는 메쉬 포맷입니다.');
	}

	const summary =
		format === 'stl'
			? detectStlType(bytes) === 'binary'
				? parseBinaryStl(fileName, bytes)
				: parseAsciiStl(fileName, bytes)
			: format === 'ply'
				? parsePly(fileName, bytes)
				: format === 'obj'
					? parseObj(fileName, bytes)
					: parseGlb(fileName, bytes);

	assertLimits(bytes.byteLength, summary.triangleCount);
	return summary;
}

export async function importMeshFile(file: File): Promise<MeshImportSummary> {
	if (file.size > MAX_IMPORT_FILE_SIZE_BYTES) {
		throw new MeshImportError('FILE_TOO_LARGE', '파일 크기가 25MB 제한을 초과했습니다.');
	}
	const buffer = await file.arrayBuffer();
	return parseMeshBytes(file.name, new Uint8Array(buffer));
}
