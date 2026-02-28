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
});

