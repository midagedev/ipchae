<script lang="ts">
	import { onMount } from 'svelte';
	import {
		authState,
		hydrateAuthState,
		signInWithOtp,
		signOutSupabase
	} from '$lib/core/supabase/auth-store';
	import {
		gamificationAchievements,
		gamificationProfile,
		gamificationXpEvents,
		hydrateGamification
	} from '$lib/core/gamification/gamification-store';
	import { getPendingSyncCount, studioSyncStatus } from '$lib/core/sync/scene-sync-service';

	let email = '';
	let authMessage = '';
	let pendingSync = 0;

	onMount(async () => {
		await Promise.all([hydrateAuthState(), hydrateGamification()]);
		pendingSync = getPendingSyncCount();
	});

	async function requestOtp() {
		authMessage = '';
		try {
			await signInWithOtp(email);
			authMessage = 'OTP 메일을 전송했습니다.';
		} catch (error) {
			authMessage = error instanceof Error ? error.message : 'OTP 전송 실패';
		}
	}
</script>

<main class="account-shell">
	<section class="card">
		<p class="eyebrow">Account</p>
		<h1>Sync & Auth</h1>
		<p>Sync Status: {$studioSyncStatus} · Pending Queue: {pendingSync}</p>

		{#if $authState.status === 'authenticated'}
			<p>Logged in as {$authState.email} ({$authState.userId})</p>
			<button type="button" on:click={signOutSupabase}>Sign Out</button>
		{:else if $authState.status === 'anonymous'}
			<div class="otp-row">
				<input type="email" bind:value={email} placeholder="email@domain.com" />
				<button type="button" on:click={requestOtp}>Send OTP</button>
			</div>
			{#if authMessage}
				<p>{authMessage}</p>
			{/if}
		{:else}
			<p>Supabase 환경변수가 설정되지 않았습니다. `.env`를 확인하세요.</p>
		{/if}
	</section>

	<section class="card">
		<p class="eyebrow">Gamification</p>
		<h2>Level {$gamificationProfile.level}</h2>
		<p>Total XP {$gamificationProfile.totalXp}</p>
		<p>
			Progress {$gamificationProfile.currentLevelXp}/{$gamificationProfile.nextLevelXp}
		</p>
	</section>

	<section class="card">
		<h2>Achievements</h2>
		<div class="grid">
			{#each $gamificationAchievements as achievement}
				<article class="achievement {achievement.isUnlocked ? 'unlocked' : ''}">
					<p>{achievement.name}</p>
					<p>{achievement.progressValue}/{achievement.thresholdValue}</p>
				</article>
			{/each}
		</div>
	</section>

	<section class="card">
		<h2>Recent XP Events</h2>
		<ul>
			{#if $gamificationXpEvents.length === 0}
				<li>No events yet.</li>
			{:else}
				{#each $gamificationXpEvents.slice(0, 12) as xpEvent}
					<li>
						{new Date(xpEvent.createdAt).toLocaleString()} · {xpEvent.sourceType} · +{xpEvent.xpDelta}
					</li>
				{/each}
			{/if}
		</ul>
	</section>
</main>

<style>
	.account-shell {
		max-width: 980px;
		margin: 0 auto;
		padding: 40px 24px 64px;
		display: grid;
		gap: 14px;
	}

	.card {
		background: #ffffff;
		border: 1px solid #dbe2f2;
		border-radius: 12px;
		padding: 16px;
		display: grid;
		gap: 8px;
	}

	.card h1,
	.card h2 {
		margin: 0;
	}

	.otp-row {
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
	}

	.otp-row input {
		height: 36px;
		min-width: 260px;
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
		padding: 0 12px;
		cursor: pointer;
	}

	.grid {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: 8px;
	}

	.achievement {
		padding: 10px;
		border: 1px solid #cbd5e1;
		border-radius: 8px;
	}

	.achievement.unlocked {
		border-color: #22c55e;
		background: #f0fdf4;
	}

	.achievement p {
		margin: 0;
	}

	ul {
		margin: 0;
		padding-left: 18px;
	}

	@media (max-width: 760px) {
		.grid {
			grid-template-columns: 1fr;
		}
	}
</style>

