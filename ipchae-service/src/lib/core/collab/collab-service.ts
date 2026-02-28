import { createStore, get, set } from 'idb-keyval';
import { getSupabaseClient } from '$lib/core/supabase/client';

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

function isUuidLike(value: string) {
	return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
		value
	);
}

function parseRoleToken(roleToken: string): CollabRole {
	if (roleToken === 'owner' || roleToken === 'viewer') return roleToken;
	return 'editor';
}

export function parseInviteCode(inviteCode: string): { projectId: string; role: CollabRole } {
	const normalized = inviteCode.trim();
	if (!normalized) {
		return { projectId: 'unknown-project', role: 'editor' };
	}

	const colonTokens = normalized.split(':');
	if (colonTokens.length >= 2) {
		const roleToken = colonTokens[1]?.toLowerCase() ?? 'editor';
		return {
			projectId: colonTokens[0] || 'unknown-project',
			role: parseRoleToken(roleToken)
		};
	}

	const tokens = normalized.split('-');
	const lastToken = tokens[tokens.length - 1]?.toLowerCase() ?? '';
	if (tokens.length > 1 && (lastToken === 'owner' || lastToken === 'editor' || lastToken === 'viewer')) {
		return {
			projectId: tokens.slice(0, -1).join('-') || 'unknown-project',
			role: parseRoleToken(lastToken)
		};
	}

	return { projectId: normalized, role: 'editor' };
}

async function getLocalSession(sessionId: string) {
	const session = await get<CollabSession | undefined>(sessionKey(sessionId), store);
	return session ?? null;
}

async function saveLocalSession(session: CollabSession) {
	await set(sessionKey(session.sessionId), session, store);
}

async function tryJoinRemoteSession(inviteCode: string, userLabel: string): Promise<CollabSession | null> {
	const supabase = getSupabaseClient();
	if (!supabase) return null;
	const {
		data: { session: authSession }
	} = await supabase.auth.getSession();
	if (!authSession?.user?.id) return null;

	const inviteResp = await supabase
		.from('project_collab_invites')
		.select('project_id, default_role, max_editors, expires_at, is_active')
		.eq('invite_code', inviteCode)
		.eq('is_active', true)
		.maybeSingle();

	if (inviteResp.error || !inviteResp.data) {
		return null;
	}

	const invite = inviteResp.data;
	const inviteExpiresAt = new Date(invite.expires_at).getTime();
	if (Number.isFinite(inviteExpiresAt) && inviteExpiresAt <= Date.now()) {
		return null;
	}

	const role = (invite.default_role as CollabRole) ?? 'editor';
	const nowIso = new Date().toISOString();

	await supabase.from('project_collaborators').upsert(
		{
			project_id: invite.project_id,
			user_id: authSession.user.id,
			role,
			status: 'active',
			joined_at: nowIso
		},
		{
			onConflict: 'project_id,user_id'
		}
	);

	const sessionResp = await supabase
		.from('project_collab_sessions')
		.insert({
			project_id: invite.project_id,
			host_user_id: authSession.user.id,
			max_editors: invite.max_editors ?? 4
		})
		.select('id, project_id, started_at')
		.single();

	if (sessionResp.error || !sessionResp.data) {
		return null;
	}

	const startedAt = new Date(sessionResp.data.started_at).getTime();
	const collabSession: CollabSession = {
		sessionId: sessionResp.data.id,
		projectId: sessionResp.data.project_id,
		role,
		userLabel,
		joinedAt: startedAt,
		heartbeatAt: startedAt,
		locks: []
	};

	await saveLocalSession(collabSession);
	return collabSession;
}

export async function joinSession(inviteCode: string, userLabel: string): Promise<CollabSession> {
	const remote = await tryJoinRemoteSession(inviteCode, userLabel);
	if (remote) return remote;

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
	await saveLocalSession(session);
	return session;
}

async function pullRemoteLocks(session: CollabSession) {
	const supabase = getSupabaseClient();
	if (!supabase || !isUuidLike(session.sessionId)) return null;

	const locksResp = await supabase
		.from('project_mesh_locks')
		.select('id, mesh_node_id, owner_user_id, created_at, lease_expires_at, is_active')
		.eq('project_id', session.projectId)
		.eq('is_active', true);

	if (locksResp.error || !locksResp.data) return null;
	return locksResp.data.map((lock) => ({
		lockId: lock.id,
		meshNodeId: lock.mesh_node_id,
		ownerLabel: String(lock.owner_user_id).slice(0, 8),
		acquiredAt: new Date(lock.created_at).getTime(),
		expiresAt: new Date(lock.lease_expires_at).getTime()
	})) satisfies CollabLock[];
}

export async function getSession(sessionId: string): Promise<CollabSession | null> {
	const local = await getLocalSession(sessionId);
	if (!local) return null;
	const remoteLocks = await pullRemoteLocks(local);
	if (!remoteLocks) return local;
	const merged: CollabSession = {
		...local,
		locks: remoteLocks
	};
	await saveLocalSession(merged);
	return merged;
}

export async function heartbeatSession(sessionId: string): Promise<CollabSession | null> {
	const session = await getSession(sessionId);
	if (!session) return null;

	const nextSession: CollabSession = {
		...session,
		heartbeatAt: Date.now()
	};
	await saveLocalSession(nextSession);

	const supabase = getSupabaseClient();
	if (supabase && isUuidLike(session.sessionId)) {
		const {
			data: { session: authSession }
		} = await supabase.auth.getSession();
		if (authSession?.user?.id) {
			await supabase.from('project_presence').upsert(
				{
					session_id: session.sessionId,
					project_id: session.projectId,
					user_id: authSession.user.id,
					cursor_world: {},
					camera_state: {},
					heartbeat_at: new Date().toISOString()
				},
				{
					onConflict: 'session_id,user_id'
				}
			);
		}
	}

	return nextSession;
}

async function tryAcquireRemoteLock(session: CollabSession, meshNodeId: string): Promise<CollabLock | null> {
	const supabase = getSupabaseClient();
	if (!supabase || !isUuidLike(session.sessionId)) return null;

	const {
		data: { session: authSession }
	} = await supabase.auth.getSession();
	if (!authSession?.user?.id) return null;

	const now = Date.now();
	const nowIso = new Date(now).toISOString();

	const heldResp = await supabase
		.from('project_mesh_locks')
		.select('id, owner_user_id, lease_expires_at, is_active')
		.eq('project_id', session.projectId)
		.eq('mesh_node_id', meshNodeId)
		.eq('is_active', true)
		.order('created_at', { ascending: false })
		.limit(1)
		.maybeSingle();

	if (!heldResp.error && heldResp.data) {
		const expiresAt = new Date(heldResp.data.lease_expires_at).getTime();
		if (heldResp.data.owner_user_id !== authSession.user.id && expiresAt > now) {
			throw new Error('LOCK_HELD_BY_OTHER');
		}
	}

	const lockResp = await supabase
		.from('project_mesh_locks')
		.insert({
			project_id: session.projectId,
			session_id: session.sessionId,
			mesh_node_id: meshNodeId,
			lock_scope: 'node',
			owner_user_id: authSession.user.id,
			lease_expires_at: new Date(now + 20000).toISOString(),
			is_active: true
		})
		.select('id, owner_user_id, created_at, lease_expires_at')
		.single();

	if (lockResp.error || !lockResp.data) {
		return null;
	}

	return {
		lockId: lockResp.data.id,
		meshNodeId,
		ownerLabel: String(lockResp.data.owner_user_id).slice(0, 8),
		acquiredAt: new Date(lockResp.data.created_at).getTime(),
		expiresAt: new Date(lockResp.data.lease_expires_at).getTime()
	};
}

export async function acquireLock(
	sessionId: string,
	meshNodeId: string,
	userLabel: string
): Promise<CollabSession> {
	const session = await getSession(sessionId);
	if (!session) throw new Error('SESSION_NOT_FOUND');

	const remoteLock = await tryAcquireRemoteLock(session, meshNodeId);
	if (remoteLock) {
		const nextSession: CollabSession = {
			...session,
			locks: [remoteLock, ...session.locks.filter((item) => item.meshNodeId !== meshNodeId)]
		};
		await saveLocalSession(nextSession);
		return nextSession;
	}

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
	const nextSession: CollabSession = {
		...session,
		locks: [lock, ...session.locks.filter((item) => item.meshNodeId !== meshNodeId)]
	};
	await saveLocalSession(nextSession);
	return nextSession;
}

export async function releaseLock(sessionId: string, lockId: string): Promise<CollabSession | null> {
	const session = await getSession(sessionId);
	if (!session) return null;

	const supabase = getSupabaseClient();
	if (supabase && isUuidLike(lockId)) {
		await supabase
			.from('project_mesh_locks')
			.update({
				is_active: false,
				released_at: new Date().toISOString(),
				release_reason: 'manual'
			})
			.eq('id', lockId);
	}

	const nextSession: CollabSession = {
		...session,
		locks: session.locks.filter((lock) => lock.lockId !== lockId)
	};
	await saveLocalSession(nextSession);
	return nextSession;
}
