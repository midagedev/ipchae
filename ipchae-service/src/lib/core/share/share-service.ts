import type { StartMode, StudioSnapshotV1 } from '$lib/core/contracts/studio';
import { createStore, get, set } from 'idb-keyval';
import {
	recordPartImportReward,
	recordShareCloneReward
} from '$lib/core/gamification/gamification-store';
import { saveStudioSnapshot } from '$lib/core/persistence/project-snapshot-store';
import { getSupabaseClient } from '$lib/core/supabase/client';

export type ProjectShareView = {
	shareId?: string;
	sourceProjectId?: string;
	ownerId?: string;
	shareSlug: string;
	title: string;
	description: string;
	ownerName: string;
	visibility: 'public' | 'unlisted';
	allowClone: boolean;
};

export type PartShareView = {
	partShareId?: string;
	partId?: string;
	ownerId?: string;
	partShareSlug: string;
	partName: string;
	category: string;
	styleFamily: string;
	ownerName: string;
	allowImport: boolean;
	allowRemix: boolean;
};

export type CollabInviteRole = 'owner' | 'editor' | 'viewer';

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

function toOwnerLabel(ownerId?: string | null) {
	if (!ownerId) return 'anonymous';
	return ownerId.slice(0, 8);
}

function buildSlug(seed: string) {
	const base = seed
		.toLowerCase()
		.replace(/[^a-z0-9\s-]/g, '')
		.trim()
		.replace(/\s+/g, '-')
		.slice(0, 40);
	const suffix = Math.random().toString(36).slice(2, 8);
	return `${base || 'share'}-${suffix}`;
}

const SHARE_STORE = createStore('ipchae-local', 'shares');
const LOCAL_PROJECT_SHARES_KEY = 'project-shares-v1';
const LOCAL_PART_SHARES_KEY = 'part-shares-v1';

async function readLocalProjectShares() {
	const rows = await get<ProjectShareView[] | undefined>(LOCAL_PROJECT_SHARES_KEY, SHARE_STORE);
	return rows ?? [];
}

async function writeLocalProjectShares(shares: ProjectShareView[]) {
	await set(LOCAL_PROJECT_SHARES_KEY, shares, SHARE_STORE);
}

async function readLocalPartShares() {
	const rows = await get<PartShareView[] | undefined>(LOCAL_PART_SHARES_KEY, SHARE_STORE);
	return rows ?? [];
}

async function writeLocalPartShares(shares: PartShareView[]) {
	await set(LOCAL_PART_SHARES_KEY, shares, SHARE_STORE);
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
	const supabase = getSupabaseClient();
	if (supabase) {
		const { data, error } = await supabase
			.from('project_shares')
			.select('id, project_id, owner_id, share_slug, title, description, visibility, allow_clone')
			.eq('share_slug', shareSlug)
			.maybeSingle();

		if (!error && data && (data.visibility === 'public' || data.visibility === 'unlisted')) {
			return {
				shareId: data.id,
				sourceProjectId: data.project_id,
				ownerId: data.owner_id,
				shareSlug: data.share_slug,
				title: data.title,
				description: data.description ?? '',
				ownerName: toOwnerLabel(data.owner_id),
				visibility: data.visibility,
				allowClone: data.allow_clone
			};
		}
	}

	const localShares = await readLocalProjectShares();
	const local = localShares.find((item) => item.shareSlug === shareSlug);
	if (local) return local;

	return PROJECT_MOCKS.find((item) => item.shareSlug === shareSlug) ?? null;
}

export async function loadPartShare(partShareSlug: string): Promise<PartShareView | null> {
	const supabase = getSupabaseClient();
	if (supabase) {
		const { data, error } = await supabase
			.from('part_shares')
			.select('id, part_id, owner_id, share_slug, title, visibility, allow_import, allow_remix')
			.eq('share_slug', partShareSlug)
			.maybeSingle();

		if (!error && data && (data.visibility === 'public' || data.visibility === 'unlisted')) {
			let partName = data.title;
			let styleFamily = 'generic';
			let category = 'part';

			const metaResp = await supabase
				.from('parts')
				.select('name, style_family, category_id')
				.eq('id', data.part_id)
				.maybeSingle();

			if (!metaResp.error && metaResp.data) {
				partName = metaResp.data.name;
				styleFamily = metaResp.data.style_family ?? styleFamily;
				category = metaResp.data.category_id ? 'categorized' : 'part';
			}

			return {
				partShareId: data.id,
				partId: data.part_id,
				ownerId: data.owner_id ?? undefined,
				partShareSlug: data.share_slug,
				partName,
				category,
				styleFamily,
				ownerName: toOwnerLabel(data.owner_id),
				allowImport: data.allow_import,
				allowRemix: data.allow_remix
			};
		}
	}

	const localShares = await readLocalPartShares();
	const local = localShares.find((item) => item.partShareSlug === partShareSlug);
	if (local) return local;

	return PART_MOCKS.find((item) => item.partShareSlug === partShareSlug) ?? null;
}

export async function createProjectShareFromProject({
	projectId,
	title,
	description,
	visibility = 'unlisted',
	allowClone = true
}: {
	projectId: string;
	title: string;
	description: string;
	visibility?: 'public' | 'unlisted' | 'private';
	allowClone?: boolean;
}): Promise<string | null> {
	const supabase = getSupabaseClient();
	if (!supabase) {
		const shareSlug = buildSlug(title);
		const localShare: ProjectShareView = {
			shareSlug,
			sourceProjectId: projectId,
			ownerName: 'local-user',
			title,
			description,
			visibility: visibility === 'private' ? 'unlisted' : visibility,
			allowClone
		};
		const localShares = await readLocalProjectShares();
		await writeLocalProjectShares([localShare, ...localShares.filter((item) => item.shareSlug !== shareSlug)]);
		return shareSlug;
	}
	const {
		data: { session }
	} = await supabase.auth.getSession();
	if (!session?.user?.id) {
		const shareSlug = buildSlug(title);
		const localShare: ProjectShareView = {
			shareSlug,
			sourceProjectId: projectId,
			ownerName: 'local-user',
			title,
			description,
			visibility: visibility === 'private' ? 'unlisted' : visibility,
			allowClone
		};
		const localShares = await readLocalProjectShares();
		await writeLocalProjectShares([localShare, ...localShares.filter((item) => item.shareSlug !== shareSlug)]);
		return shareSlug;
	}

	const shareSlug = buildSlug(title);
	const { error } = await supabase.from('project_shares').insert({
		project_id: projectId,
		owner_id: session.user.id,
		share_slug: shareSlug,
		title,
		description,
		visibility,
		allow_clone: allowClone
	});
	if (error) return null;
	return shareSlug;
}

export async function createPartShareFromPart({
	partId,
	title,
	description,
	visibility = 'unlisted',
	allowImport = true,
	allowRemix = true
}: {
	partId: string;
	title: string;
	description: string;
	visibility?: 'public' | 'unlisted' | 'private';
	allowImport?: boolean;
	allowRemix?: boolean;
}): Promise<string | null> {
	const supabase = getSupabaseClient();
	if (!supabase) {
		const shareSlug = buildSlug(title);
		const localShare: PartShareView = {
			partShareSlug: shareSlug,
			partId,
			partName: title,
			category: 'part',
			styleFamily: 'generic',
			ownerName: 'local-user',
			allowImport,
			allowRemix
		};
		const localShares = await readLocalPartShares();
		await writeLocalPartShares([localShare, ...localShares.filter((item) => item.partShareSlug !== shareSlug)]);
		return shareSlug;
	}
	const {
		data: { session }
	} = await supabase.auth.getSession();
	if (!session?.user?.id) {
		const shareSlug = buildSlug(title);
		const localShare: PartShareView = {
			partShareSlug: shareSlug,
			partId,
			partName: title,
			category: 'part',
			styleFamily: 'generic',
			ownerName: 'local-user',
			allowImport,
			allowRemix
		};
		const localShares = await readLocalPartShares();
		await writeLocalPartShares([localShare, ...localShares.filter((item) => item.partShareSlug !== shareSlug)]);
		return shareSlug;
	}

	const shareSlug = buildSlug(title);
	const { error } = await supabase.from('part_shares').insert({
		part_id: partId,
		owner_id: session.user.id,
		share_slug: shareSlug,
		title,
		description,
		visibility,
		allow_import: allowImport,
		allow_remix: allowRemix
	});
	if (error) return null;
	return shareSlug;
}

export async function createCollabInviteFromShare(
	share: ProjectShareView,
	{
		role = 'editor',
		maxEditors = 4,
		expiresInMinutes = 60 * 24
	}: {
		role?: CollabInviteRole;
		maxEditors?: number;
		expiresInMinutes?: number;
	} = {}
): Promise<string | null> {
	if (!share.sourceProjectId) return null;

	const localFallbackCode = `${share.sourceProjectId}:${role}`;
	const supabase = getSupabaseClient();
	if (!supabase || !share.shareId) {
		return localFallbackCode;
	}

	const {
		data: { session }
	} = await supabase.auth.getSession();
	if (!session?.user?.id) {
		return localFallbackCode;
	}

	const randomSuffix = Math.random().toString(36).slice(2, 10);
	const inviteCode = `${share.sourceProjectId}:${role}:${randomSuffix}`;
	const expiresAtIso = new Date(Date.now() + Math.max(5, expiresInMinutes) * 60_000).toISOString();

	const { data, error } = await supabase
		.from('project_collab_invites')
		.insert({
			project_id: share.sourceProjectId,
			invite_code: inviteCode,
			default_role: role,
			max_editors: Math.max(1, maxEditors),
			expires_at: expiresAtIso,
			is_active: true
		})
		.select('invite_code')
		.single();

	if (error || !data?.invite_code) {
		return localFallbackCode;
	}

	return data.invite_code;
}

export async function cloneProjectFromShare(share: ProjectShareView): Promise<string> {
	if (!share.allowClone) throw new Error('CLONE_DISABLED');
	const projectId = crypto.randomUUID();
	await saveStudioSnapshot(createDefaultSnapshot(projectId, 'starter'));

	const supabase = getSupabaseClient();
	if (supabase && share.shareId && share.sourceProjectId) {
		const {
			data: { session }
		} = await supabase.auth.getSession();

		if (session?.user?.id) {
			const nowIso = new Date().toISOString();
			await supabase.from('projects').insert({
				id: projectId,
				owner_id: session.user.id,
				name: `${share.title} Remix`,
				updated_at: nowIso
			});
			await supabase.from('project_remixes').insert({
				source_share_id: share.shareId,
				source_project_id: share.sourceProjectId,
				remix_project_id: projectId,
				owner_id: session.user.id
			});
			await supabase.from('share_events').insert({
				share_id: share.shareId,
				event_type: 'share_clone_success',
				viewer_id: session.user.id,
				referrer: 'web'
			});
		}
	}

	await recordShareCloneReward(share.shareSlug);
	return projectId;
}

export async function importPartFromShare(share: PartShareView): Promise<string> {
	if (!share.allowImport) throw new Error('IMPORT_DISABLED');
	const projectId = crypto.randomUUID();
	await saveStudioSnapshot(createDefaultSnapshot(projectId, 'starter'));

	const supabase = getSupabaseClient();
	if (supabase && share.partShareId && share.partId) {
		const {
			data: { session }
		} = await supabase.auth.getSession();

		if (session?.user?.id) {
			const nowIso = new Date().toISOString();
			await supabase.from('projects').insert({
				id: projectId,
				owner_id: session.user.id,
				name: `${share.partName} Import Project`,
				updated_at: nowIso
			});
			await supabase.from('project_used_parts').insert({
				project_id: projectId,
				part_id: share.partId,
				source_part_share_id: share.partShareId,
				inserted_by: session.user.id
			});
			await supabase.from('part_events').insert({
				part_share_id: share.partShareId,
				event_type: 'part_import_success',
				viewer_id: session.user.id,
				referrer: 'web'
			});
		}
	}

	await recordPartImportReward(share.partShareSlug);
	return projectId;
}
