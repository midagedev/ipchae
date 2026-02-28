import { createStore, get, set } from 'idb-keyval';

export type CollabRole = 'owner' | 'editor' | 'viewer';

export type CollabLock = {
	lockId: string;
	meshNodeId: string;
	ownerLabel: string;
	acquiredAt: number;
	expiresAt: number;
};

export type CollabSession = {
	sessionId: string;
	projectId: string;
	role: CollabRole;
	userLabel: string;
	joinedAt: number;
	heartbeatAt: number;
	locks: CollabLock[];
};

const store = createStore('ipchae-local', 'collab');

function sessionKey(sessionId: string) {
	return `session:${sessionId}`;
}

export function parseInviteCode(inviteCode: string): { projectId: string; role: CollabRole } {
	const [projectId = 'unknown-project', roleToken = 'editor'] = inviteCode.split('-');
	const role: CollabRole =
		roleToken === 'owner' || roleToken === 'viewer' ? roleToken : 'editor';
	return { projectId, role };
}

export async function joinSession(inviteCode: string, userLabel: string): Promise<CollabSession> {
	const { projectId, role } = parseInviteCode(inviteCode);
	const sessionId = `session-${projectId}-${role}`;
	const now = Date.now();
	const session: CollabSession = {
		sessionId,
		projectId,
		role,
		userLabel,
		joinedAt: now,
		heartbeatAt: now,
		locks: []
	};
	await set(sessionKey(sessionId), session, store);
	return session;
}

export async function getSession(sessionId: string): Promise<CollabSession | null> {
	const session = await get<CollabSession | undefined>(sessionKey(sessionId), store);
	return session ?? null;
}

export async function heartbeatSession(sessionId: string): Promise<CollabSession | null> {
	const session = await getSession(sessionId);
	if (!session) return null;
	const nextSession: CollabSession = {
		...session,
		heartbeatAt: Date.now()
	};
	await set(sessionKey(sessionId), nextSession, store);
	return nextSession;
}

export async function acquireLock(
	sessionId: string,
	meshNodeId: string,
	userLabel: string
): Promise<CollabSession> {
	const session = await getSession(sessionId);
	if (!session) throw new Error('SESSION_NOT_FOUND');
	const lockHeldByOther = session.locks.find((lock) => lock.meshNodeId === meshNodeId);
	if (lockHeldByOther && lockHeldByOther.ownerLabel !== userLabel) {
		throw new Error('LOCK_HELD_BY_OTHER');
	}
	const now = Date.now();
	const lock: CollabLock = {
		lockId: `lock-${meshNodeId}-${now}`,
		meshNodeId,
		ownerLabel: userLabel,
		acquiredAt: now,
		expiresAt: now + 20000
	};
	const nextLocks = [
		lock,
		...session.locks.filter((item) => item.meshNodeId !== meshNodeId)
	];
	const nextSession: CollabSession = {
		...session,
		locks: nextLocks
	};
	await set(sessionKey(sessionId), nextSession, store);
	return nextSession;
}

export async function releaseLock(sessionId: string, lockId: string): Promise<CollabSession | null> {
	const session = await getSession(sessionId);
	if (!session) return null;
	const nextSession: CollabSession = {
		...session,
		locks: session.locks.filter((lock) => lock.lockId !== lockId)
	};
	await set(sessionKey(sessionId), nextSession, store);
	return nextSession;
}

