import { getSupabaseClient } from '$lib/core/supabase/client';

export type StarterStyle =
	| 'nendo'
	| 'moe'
	| 'minecraft'
	| 'roblox'
	| 'anime'
	| 'animal'
	| 'robot'
	| 'fantasy'
	| 'generic';

export type StarterPack = {
	id: string;
	slug: string;
	name: string;
	description: string;
	targetStyle: StarterStyle;
};

export type StarterTemplate = {
	id: string;
	packId: string;
	slug: string;
	name: string;
	targetStyle: StarterStyle;
	difficulty: 'easy' | 'normal' | 'advanced';
	defaultProportion: {
		headRatio: number;
		bodyRatio: number;
		legRatio: number;
	};
};

export type StarterPart = {
	id: string;
	name: string;
	category: 'head' | 'face' | 'hair' | 'outfit' | 'hand' | 'foot' | 'props' | 'voxel';
	styleFamily: StarterStyle;
	difficulty: 'easy' | 'normal' | 'advanced';
	tags: string[];
	isOfficial: boolean;
};

export type StarterCatalog = {
	source: 'local' | 'remote';
	packs: StarterPack[];
	templates: StarterTemplate[];
	parts: StarterPart[];
};

const LOCAL_PACKS: StarterPack[] = [
	{
		id: 'pack-nendo-core',
		slug: 'nendo-core',
		name: 'Nendo Core',
		description: '둥근 실루엣 중심의 빠른 베이스',
		targetStyle: 'nendo'
	},
	{
		id: 'pack-moe-core',
		slug: 'moe-core',
		name: 'Moe Core',
		description: '표정과 헤어 변형 중심',
		targetStyle: 'moe'
	},
	{
		id: 'pack-minecraft-core',
		slug: 'minecraft-core',
		name: 'Minecraft Core',
		description: '복셀 베이스 스타터',
		targetStyle: 'minecraft'
	},
	{
		id: 'pack-roblox-core',
		slug: 'roblox-core',
		name: 'Roblox Core',
		description: '블록 인체 비율 스타터',
		targetStyle: 'roblox'
	},
	{
		id: 'pack-anime-core',
		slug: 'anime-core',
		name: 'Anime Core',
		description: '애니 바디 비율 기본형',
		targetStyle: 'anime'
	},
	{
		id: 'pack-animal-core',
		slug: 'animal-core',
		name: 'Animal Core',
		description: '동물형 캐릭터 기초',
		targetStyle: 'animal'
	},
	{
		id: 'pack-robot-core',
		slug: 'robot-core',
		name: 'Robot Core',
		description: '메카닉 실루엣 스타터',
		targetStyle: 'robot'
	},
	{
		id: 'pack-fantasy-core',
		slug: 'fantasy-core',
		name: 'Fantasy Core',
		description: '판타지 캐릭터 베이스',
		targetStyle: 'fantasy'
	}
];

const LOCAL_TEMPLATES: StarterTemplate[] = LOCAL_PACKS.map((pack, index) => ({
	id: `tmpl-${pack.slug}`,
	packId: pack.id,
	slug: `${pack.slug}-base`,
	name: `${pack.name} Base`,
	targetStyle: pack.targetStyle,
	difficulty: index % 3 === 0 ? 'easy' : index % 3 === 1 ? 'normal' : 'advanced',
	defaultProportion: {
		headRatio: 1.25 + (index % 3) * 0.2,
		bodyRatio: 1.0 + ((index + 1) % 2) * 0.12,
		legRatio: 0.7 + ((index + 2) % 3) * 0.1
	}
}));

const PART_CATEGORIES: StarterPart['category'][] = [
	'head',
	'face',
	'hair',
	'outfit',
	'hand',
	'foot',
	'props',
	'voxel'
];

const STYLE_ORDER: StarterStyle[] = [
	'nendo',
	'moe',
	'minecraft',
	'roblox',
	'anime',
	'animal',
	'robot',
	'fantasy'
];

const LOCAL_PARTS: StarterPart[] = Array.from({ length: 40 }, (_, index) => {
	const category = PART_CATEGORIES[index % PART_CATEGORIES.length];
	const styleFamily = STYLE_ORDER[index % STYLE_ORDER.length];
	const difficulty = index % 3 === 0 ? 'easy' : index % 3 === 1 ? 'normal' : 'advanced';
	return {
		id: `part-local-${index + 1}`,
		name: `${styleFamily.toUpperCase()} ${category} ${String(index + 1).padStart(2, '0')}`,
		category,
		styleFamily,
		difficulty,
		tags: [styleFamily, category, difficulty, 'starter'],
		isOfficial: true
	};
});

function buildLocalCatalog(): StarterCatalog {
	return {
		source: 'local',
		packs: LOCAL_PACKS,
		templates: LOCAL_TEMPLATES,
		parts: LOCAL_PARTS
	};
}

export async function loadStarterCatalog(): Promise<StarterCatalog> {
	const supabase = getSupabaseClient();
	if (!supabase) {
		return buildLocalCatalog();
	}

	try {
		const [packsResponse, templatesResponse] = await Promise.all([
			supabase
				.from('starter_packs')
				.select('id, slug, name, description, is_active')
				.eq('is_active', true)
				.order('sort_order', { ascending: true })
				.limit(16),
			supabase
				.from('starter_templates')
				.select('id, pack_id, slug, name, target_style, difficulty, is_active')
				.eq('is_active', true)
				.order('sort_order', { ascending: true })
				.limit(64)
		]);

		if (packsResponse.error || templatesResponse.error) {
			return buildLocalCatalog();
		}

		if (!packsResponse.data || !templatesResponse.data) {
			return buildLocalCatalog();
		}

		const packs: StarterPack[] = packsResponse.data.map((item) => ({
			id: item.id,
			slug: item.slug,
			name: item.name,
			description: item.description ?? '',
			targetStyle: 'generic'
		}));

		const templates: StarterTemplate[] = templatesResponse.data.map((item) => ({
			id: item.id,
			packId: item.pack_id,
			slug: item.slug,
			name: item.name,
			targetStyle: (item.target_style as StarterStyle) ?? 'generic',
			difficulty: (item.difficulty as StarterTemplate['difficulty']) ?? 'easy',
			defaultProportion: {
				headRatio: 1.4,
				bodyRatio: 1.0,
				legRatio: 0.75
			}
		}));

		if (packs.length < 2 || templates.length < 8) {
			return buildLocalCatalog();
		}

		return {
			source: 'remote',
			packs,
			templates,
			parts: LOCAL_PARTS
		};
	} catch {
		return buildLocalCatalog();
	}
}

export function filterCatalogParts(
	parts: StarterPart[],
	options: {
		search?: string;
		category?: StarterPart['category'] | 'all';
		styleFamily?: StarterStyle | 'all';
		difficulty?: StarterPart['difficulty'] | 'all';
	}
) {
	const search = options.search?.trim().toLowerCase() ?? '';
	return parts.filter((part) => {
		if (options.category && options.category !== 'all' && part.category !== options.category) return false;
		if (options.styleFamily && options.styleFamily !== 'all' && part.styleFamily !== options.styleFamily)
			return false;
		if (options.difficulty && options.difficulty !== 'all' && part.difficulty !== options.difficulty)
			return false;
		if (!search) return true;
		if (part.name.toLowerCase().includes(search)) return true;
		return part.tags.some((tag) => tag.toLowerCase().includes(search));
	});
}

