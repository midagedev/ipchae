import { createStore, get, set } from 'idb-keyval';
import type { DraftSummary } from '$lib/core/contracts/editor-stage';
import { getSupabaseClient } from '$lib/core/supabase/client';

export type MyPartVisibility = 'private' | 'unlisted' | 'public';

export type MyPart = {
	id: string;
	name: string;
	category: 'head' | 'face' | 'hair' | 'outfit' | 'hand' | 'foot' | 'props' | 'voxel';
	styleFamily: string;
	visibility: MyPartVisibility;
	sourceProjectId: string;
	previewColorHex: string;
	polyCountEstimate: number;
	createdAt: number;
	updatedAt: number;
};

const DB = createStore('ipchae-local', 'my-parts');
const KEY = 'parts-v1';

const CATEGORIES: MyPart['category'][] = [
	'head',
	'face',
	'hair',
	'outfit',
	'hand',
	'foot',
	'props',
	'voxel'
];

async function readAll(): Promise<MyPart[]> {
	const parts = await get<MyPart[] | undefined>(KEY, DB);
	if (!parts) return [];
	return parts.sort((a, b) => b.updatedAt - a.updatedAt);
}

async function writeAll(parts: MyPart[]) {
	await set(KEY, parts, DB);
}

function pickCategoryFromDraft(summary: DraftSummary): MyPart['category'] {
	const index = Math.max(0, summary.strokeCount % CATEGORIES.length);
	return CATEGORIES[index];
}

function pickColor(summary: DraftSummary) {
	return summary.dots[0]?.colorHex ?? '#3b82f6';
}

export async function listMyParts() {
	return readAll();
}

export async function savePartFromDraft({
	projectId,
	summary,
	name,
	styleFamily = 'generic'
}: {
	projectId: string;
	summary: DraftSummary;
	name?: string;
	styleFamily?: string;
}) {
	const now = Date.now();
	const parts = await readAll();
	const part: MyPart = {
		id: crypto.randomUUID(),
		name: name ?? `Part ${projectId.slice(0, 8)}`,
		category: pickCategoryFromDraft(summary),
		styleFamily,
		visibility: 'private',
		sourceProjectId: projectId,
		previewColorHex: pickColor(summary),
		polyCountEstimate: summary.dotCount * 16,
		createdAt: now,
		updatedAt: now
	};
	await writeAll([part, ...parts]);
	return part;
}

export async function updatePartVisibility(partId: string, visibility: MyPartVisibility) {
	const parts = await readAll();
	const next = parts.map((part) =>
		part.id === partId
			? {
					...part,
					visibility,
					updatedAt: Date.now()
				}
			: part
	);
	await writeAll(next);
	return next.find((part) => part.id === partId) ?? null;
}

function toSlug(name: string, id: string) {
	const base = name
		.toLowerCase()
		.replace(/[^a-z0-9\s-]/g, '')
		.trim()
		.replace(/\s+/g, '-')
		.slice(0, 32);
	return `${base || 'part'}-${id.slice(0, 8)}`;
}

export async function syncMyPartsToSupabase() {
	const supabase = getSupabaseClient();
	if (!supabase) return { synced: 0, skipped: true };

	const {
		data: { session }
	} = await supabase.auth.getSession();
	if (!session?.user?.id) return { synced: 0, skipped: true };

	const localParts = await readAll();
	if (localParts.length === 0) return { synced: 0, skipped: false };

	let synced = 0;
	for (const part of localParts) {
		const { error } = await supabase.from('parts').upsert(
			{
				id: part.id,
				owner_id: session.user.id,
				slug: toSlug(part.name, part.id),
				name: part.name,
				description: `Local synced part from ${part.sourceProjectId}`,
				source_type: 'user',
				visibility: part.visibility,
				style_family: part.styleFamily,
				mesh_path: `local://part/${part.id}`,
				tags: [part.category, part.styleFamily, 'local-sync'],
				poly_count: part.polyCountEstimate,
				allow_remix: true,
				is_active: true
			},
			{
				onConflict: 'id'
			}
		);
		if (!error) {
			synced += 1;
		}
	}

	return { synced, skipped: false };
}

export async function pullMyPartsFromSupabase() {
	const supabase = getSupabaseClient();
	if (!supabase) return { pulled: 0, skipped: true };

	const {
		data: { session }
	} = await supabase.auth.getSession();
	if (!session?.user?.id) return { pulled: 0, skipped: true };

	const { data, error } = await supabase
		.from('parts')
		.select('id, name, style_family, visibility, poly_count, updated_at, created_at')
		.eq('owner_id', session.user.id)
		.order('updated_at', { ascending: false })
		.limit(200);

	if (error || !data) return { pulled: 0, skipped: false };

	const existing = await readAll();
	const byId = new Map(existing.map((part) => [part.id, part]));

	for (const item of data) {
		const current = byId.get(item.id);
		byId.set(item.id, {
			id: item.id,
			name: item.name,
			category: current?.category ?? 'props',
			styleFamily: item.style_family ?? 'generic',
			visibility: (item.visibility as MyPartVisibility) ?? 'private',
			sourceProjectId: current?.sourceProjectId ?? 'remote-sync',
			previewColorHex: current?.previewColorHex ?? '#3b82f6',
			polyCountEstimate: item.poly_count ?? current?.polyCountEstimate ?? 0,
			createdAt: item.created_at ? new Date(item.created_at).getTime() : current?.createdAt ?? Date.now(),
			updatedAt: item.updated_at ? new Date(item.updated_at).getTime() : current?.updatedAt ?? Date.now()
		});
	}

	const merged = Array.from(byId.values()).sort((a, b) => b.updatedAt - a.updatedAt);
	await writeAll(merged);
	return { pulled: data.length, skipped: false };
}
