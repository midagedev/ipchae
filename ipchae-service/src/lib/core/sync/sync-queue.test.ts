import { describe, expect, it, vi } from 'vitest';
import { createSyncQueue } from '$lib/core/sync/sync-queue';

describe('sync queue', () => {
	it('flushes queued payloads in order', async () => {
		const pushed: string[] = [];
		const queue = createSyncQueue<string>(async (payload) => {
			pushed.push(payload);
		});

		queue.enqueue('a');
		queue.enqueue('b');

		await vi.waitFor(() => {
			expect(pushed).toEqual(['a', 'b']);
		});
	});

	it('coalesces pending payloads by key', async () => {
		const pushed: Array<{ projectId: string; seq: number }> = [];
		const queue = createSyncQueue<{ projectId: string; seq: number }>(
			async (payload) => {
				await new Promise((resolve) => setTimeout(resolve, 20));
				pushed.push(payload);
			},
			{
				coalesceKey: (payload) => payload.projectId
			}
		);

		queue.enqueue({ projectId: 'project-1', seq: 1 });
		queue.enqueue({ projectId: 'project-1', seq: 2 });
		queue.enqueue({ projectId: 'project-1', seq: 3 });

		await vi.waitFor(() => {
			expect(pushed).toEqual([
				{ projectId: 'project-1', seq: 1 },
				{ projectId: 'project-1', seq: 3 }
			]);
		});
	});
});
