import { describe, expect, it } from 'vitest';
import { parseInviteCode } from '$lib/core/collab/collab-service';

describe('parseInviteCode', () => {
	it('parses uuid with dash role suffix', () => {
		const parsed = parseInviteCode('123e4567-e89b-12d3-a456-426614174000-editor');
		expect(parsed).toEqual({
			projectId: '123e4567-e89b-12d3-a456-426614174000',
			role: 'editor'
		});
	});

	it('parses colon invite format and ignores trailing token', () => {
		const parsed = parseInviteCode('project-alpha-01:viewer:qwerty123');
		expect(parsed).toEqual({
			projectId: 'project-alpha-01',
			role: 'viewer'
		});
	});
});
