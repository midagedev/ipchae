import { createStore, get, set } from 'idb-keyval';
import type { StudioSnapshotV1 } from '$lib/core/contracts/studio';

const DB_NAME = 'ipchae-local';
const STORE_NAME = 'studio-snapshots';
const RECENTS_KEY = 'recent-projects';
const MAX_RECENTS = 24;

const store = createStore(DB_NAME, STORE_NAME);

function projectKey(projectId: string) {
	return `studio:${projectId}`;
}

type RecentProjects = Array<{ projectId: string; updatedAt: number }>;

export async function saveStudioSnapshot(snapshot: StudioSnapshotV1): Promise<void> {
	const nextSnapshot = {
		...snapshot,
		updatedAt: Date.now()
	} satisfies StudioSnapshotV1;

	await set(projectKey(snapshot.projectId), nextSnapshot, store);

	const recents = await getRecentProjects();
	const deduped = recents.filter((item) => item.projectId !== snapshot.projectId);
	const nextRecents: RecentProjects = [
		{ projectId: snapshot.projectId, updatedAt: nextSnapshot.updatedAt },
		...deduped
	].slice(0, MAX_RECENTS);

	await set(RECENTS_KEY, nextRecents, store);
}

export async function loadStudioSnapshot(projectId: string): Promise<StudioSnapshotV1 | null> {
	const snapshot = await get<StudioSnapshotV1 | undefined>(projectKey(projectId), store);
	if (!snapshot || snapshot.schemaVersion !== 1) return null;
	return snapshot;
}

export async function getRecentProjects(): Promise<RecentProjects> {
	const recents = await get<RecentProjects | undefined>(RECENTS_KEY, store);
	if (!recents) return [];
	return recents.sort((a, b) => b.updatedAt - a.updatedAt);
}
