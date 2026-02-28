import { createStore, get, set } from 'idb-keyval';
import { writable } from 'svelte/store';

type ToolId = 'free-draw' | 'fill' | 'erase' | 'add-blob' | 'push-pull' | 'smooth' | 'carve';

type AchievementDef = {
	code: string;
	name: string;
	metricKey: string;
	thresholdValue: number;
	xpReward: number;
};

export type XpEvent = {
	id: string;
	sourceType:
		| 'tool_first_use'
		| 'tool_usage_milestone'
		| 'project_clone_received'
		| 'part_import_received'
		| 'export_success'
		| 'achievement_unlock';
	xpDelta: number;
	eventKey: string;
	createdAt: number;
};

export type AchievementProgress = {
	code: string;
	name: string;
	metricKey: string;
	thresholdValue: number;
	progressValue: number;
	isUnlocked: boolean;
	unlockedAt?: number;
};

export type GamificationProfile = {
	level: number;
	totalXp: number;
	currentLevelXp: number;
	nextLevelXp: number;
};

type PersistedState = {
	totalXp: number;
	xpEvents: XpEvent[];
	dedupKeys: string[];
	toolUsage: Record<string, number>;
	achievements: AchievementProgress[];
};

const DB = createStore('ipchae-local', 'gamification');
const KEY = 'state-v1';
const MAX_XP_EVENTS = 80;

const ACHIEVEMENTS: AchievementDef[] = [
	{
		code: 'tool_free_draw_first',
		name: 'First Draw',
		metricKey: 'tool.free-draw.usage',
		thresholdValue: 1,
		xpReward: 12
	},
	{
		code: 'tool_fill_first',
		name: 'First Fill',
		metricKey: 'tool.fill.usage',
		thresholdValue: 1,
		xpReward: 12
	},
	{
		code: 'tool_erase_first',
		name: 'First Erase',
		metricKey: 'tool.erase.usage',
		thresholdValue: 1,
		xpReward: 12
	},
	{
		code: 'tool_draw_10',
		name: 'Draw Apprentice',
		metricKey: 'tool.free-draw.usage',
		thresholdValue: 10,
		xpReward: 26
	},
	{
		code: 'share_clone_1',
		name: 'Shared Builder',
		metricKey: 'share.clone.received',
		thresholdValue: 1,
		xpReward: 20
	},
	{
		code: 'part_import_1',
		name: 'Part Curator',
		metricKey: 'part.import.received',
		thresholdValue: 1,
		xpReward: 18
	},
	{
		code: 'export_first',
		name: 'First Export',
		metricKey: 'export.success.count',
		thresholdValue: 1,
		xpReward: 24
	}
];

function makeInitialState(): PersistedState {
	return {
		totalXp: 0,
		xpEvents: [],
		dedupKeys: [],
		toolUsage: {},
		achievements: ACHIEVEMENTS.map((item) => ({
			code: item.code,
			name: item.name,
			metricKey: item.metricKey,
			thresholdValue: item.thresholdValue,
			progressValue: 0,
			isUnlocked: false
		}))
	};
}

export function computeLevelFromXp(totalXp: number): GamificationProfile {
	let level = 1;
	let xpForCurrent = 120;
	let consumed = 0;

	while (totalXp >= consumed + xpForCurrent) {
		consumed += xpForCurrent;
		level += 1;
		xpForCurrent += 40;
	}

	return {
		level,
		totalXp,
		currentLevelXp: totalXp - consumed,
		nextLevelXp: xpForCurrent
	};
}

function toAchievementMap(achievements: AchievementProgress[]) {
	return new Map(achievements.map((item) => [item.code, item]));
}

export const gamificationProfile = writable<GamificationProfile>(computeLevelFromXp(0));
export const gamificationAchievements = writable<AchievementProgress[]>(makeInitialState().achievements);
export const gamificationXpEvents = writable<XpEvent[]>([]);

let memoryState = makeInitialState();
let hydrated = false;

async function saveState() {
	await set(KEY, memoryState, DB);
}

function applyStateToStores() {
	gamificationProfile.set(computeLevelFromXp(memoryState.totalXp));
	gamificationAchievements.set([...memoryState.achievements]);
	gamificationXpEvents.set([...memoryState.xpEvents]);
}

export async function hydrateGamification() {
	if (hydrated) return;
	const stored = await get<PersistedState | undefined>(KEY, DB);
	if (stored) {
		memoryState = stored;
	}
	hydrated = true;
	applyStateToStores();
}

async function grantXp({
	sourceType,
	xpDelta,
	eventKey
}: {
	sourceType: XpEvent['sourceType'];
	xpDelta: number;
	eventKey: string;
}) {
	await hydrateGamification();
	if (memoryState.dedupKeys.includes(eventKey)) return;

	memoryState.dedupKeys.push(eventKey);
	if (memoryState.dedupKeys.length > 400) {
		memoryState.dedupKeys = memoryState.dedupKeys.slice(-400);
	}

	memoryState.totalXp += xpDelta;
	memoryState.xpEvents = [
		{
			id: `xp-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
			sourceType,
			xpDelta,
			eventKey,
			createdAt: Date.now()
		},
		...memoryState.xpEvents
	].slice(0, MAX_XP_EVENTS);
}

function metricValue(metricKey: string): number {
	if (metricKey.startsWith('tool.')) {
		const toolId = metricKey.split('.')[1];
		return memoryState.toolUsage[toolId] ?? 0;
	}
	if (metricKey === 'share.clone.received') {
		return memoryState.xpEvents.filter((item) => item.sourceType === 'project_clone_received').length;
	}
	if (metricKey === 'part.import.received') {
		return memoryState.xpEvents.filter((item) => item.sourceType === 'part_import_received').length;
	}
	if (metricKey === 'export.success.count') {
		return memoryState.xpEvents.filter((item) => item.sourceType === 'export_success').length;
	}
	return 0;
}

async function evaluateAchievements() {
	const achievementMap = toAchievementMap(memoryState.achievements);
	for (const definition of ACHIEVEMENTS) {
		const progress = achievementMap.get(definition.code);
		if (!progress) continue;
		progress.progressValue = metricValue(definition.metricKey);
		if (!progress.isUnlocked && progress.progressValue >= definition.thresholdValue) {
			progress.isUnlocked = true;
			progress.unlockedAt = Date.now();
			await grantXp({
				sourceType: 'achievement_unlock',
				xpDelta: definition.xpReward,
				eventKey: `achievement:${definition.code}`
			});
		}
	}
}

export async function recordToolUsed(toolId: ToolId) {
	await hydrateGamification();
	memoryState.toolUsage[toolId] = (memoryState.toolUsage[toolId] ?? 0) + 1;
	const usageCount = memoryState.toolUsage[toolId];

	if (usageCount === 1) {
		await grantXp({
			sourceType: 'tool_first_use',
			xpDelta: 8,
			eventKey: `tool:first:${toolId}`
		});
	}

	if (usageCount % 10 === 0) {
		await grantXp({
			sourceType: 'tool_usage_milestone',
			xpDelta: 15,
			eventKey: `tool:milestone:${toolId}:${usageCount}`
		});
	}

	await evaluateAchievements();
	await saveState();
	applyStateToStores();
}

export async function recordShareCloneReward(shareSlug: string) {
	await grantXp({
		sourceType: 'project_clone_received',
		xpDelta: 14,
		eventKey: `share-clone:${shareSlug}`
	});
	await evaluateAchievements();
	await saveState();
	applyStateToStores();
}

export async function recordPartImportReward(partShareSlug: string) {
	await grantXp({
		sourceType: 'part_import_received',
		xpDelta: 12,
		eventKey: `part-import:${partShareSlug}`
	});
	await evaluateAchievements();
	await saveState();
	applyStateToStores();
}

export async function recordExportSuccess(projectId: string) {
	await grantXp({
		sourceType: 'export_success',
		xpDelta: 20,
		eventKey: `export:${projectId}:${Date.now()}`
	});
	await evaluateAchievements();
	await saveState();
	applyStateToStores();
}
