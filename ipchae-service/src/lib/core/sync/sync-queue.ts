export type SyncStatus = 'local' | 'syncing' | 'synced' | 'failed';

type QueueJob<T> = {
	id: string;
	payload: T;
	retry: number;
	coalesceKey: string | null;
};

type PushHandler<T> = (payload: T) => Promise<void>;

export function createSyncQueue<T>(
	pushHandler: PushHandler<T>,
	{
		coalesceKey
	}: {
		coalesceKey?: (payload: T) => string | null;
	} = {}
) {
	const queue: QueueJob<T>[] = [];
	let flushing = false;

	async function flush() {
		if (flushing) return;
		flushing = true;

		try {
			while (queue.length > 0) {
				const current = queue[0];
				try {
					await pushHandler(current.payload);
					queue.shift();
				} catch (error) {
					current.retry += 1;
					const delayMs = Math.min(15000, 1000 * 2 ** (current.retry - 1));
					await new Promise((resolve) => setTimeout(resolve, delayMs));
				}
			}
		} finally {
			flushing = false;
		}
	}

	function enqueue(payload: T) {
		const candidateKey = coalesceKey?.(payload) ?? null;
		if (candidateKey) {
			const startIndex = flushing ? 1 : 0;
			const existingIndex = queue.findIndex(
				(job, index) => index >= startIndex && job.coalesceKey === candidateKey
			);
			if (existingIndex >= 0) {
				const existing = queue[existingIndex];
				queue[existingIndex] = {
					...existing,
					payload
				};
				return;
			}
		}

		queue.push({
			id: `sync-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`,
			payload,
			retry: 0,
			coalesceKey: candidateKey
		});
		void flush();
	}

	function size() {
		return queue.length;
	}

	return {
		enqueue,
		size
	};
}
