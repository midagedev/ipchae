import { describe, expect, it } from 'vitest';
import { computeLevelFromXp } from '$lib/core/gamification/gamification-store';

describe('computeLevelFromXp', () => {
	it('returns level 1 at zero xp', () => {
		const profile = computeLevelFromXp(0);
		expect(profile.level).toBe(1);
		expect(profile.currentLevelXp).toBe(0);
		expect(profile.nextLevelXp).toBe(120);
	});

	it('moves to level 2 when threshold is reached', () => {
		const profile = computeLevelFromXp(120);
		expect(profile.level).toBe(2);
		expect(profile.currentLevelXp).toBe(0);
		expect(profile.nextLevelXp).toBe(160);
	});
});

