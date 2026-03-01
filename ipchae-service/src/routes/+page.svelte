<script lang="ts">
	import { goto } from '$app/navigation';
	import { base } from '$app/paths';
	import { onMount } from 'svelte';
	import { loadStarterCatalog, type StarterCatalog } from '$lib/core/catalog/starter-catalog';
	import { getRecentProjects } from '$lib/core/persistence/project-snapshot-store';
	import { setUiLocale, uiLocale, type UiLocale } from '$lib/core/i18n/ui-locale';

	type StartMode = 'blank' | 'free-draw' | 'starter';
	type RecentProject = { projectId: string; updatedAt: number };
	type LocalizedText = Record<UiLocale, string>;
	type LocalizedCard = {
		mode: StartMode;
		icon: string;
		title: LocalizedText;
		description: LocalizedText;
	};

	const localeOptions: Array<{ id: UiLocale; label: string }> = [
		{ id: 'ko', label: '한국어' },
		{ id: 'en', label: 'English' },
		{ id: 'ja', label: '日本語' }
	];

	const quickStartCards: LocalizedCard[] = [
		{
			mode: 'blank',
			icon: '◻',
			title: {
				ko: '빈 캔버스',
				en: 'Blank',
				ja: 'ブランク'
			},
			description: {
				ko: '아무 것도 없는 씬에서 바로 시작',
				en: 'Start from an empty scene',
				ja: '何もないシーンから始める'
			}
		},
		{
			mode: 'free-draw',
			icon: '✎',
			title: {
				ko: '자유 드로잉',
				en: 'Free Draw First',
				ja: 'フリードロー優先'
			},
			description: {
				ko: '3D 펜처럼 선부터 그리며 형태 만들기',
				en: 'Build form by drawing lines first',
				ja: '3Dペンのように線から形を作る'
			}
		},
		{
			mode: 'starter',
			icon: '◎',
			title: {
				ko: '스타터 템플릿',
				en: 'Starter Scaffold',
				ja: 'スターターテンプレート'
			},
			description: {
				ko: '기본 템플릿 위에서 빠르게 캐릭터 시작',
				en: 'Start quickly on a starter template',
				ja: 'テンプレートから素早く開始'
			}
		}
	];

	const coreGoals: LocalizedText[] = [
		{
			ko: '60초 안에 캐릭터 베이스 만들기',
			en: 'Build a character base within 60 seconds',
			ja: '60秒以内にキャラのベースを作る'
		},
		{
			ko: '10분 안에 첫 Export 도달하기',
			en: 'Reach first export within 10 minutes',
			ja: '10分以内に最初の書き出しに到達する'
		},
		{
			ko: 'Draw -> Build -> Polish 루프를 직관적으로 완주하기',
			en: 'Finish Draw -> Build -> Polish loop intuitively',
			ja: 'Draw -> Build -> Polish を直感的に完走する'
		}
	];

	const serviceTracks: Array<{ href: string; icon: string; title: LocalizedText; description: LocalizedText }> = [
		{
			href: `${base}/parts`,
			icon: '◫',
			title: { ko: '파츠', en: 'Parts', ja: 'パーツ' },
			description: {
				ko: '브라우저/저장/게시 흐름',
				en: 'Browse, save, and publish parts',
				ja: '閲覧・保存・公開フロー'
			}
		},
		{
			href: `${base}/account`,
			icon: '◉',
			title: { ko: '계정', en: 'Account', ja: 'アカウント' },
			description: {
				ko: '동기화/레벨/업적',
				en: 'Sync, level, and achievements',
				ja: '同期・レベル・実績'
			}
		},
		{
			href: `${base}/help`,
			icon: '?',
			title: { ko: '도움말', en: 'Help', ja: 'ヘルプ' },
			description: {
				ko: '가이드/FAQ/문제해결',
				en: 'Guide, FAQ, and troubleshooting',
				ja: 'ガイド・FAQ・トラブル対応'
			}
		},
		{
			href: `${base}/share/demo-hero-robot`,
			icon: '↗',
			title: { ko: '공유 데모', en: 'Share Demo', ja: '共有デモ' },
			description: {
				ko: '프로젝트 공유 CTA 테스트',
				en: 'Project share CTA test',
				ja: 'プロジェクト共有CTAテスト'
			}
		},
		{
			href: `${base}/part/demo-part-hair-01`,
			icon: '⬡',
			title: { ko: '파츠 데모', en: 'Part Demo', ja: 'パーツデモ' },
			description: {
				ko: '파츠 공유 import 테스트',
				en: 'Part-share import test',
				ja: 'パーツ共有インポートテスト'
			}
		},
		{
			href: `${base}/collab/demo-project-editor`,
			icon: '⟷',
			title: { ko: '협업 데모', en: 'Collab Demo', ja: '協業デモ' },
			description: {
				ko: 'invite/lock 시뮬레이터',
				en: 'Invite/lock simulator',
				ja: '招待/ロックシミュレーター'
			}
		}
	];
	let recentProjects: RecentProject[] = [];
	let starterCatalog: StarterCatalog | null = null;

	function t(text: LocalizedText) {
		return text[$uiLocale] ?? text.ko;
	}

	function onLocaleChange(event: Event) {
		const value = (event.currentTarget as HTMLSelectElement).value as UiLocale;
		setUiLocale(value);
	}

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
		<div class="hero-meta-row">
			<p class="eyebrow">IPCHAE Core MVP</p>
			<label class="locale-picker" for="home-locale">
				<span class="locale-icon" aria-hidden="true">🌐</span>
				<select id="home-locale" value={$uiLocale} on:change={onLocaleChange}>
					{#each localeOptions as option}
						<option value={option.id}>{option.label}</option>
					{/each}
				</select>
			</label>
		</div>
		<h1>{t({ ko: '쉽게 시작하고 끝까지 완주하는 3D 모델링', en: '3D modeling that starts easy and finishes strong', ja: 'かんたんに始めて最後まで作れる3Dモデリング' })}</h1>
		<p class="lead">
			{t({
				ko: '이번 MVP는 공유/협업보다 먼저, 첫 사용자도 막히지 않고 캐릭터를 완성하도록 만드는 데 집중합니다.',
				en: 'This MVP focuses on helping first-time users complete a character before advanced sharing/collab.',
				ja: 'このMVPは共有/協業より先に、初回ユーザーが止まらず作品を完成できることに集中します。'
			})}
		</p>
	</section>

	<section class="quick-start">
		<h2>{t({ ko: '빠른 시작', en: 'Quick Start', ja: 'クイックスタート' })}</h2>
		<div class="card-grid">
			{#each quickStartCards as card}
				<button class="start-card" type="button" on:click={() => startProject(card.mode)}>
					<span class="card-title card-title-row">
						<span class="menu-icon" aria-hidden="true">{card.icon}</span>
						<span>{t(card.title)}</span>
					</span>
					<span class="card-desc">{t(card.description)}</span>
					<span class="card-action">{t({ ko: '바로 시작', en: 'Start Now', ja: 'すぐ始める' })}</span>
				</button>
			{/each}
		</div>
	</section>

	<section class="focus">
		<h2>{t({ ko: '이번 스프린트 목표', en: 'Sprint Goals', ja: '今回のスプリント目標' })}</h2>
		<ul>
			{#each coreGoals as goal}
				<li>{t(goal)}</li>
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
		<h2>{t({ ko: '서비스 트랙', en: 'Service Tracks', ja: 'サービストラック' })}</h2>
		<div class="card-grid">
			{#each serviceTracks as track}
				<a class="start-card" href={track.href}>
					<span class="card-title card-title-row">
						<span class="menu-icon" aria-hidden="true">{track.icon}</span>
						<span>{t(track.title)}</span>
					</span>
					<span class="card-desc">{t(track.description)}</span>
				</a>
			{/each}
		</div>
	</section>

	<section class="focus">
		<h2>{t({ ko: '최근 프로젝트', en: 'Recent Projects', ja: '最近のプロジェクト' })}</h2>
		{#if recentProjects.length === 0}
			<p>{t({ ko: '아직 저장된 로컬 프로젝트가 없습니다.', en: 'No saved local projects yet.', ja: '保存されたローカルプロジェクトはまだありません。' })}</p>
		{:else}
			<div class="card-grid">
				{#each recentProjects.slice(0, 6) as item}
					<button class="start-card" type="button" on:click={() => openProject(item.projectId)}>
						<span class="card-title">Project {item.projectId.slice(0, 8)}</span>
						<span class="card-desc">{new Date(item.updatedAt).toLocaleString()}</span>
						<span class="card-action">{t({ ko: '열기', en: 'Open', ja: '開く' })}</span>
					</button>
				{/each}
			</div>
		{/if}
	</section>
</main>
