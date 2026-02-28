<script lang="ts">
	import { goto } from '$app/navigation';

	type StartMode = 'blank' | 'free-draw' | 'starter';

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

	async function startProject(mode: StartMode) {
		const projectId = crypto.randomUUID();
		await goto(`/studio/${projectId}?mode=${mode}`);
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
</main>
