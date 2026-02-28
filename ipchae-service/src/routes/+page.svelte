<script lang="ts">
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import { onMount } from 'svelte';
	import { loadStarterCatalog, type StarterCatalog } from '$lib/core/catalog/starter-catalog';
	import { getRecentProjects } from '$lib/core/persistence/project-snapshot-store';

	type StartMode = 'blank' | 'free-draw' | 'starter';
	type RecentProject = { projectId: string; updatedAt: number };

	const quickStartCards: Array<{ mode: StartMode; title: string; description: string }> = [
		{
			mode: 'blank',
			title: 'Blank',
			description: '아무 것도 없는 씬에서 바로 시작'
		},
		{
			mode: 'free-draw',
			title: 'Free Draw First',
			description: '3D 펜처럼 선부터 그리며 형태 만들기'
		},
		{
			mode: 'starter',
			title: 'Starter Scaffold',
			description: '기본 템플릿 위에서 빠르게 캐릭터 시작'
		}
	];

	const coreGoals = [
		'60초 안에 캐릭터 베이스 만들기',
		'10분 안에 첫 Export 도달하기',
		'Draw -> Build -> Polish 루프를 직관적으로 완주하기'
	];
	let recentProjects: RecentProject[] = [];
	let starterCatalog: StarterCatalog | null = null;

	onMount(async () => {
		const [recents, catalog] = await Promise.all([getRecentProjects(), loadStarterCatalog()]);
		recentProjects = recents;
		starterCatalog = catalog;
	});

	async function startProject(mode: StartMode) {
		const projectId = crypto.randomUUID();
		await goto(`${base}/studio/${projectId}?mode=${mode}`);
	}

	async function openProject(projectId: string) {
		await goto(`${base}/studio/${projectId}`);
	}
</script>

<main class="home-shell">
	<section class="hero">
		<p class="eyebrow">IPCHAE Core MVP</p>
		<h1>쉽게 시작하고 끝까지 완주하는 3D 모델링</h1>
		<p class="lead">
			이번 MVP는 공유/협업보다 먼저, 첫 사용자도 막히지 않고 캐릭터를 완성하도록 만드는 데 집중합니다.
		</p>
	</section>

	<section class="quick-start">
		<h2>Quick Start</h2>
		<div class="card-grid">
			{#each quickStartCards as card}
				<button class="start-card" type="button" on:click={() => startProject(card.mode)}>
					<span class="card-title">{card.title}</span>
					<span class="card-desc">{card.description}</span>
					<span class="card-action">바로 시작</span>
				</button>
			{/each}
		</div>
	</section>

	<section class="focus">
		<h2>이번 스프린트 목표</h2>
		<ul>
			{#each coreGoals as goal}
				<li>{goal}</li>
			{/each}
		</ul>
	</section>

	<section class="focus">
		<h2>Starter Catalog</h2>
		{#if starterCatalog}
			<ul>
				<li>Source: {starterCatalog.source}</li>
				<li>Packs: {starterCatalog.packs.length}</li>
				<li>Templates: {starterCatalog.templates.length}</li>
				<li>Official Parts: {starterCatalog.parts.length}</li>
			</ul>
		{:else}
			<p>카탈로그 로딩 중...</p>
		{/if}
	</section>

	<section class="focus">
		<h2>Service Tracks</h2>
		<div class="card-grid">
			<a class="start-card" href={`${base}/parts`}>
				<span class="card-title">Parts</span>
				<span class="card-desc">브라우저/저장/게시 흐름</span>
			</a>
			<a class="start-card" href={`${base}/account`}>
				<span class="card-title">Account</span>
				<span class="card-desc">동기화/레벨/업적</span>
			</a>
			<a class="start-card" href={`${base}/help`}>
				<span class="card-title">Help</span>
				<span class="card-desc">가이드/FAQ/문제해결</span>
			</a>
			<a class="start-card" href={`${base}/share/demo-hero-robot`}>
				<span class="card-title">Share Demo</span>
				<span class="card-desc">프로젝트 공유 CTA 테스트</span>
			</a>
			<a class="start-card" href={`${base}/part/demo-part-hair-01`}>
				<span class="card-title">Part Demo</span>
				<span class="card-desc">파츠 공유 import 테스트</span>
			</a>
			<a class="start-card" href={`${base}/collab/demo-project-editor`}>
				<span class="card-title">Collab Demo</span>
				<span class="card-desc">invite/lock 시뮬레이터</span>
			</a>
		</div>
	</section>

	<section class="focus">
		<h2>Recent Projects</h2>
		{#if recentProjects.length === 0}
			<p>아직 저장된 로컬 프로젝트가 없습니다.</p>
		{:else}
			<div class="card-grid">
				{#each recentProjects.slice(0, 6) as item}
					<button class="start-card" type="button" on:click={() => openProject(item.projectId)}>
						<span class="card-title">Project {item.projectId.slice(0, 8)}</span>
						<span class="card-desc">{new Date(item.updatedAt).toLocaleString()}</span>
						<span class="card-action">열기</span>
					</button>
				{/each}
			</div>
		{/if}
	</section>
</main>
