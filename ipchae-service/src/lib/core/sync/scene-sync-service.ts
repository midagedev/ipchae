import { writable } from 'svelte/store';
import type { StudioSnapshotV1 } from '$lib/core/contracts/studio';
import { getSupabaseClient } from '$lib/core/supabase/client';
import { createSyncQueue, type SyncStatus } from '$lib/core/sync/sync-queue';

export const studioSyncStatus = writable<SyncStatus>('local');
export const studioLastSyncedAt = writable<number | null>(null);

const queue = createSyncQueue<StudioSnapshotV1>(async (snapshot) => {
	const supabase = getSupabaseClient();
	if (!supabase) return;

	const {
		data: { session }
	} = await supabase.auth.getSession();

	if (!session?.user?.id) return;
	studioSyncStatus.set('syncing');

	const nowIso = new Date().toISOString();
	const projectName = `Project ${snapshot.projectId.slice(0, 8)}`;

	const { error } = await supabase.from('projects').upsert(
		{
			id: snapshot.projectId,
			owner_id: session.user.id,
			name: projectName,
			updated_at: nowIso
		},
		{
			onConflict: 'id'
		}
	);

	if (error) {
		studioSyncStatus.set('failed');
		throw error;
	}

	studioLastSyncedAt.set(Date.now());
	studioSyncStatus.set('synced');
}, {
	coalesceKey: (snapshot) => snapshot.projectId
});

export function enqueueStudioSnapshotSync(snapshot: StudioSnapshotV1) {
	queue.enqueue(snapshot);
}

export function getPendingSyncCount() {
	return queue.size();
}
