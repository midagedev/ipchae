<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/state';
	import {
		acquireLock,
		heartbeatSession,
		joinSession,
		releaseLock,
		type CollabSession
	} from '$lib/core/collab/collab-service';

	let userLabel = 'editor-guest';
	let meshNodeId = 'mesh-node-1';
	let session: CollabSession | null = null;
	let statusMessage = '';

	onMount(async () => {
		const inviteCode = page.params.inviteCode ?? '';
		session = await joinSession(inviteCode, userLabel);
		statusMessage = `joined ${session.sessionId}`;
	});

	async function heartbeat() {
		if (!session) return;
		session = await heartbeatSession(session.sessionId);
		statusMessage = 'heartbeat sent';
	}

	async function requestLock() {
		if (!session) return;
		try {
			session = await acquireLock(session.sessionId, meshNodeId, userLabel);
			statusMessage = `lock acquired for ${meshNodeId}`;
		} catch (error) {
			statusMessage = error instanceof Error ? error.message : 'lock failed';
		}
	}

	async function unlock(lockId: string) {
		if (!session) return;
		session = await releaseLock(session.sessionId, lockId);
		statusMessage = `lock released ${lockId}`;
	}
</script>

<main class="collab-shell">
	<section class="card">
		<p class="eyebrow">Collaboration</p>
		<h1>Invite: {page.params.inviteCode}</h1>
		<p>{statusMessage}</p>
		<div class="controls">
			<input bind:value={userLabel} placeholder="user label" />
			<input bind:value={meshNodeId} placeholder="mesh node id" />
			<button type="button" on:click={heartbeat}>Heartbeat</button>
			<button type="button" on:click={requestLock}>Acquire Lock</button>
		</div>
	</section>

	<section class="card">
		<h2>Session State</h2>
		{#if !session}
			<p>세션 없음</p>
		{:else}
			<p>Session: {session.sessionId}</p>
			<p>Project: {session.projectId}</p>
			<p>Role: {session.role}</p>
			<p>Heartbeat: {new Date(session.heartbeatAt).toLocaleTimeString()}</p>

			<h3>Locks</h3>
			{#if session.locks.length === 0}
				<p>잠금 없음</p>
			{:else}
				<ul>
					{#each session.locks as lock}
						<li>
							{lock.meshNodeId} · {lock.ownerLabel}
							<button type="button" on:click={() => unlock(lock.lockId)}>release</button>
						</li>
					{/each}
				</ul>
			{/if}
		{/if}
	</section>
</main>

<style>
	.collab-shell {
		max-width: 920px;
		margin: 0 auto;
		padding: 40px 24px 64px;
		display: grid;
		gap: 12px;
	}

	.card {
		border: 1px solid #dbe2f2;
		border-radius: 12px;
		background: #ffffff;
		padding: 16px;
		display: grid;
		gap: 8px;
	}

	h1,
	h2,
	h3,
	p {
		margin: 0;
	}

	.controls {
		display: grid;
		grid-template-columns: repeat(4, minmax(0, 1fr));
		gap: 8px;
	}

	input {
		height: 36px;
		border: 1px solid #cbd5e1;
		border-radius: 8px;
		padding: 0 10px;
	}

	button {
		height: 36px;
		border: 1px solid #2563eb;
		border-radius: 8px;
		background: #2563eb;
		color: #ffffff;
		font-weight: 700;
		cursor: pointer;
		padding: 0 10px;
	}

	ul {
		margin: 0;
		padding-left: 18px;
	}

	li {
		display: flex;
		align-items: center;
		gap: 6px;
	}

	li button {
		height: 24px;
		font-size: 0.75rem;
	}

	@media (max-width: 840px) {
		.controls {
			grid-template-columns: 1fr;
		}
	}
</style>

