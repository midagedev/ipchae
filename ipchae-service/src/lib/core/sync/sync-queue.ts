export type SyncStatus = 'local' | 'syncing' | 'synced' | 'failed';

type QueueJob<T> = {
	id: string;
	payload: T;
	retry: number;
};

type PushHandler<T> = (payload: T) => Promise<void>;

export function createSyncQueue<T>(pushHandler: PushHandler<T>) {
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
		queue.push({
			id: `sync-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`,
			payload,
			retry: 0
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

