<script lang="ts">
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import { page } from '$app/state';
	import { onMount } from 'svelte';
	import {
		importPartFromShare,
		loadPartShare,
		type PartShareView
	} from '$lib/core/share/share-service';

	let share: PartShareView | null = null;
	let loading = true;
	let errorMessage = '';

	onMount(async () => {
		const slug = page.params.partShareSlug ?? '';
		share = await loadPartShare(slug);
		loading = false;
	});

	async function importAndEdit() {
		if (!share) return;
		try {
			const projectId = await importPartFromShare(share);
			await goto(`${base}/studio/${projectId}?mode=starter`);
		} catch (error) {
			errorMessage = error instanceof Error ? error.message : 'Import failed';
		}
	}
</script>

<main class="share-shell">
	{#if loading}
		<p>로딩 중...</p>
	{:else if !share}
		<h1>파츠 공유 항목을 찾을 수 없습니다.</h1>
	{:else}
		<section class="share-card">
			<p class="eyebrow">Part Share</p>
			<h1>{share.partName}</h1>
			<p class="desc">{share.category} · {share.styleFamily}</p>
			<p class="meta">by {share.ownerName}</p>
			<div class="cta-row">
				<button type="button" class="primary" on:click={importAndEdit}>이걸 이용해서 고쳐보시겠어요?</button>
				<a class="ghost" href={`${base}/parts`}>내 파츠로 저장 (Next)</a>
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

