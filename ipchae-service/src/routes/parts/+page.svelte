<script lang="ts">
	import { onMount } from 'svelte';
	import {
		filterCatalogParts,
		loadStarterCatalog,
		type StarterCatalog,
		type StarterPart,
		type StarterStyle
	} from '$lib/core/catalog/starter-catalog';
	import {
		listMyParts,
		updatePartVisibility,
		type MyPart,
		type MyPartVisibility
	} from '$lib/core/parts/my-part-store';

	const categories: Array<StarterPart['category'] | 'all'> = [
		'all',
		'head',
		'face',
		'hair',
		'outfit',
		'hand',
		'foot',
		'props',
		'voxel'
	];
	const styles: Array<StarterStyle | 'all'> = [
		'all',
		'nendo',
		'moe',
		'minecraft',
		'roblox',
		'anime',
		'animal',
		'robot',
		'fantasy'
	];
	const difficulties: Array<StarterPart['difficulty'] | 'all'> = ['all', 'easy', 'normal', 'advanced'];

	let catalog: StarterCatalog | null = null;
	let search = '';
	let category: StarterPart['category'] | 'all' = 'all';
	let styleFamily: StarterStyle | 'all' = 'all';
	let difficulty: StarterPart['difficulty'] | 'all' = 'all';
	let myParts: MyPart[] = [];
	let myPartStatus = '';

	onMount(async () => {
		const [nextCatalog, nextMyParts] = await Promise.all([loadStarterCatalog(), listMyParts()]);
		catalog = nextCatalog;
		myParts = nextMyParts;
	});

	$: filteredParts = catalog
		? filterCatalogParts(catalog.parts, {
				search,
				category,
				styleFamily,
				difficulty
			})
		: [];

	async function changeVisibility(partId: string, visibility: MyPartVisibility) {
		const next = await updatePartVisibility(partId, visibility);
		myPartStatus = next ? `${next.name} -> ${visibility}` : 'part not found';
		myParts = await listMyParts();
	}
</script>

<main class="parts-shell">
	<header class="parts-header">
		<div>
			<p class="eyebrow">Parts Browser</p>
			<h1>공식/Starter 파츠 탐색</h1>
		</div>
		{#if catalog}
			<span class="source-pill">source: {catalog.source}</span>
		{/if}
	</header>

	<section class="filter-grid">
		<label for="parts-search">
			<span>Search</span>
			<input id="parts-search" type="search" bind:value={search} placeholder="name or tag" />
		</label>
		<label for="parts-category">
			<span>Category</span>
			<select id="parts-category" bind:value={category}>
				{#each categories as item}
					<option value={item}>{item}</option>
				{/each}
			</select>
		</label>
		<label for="parts-style">
			<span>Style</span>
			<select id="parts-style" bind:value={styleFamily}>
				{#each styles as item}
					<option value={item}>{item}</option>
				{/each}
			</select>
		</label>
		<label for="parts-difficulty">
			<span>Difficulty</span>
			<select id="parts-difficulty" bind:value={difficulty}>
				{#each difficulties as item}
					<option value={item}>{item}</option>
				{/each}
			</select>
		</label>
	</section>

	<section class="parts-grid">
		{#if !catalog}
			<p>카탈로그 로딩 중...</p>
		{:else if filteredParts.length === 0}
			<p>조건에 맞는 파츠가 없습니다.</p>
		{:else}
			{#each filteredParts as part}
				<article class="part-card">
					<p class="part-title">{part.name}</p>
					<p class="part-meta">{part.category} · {part.styleFamily} · {part.difficulty}</p>
					<p class="part-tags">{part.tags.join(', ')}</p>
					<button type="button">Apply (Next)</button>
				</article>
			{/each}
		{/if}
	</section>

	<section class="my-parts">
		<h2>My Parts</h2>
		{#if myPartStatus}
			<p class="my-part-status">{myPartStatus}</p>
		{/if}
		{#if myParts.length === 0}
			<p>저장된 내 파츠가 없습니다. Studio에서 `Save Part`를 실행해 주세요.</p>
		{:else}
			<div class="parts-grid">
				{#each myParts as part}
					<article class="part-card">
						<p class="part-title">{part.name}</p>
						<p class="part-meta">{part.category} · {part.styleFamily} · {part.visibility}</p>
						<p class="part-tags">poly≈{part.polyCountEstimate} · {new Date(part.updatedAt).toLocaleString()}</p>
						<div class="publish-row">
							<button type="button" on:click={() => changeVisibility(part.id, 'private')}>Private</button>
							<button type="button" on:click={() => changeVisibility(part.id, 'unlisted')}>Unlisted</button>
							<button type="button" on:click={() => changeVisibility(part.id, 'public')}>Public</button>
						</div>
					</article>
				{/each}
			</div>
		{/if}
	</section>
</main>

<style>
	.parts-shell {
		max-width: 1120px;
		margin: 0 auto;
		padding: 40px 24px 60px;
		display: grid;
		gap: 18px;
	}

	.parts-header {
		display: flex;
		justify-content: space-between;
		align-items: flex-end;
		gap: 12px;
	}

	.parts-header h1 {
		margin: 0;
		font-size: clamp(1.5rem, 3vw, 2rem);
	}

	.source-pill {
		padding: 4px 10px;
		border-radius: 999px;
		background: #dbeafe;
		color: #1d4ed8;
		font-size: 0.8rem;
		font-weight: 700;
	}

	.filter-grid {
		display: grid;
		grid-template-columns: repeat(4, minmax(0, 1fr));
		gap: 10px;
	}

	label {
		display: grid;
		gap: 6px;
		font-size: 0.86rem;
		color: #334155;
	}

	input,
	select {
		height: 36px;
		border: 1px solid #cbd5e1;
		border-radius: 8px;
		padding: 0 10px;
		background: #ffffff;
	}

	.parts-grid {
		display: grid;
		grid-template-columns: repeat(4, minmax(0, 1fr));
		gap: 10px;
	}

	.part-card {
		padding: 12px;
		border: 1px solid #dbe2f2;
		border-radius: 10px;
		background: #ffffff;
		display: grid;
		gap: 8px;
	}

	.part-title {
		margin: 0;
		font-weight: 700;
	}

	.part-meta,
	.part-tags {
		margin: 0;
		font-size: 0.8rem;
		color: #475569;
	}

	.part-card button {
		height: 32px;
		border: 1px solid #2563eb;
		border-radius: 8px;
		background: #2563eb;
		color: #ffffff;
		font-weight: 700;
		cursor: pointer;
	}

	.my-parts {
		display: grid;
		gap: 10px;
	}

	.my-parts h2 {
		margin: 0;
	}

	.my-part-status {
		margin: 0;
		color: #1d4ed8;
		font-weight: 700;
	}

	.publish-row {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: 6px;
	}

	.publish-row button {
		height: 30px;
		font-size: 0.75rem;
	}

	@media (max-width: 960px) {
		.filter-grid {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}

		.parts-grid {
			grid-template-columns: repeat(2, minmax(0, 1fr));
		}
	}

	@media (max-width: 640px) {
		.filter-grid,
		.parts-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
