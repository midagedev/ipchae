<script lang="ts">
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import { page } from '$app/state';
	import FixedDraftStage from '$lib/stage/FixedDraftStage.svelte';

	const steps = ['Start', 'Draw', 'Build', 'Polish', 'Export'];

	const modeLabelMap: Record<string, string> = {
		blank: 'Blank',
		'free-draw': 'Free Draw First',
		starter: 'Starter Scaffold'
	};

	type DrawTool = 'free-draw' | 'fill' | 'erase';

	const drawTools: Array<{ id: DrawTool; label: string }> = [
		{ id: 'free-draw', label: 'Free Draw' },
		{ id: 'fill', label: 'Fill' },
		{ id: 'erase', label: 'Erase' }
	];

	const toolGroups = [
		{
			title: 'Build',
			tools: ['Add Blob', 'Push/Pull', 'Mirror']
		},
		{
			title: 'Polish',
			tools: ['Smooth', 'Carve']
		}
	];

	let brushSize = 20;
	let brushStrength = 0.28;
	let autoFillClosedStroke = false;
	let mirrorDraw = false;
	let drawTool: DrawTool = 'free-draw';
	const paletteColors = [
		'#111827',
		'#334155',
		'#ef4444',
		'#f97316',
		'#f59e0b',
		'#22c55e',
		'#06b6d4',
		'#3b82f6',
		'#6366f1',
		'#8b5cf6',
		'#ec4899',
		'#f43f5e',
		'#f1d3b3',
		'#d5a97a',
		'#7c5132',
		'#ffffff'
	];
	let brushColorHex = '#3b82f6';

	$: brushStrengthPercent = Math.round(brushStrength * 100);

	$: projectIdLabel = (page.params.projectId ?? 'local').slice(0, 8);

	function createAnotherProject() {
		void goto(`${base}/`);
	}
</script>

<main class="studio-shell">
	<header class="top-bar">
		<div class="brand-wrap">
			<p class="brand">IPCHAE</p>
			<p class="project-name">Project {projectIdLabel}</p>
		</div>
		<div class="top-actions">
			<span class="mode-badge">{modeLabelMap[page.url.searchParams.get('mode') ?? 'blank'] ?? 'Blank'}</span>
			<button type="button" class="ghost" on:click={createAnotherProject}>새 프로젝트</button>
			<button type="button" class="primary">Export</button>
		</div>
	</header>

	<nav class="stepper" aria-label="Modeling stepper">
		{#each steps as step, index}
			<div class="step-item {index === 0 ? 'active' : ''}">{step}</div>
		{/each}
	</nav>

	<section class="studio-grid">
		<aside class="tool-dock">
			<h2>Tools</h2>
			<div class="tool-group">
				<h3>Draw</h3>
				<div class="tool-list">
					{#each drawTools as tool}
						<button
							type="button"
							class="tool {drawTool === tool.id ? 'active' : ''}"
							on:click={() => (drawTool = tool.id)}
						>
							{tool.label}
						</button>
					{/each}
				</div>
			</div>
			{#each toolGroups as group}
				<div class="tool-group">
					<h3>{group.title}</h3>
					<div class="tool-list">
						{#each group.tools as tool}
							<button type="button" class="tool">{tool}</button>
						{/each}
					</div>
				</div>
			{/each}
		</aside>

		<div class="main-stage">
			<FixedDraftStage
				bind:brushSize
				bind:brushStrength
				bind:brushColorHex
				{paletteColors}
				{autoFillClosedStroke}
				{mirrorDraw}
				{drawTool}
			/>
		</div>

		<aside class="inspector">
			<h2>Inspector</h2>
			<label for="size">브러시 크기</label>
			<input id="size" type="range" min="1" max="60" bind:value={brushSize} />
			<p class="value-text">{brushSize}</p>
			<label for="strength">브러시 강도</label>
			<input id="strength" type="range" min="0.05" max="1" step="0.01" bind:value={brushStrength} />
			<p class="value-text">{brushStrengthPercent}%</p>
			<label for="auto-fill">닫힌 선 자동 면채움</label>
			<input id="auto-fill" type="checkbox" bind:checked={autoFillClosedStroke} />
			<p class="value-text">{autoFillClosedStroke ? 'ON' : 'OFF'}</p>
			<label for="mirror-draw">좌우 대칭 드로우</label>
			<input id="mirror-draw" type="checkbox" bind:checked={mirrorDraw} />
			<p class="value-text">{mirrorDraw ? 'ON' : 'OFF'}</p>
			<label for="brush-color">브러시 색상</label>
			<div class="color-row">
				<input id="brush-color" class="color-input" type="color" bind:value={brushColorHex} />
				<p class="value-text color-code">{brushColorHex.toUpperCase()}</p>
			</div>
			<div class="color-grid" role="list" aria-label="기본 팔레트 16색">
				{#each paletteColors as color}
						<button
							type="button"
							class="color-swatch {brushColorHex === color ? 'active' : ''}"
							style={`--swatch:${color};`}
							on:click={() => (brushColorHex = color)}
							aria-label={`색상 ${color}`}
						></button>
				{/each}
			</div>
			<div class="hint">
				<p>Day 2~3 목표</p>
				<ul>
					<li>입력 후 300ms 내 프리뷰 반영</li>
					<li>Undo/Redo 50 step 이상</li>
					<li>메인 카메라 고정 + PIP 쿼터뷰 조작</li>
					<li>브러시 색상 선택 + 모바일 터치 조작</li>
				</ul>
			</div>
		</aside>
	</section>
</main>
