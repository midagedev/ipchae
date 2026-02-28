import type { StartMode, StudioSnapshotV1 } from '$lib/core/contracts/studio';
import {
	recordPartImportReward,
	recordShareCloneReward
} from '$lib/core/gamification/gamification-store';
import { saveStudioSnapshot } from '$lib/core/persistence/project-snapshot-store';

export type ProjectShareView = {
	shareSlug: string;
	title: string;
	description: string;
	ownerName: string;
	visibility: 'public' | 'unlisted';
	allowClone: boolean;
};

export type PartShareView = {
	partShareSlug: string;
	partName: string;
	category: string;
	styleFamily: string;
	ownerName: string;
	allowImport: boolean;
	allowRemix: boolean;
};

function createDefaultSnapshot(projectId: string, mode: StartMode): StudioSnapshotV1 {
	return {
		schemaVersion: 1,
		projectId,
		mode,
		starterTemplateId: undefined,
		starterProportion: {
			headRatio: 1.45,
			bodyRatio: 1,
			legRatio: 0.75
		},
		brushSize: 20,
		brushStrength: 0.28,
		brushColorHex: '#3b82f6',
		drawTool: 'free-draw',
		mirrorDraw: false,
		smoothMeshView: true,
		autoFillClosedStroke: false,
		activeView: 'front',
		inputMode: 'draw',
		sliceEnabled: false,
		activeSliceLayerId: 'slice-layer-1',
		sliceLayers: [
			{
				id: 'slice-layer-1',
				name: 'Z Layer 1',
				axis: 'z',
				depth: 0,
				visible: true,
				locked: false,
				colorHex: '#3b82f6'
			}
		],
		updatedAt: Date.now()
	};
}

const PROJECT_MOCKS: ProjectShareView[] = [
	{
		shareSlug: 'demo-hero-robot',
		title: 'Hero Robot Base',
		description: '기본 로봇 캐릭터 베이스입니다. 이걸 이용해서 고쳐보시겠어요?',
		ownerName: 'ipchae-team',
		visibility: 'public',
		allowClone: true
	},
	{
		shareSlug: 'demo-forest-animal',
		title: 'Forest Animal Kit',
		description: '동물형 템플릿 기반 스타터 프로젝트입니다.',
		ownerName: 'starter-lab',
		visibility: 'unlisted',
		allowClone: true
	}
];

const PART_MOCKS: PartShareView[] = [
	{
		partShareSlug: 'demo-part-hair-01',
		partName: 'Curly Hair 01',
		category: 'hair',
		styleFamily: 'nendo',
		ownerName: 'starter-lab',
		allowImport: true,
		allowRemix: true
	},
	{
		partShareSlug: 'demo-part-armor-02',
		partName: 'Armor Plate 02',
		category: 'outfit',
		styleFamily: 'robot',
		ownerName: 'ipchae-team',
		allowImport: true,
		allowRemix: true
	}
];

export async function loadProjectShare(shareSlug: string): Promise<ProjectShareView | null> {
	return PROJECT_MOCKS.find((item) => item.shareSlug === shareSlug) ?? null;
}

export async function loadPartShare(partShareSlug: string): Promise<PartShareView | null> {
	return PART_MOCKS.find((item) => item.partShareSlug === partShareSlug) ?? null;
}

export async function cloneProjectFromShare(share: ProjectShareView): Promise<string> {
	if (!share.allowClone) throw new Error('CLONE_DISABLED');
	const projectId = crypto.randomUUID();
	await saveStudioSnapshot(createDefaultSnapshot(projectId, 'starter'));
	await recordShareCloneReward(share.shareSlug);
	return projectId;
}

export async function importPartFromShare(share: PartShareView): Promise<string> {
	if (!share.allowImport) throw new Error('IMPORT_DISABLED');
	const projectId = crypto.randomUUID();
	await saveStudioSnapshot(createDefaultSnapshot(projectId, 'starter'));
	await recordPartImportReward(share.partShareSlug);
	return projectId;
}
