<script lang="ts">
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import { page } from '$app/state';
	import { onMount } from 'svelte';
	import {
		cloneProjectFromShare,
		loadProjectShare,
		type ProjectShareView
	} from '$lib/core/share/share-service';

	let share: ProjectShareView | null = null;
	let loading = true;
	let errorMessage = '';

	onMount(async () => {
		const slug = page.params.shareSlug ?? '';
		share = await loadProjectShare(slug);
		loading = false;
	});

	async function cloneAndEdit() {
		if (!share) return;
		try {
			const projectId = await cloneProjectFromShare(share);
			await goto(`${base}/studio/${projectId}?mode=starter`);
		} catch (error) {
			errorMessage = error instanceof Error ? error.message : 'Clone failed';
		}
	}
</script>

<main class="share-shell">
	{#if loading}
		<p>로딩 중...</p>
	{:else if !share}
		<h1>공유 항목을 찾을 수 없습니다.</h1>
	{:else}
		<section class="share-card">
			<p class="eyebrow">Project Share</p>
			<h1>{share.title}</h1>
			<p class="desc">{share.description}</p>
			<p class="meta">by {share.ownerName} · {share.visibility}</p>
			<div class="cta-row">
				<button type="button" class="primary" on:click={cloneAndEdit}>이걸 이용해서 고쳐보시겠어요?</button>
				<a class="ghost" href={`${base}/`}>입채로 새로 만들기</a>
			</div>
			{#if errorMessage}
				<p class="error">{errorMessage}</p>
			{/if}
		</section>
	{/if}
</main>

<style>
	.share-shell {
		max-width: 860px;
		margin: 0 auto;
		padding: 56px 24px;
	}

	.share-card {
		padding: 24px;
		border: 1px solid #dbe2f2;
		border-radius: 14px;
		background: #ffffff;
		display: grid;
		gap: 12px;
	}

	h1 {
		margin: 0;
	}

	.desc,
	.meta {
		margin: 0;
		color: #475569;
	}

	.cta-row {
		display: flex;
		gap: 10px;
		flex-wrap: wrap;
	}

	.primary,
	.ghost {
		height: 38px;
		padding: 0 14px;
		border-radius: 10px;
		font-weight: 700;
		text-decoration: none;
		display: inline-flex;
		align-items: center;
	}

	.primary {
		border: 1px solid #2563eb;
		background: #2563eb;
		color: #ffffff;
		cursor: pointer;
	}

	.ghost {
		border: 1px solid #cbd5e1;
		color: #334155;
	}

	.error {
		margin: 0;
		color: #dc2626;
		font-weight: 700;
	}
</style>

