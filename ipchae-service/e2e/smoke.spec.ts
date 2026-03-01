import { expect, test } from '@playwright/test';

test('home renders starter cards', async ({ page }) => {
	await page.goto('/');
	await expect(page.getByRole('heading', { name: 'Quick Start' })).toBeVisible();
	await expect(page.getByRole('button', { name: /Blank/i })).toBeVisible();
	await expect(page.getByRole('button', { name: /Free Draw First/i })).toBeVisible();
	await expect(page.getByRole('button', { name: /Starter Scaffold/i })).toBeVisible();
});

test('parts route renders filters', async ({ page }) => {
	await page.goto('/parts');
	await expect(page.getByRole('heading', { name: /파츠 탐색/ })).toBeVisible();
	await expect(page.getByRole('searchbox', { name: 'Search' })).toBeVisible();
});

test('project share page renders clone CTA', async ({ page }) => {
	await page.goto('/share/demo-hero-robot');
	await expect(page.getByRole('heading', { name: 'Hero Robot Base' })).toBeVisible();
	await expect(page.getByRole('button', { name: '이걸 이용해서 고쳐보시겠어요?' })).toBeVisible();
	await expect(page.getByRole('button', { name: '같이 편집하기' })).toBeVisible();
});

test('studio renders import action', async ({ page }) => {
	await page.goto('/studio/e2e-import-project?mode=blank');
	await expect(page.getByRole('button', { name: '초등 모드' })).toBeVisible();
	await expect(page.getByRole('button', { name: '다시실행' })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Select', exact: true })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Select All' })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Duplicate' })).toBeVisible();
	await page.getByRole('button', { name: '초등 모드' }).click();
	await expect(page.getByRole('button', { name: 'Import' })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Group', exact: true })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Sphere' })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Pivot Sel' })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Plane Cut +' })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Delete' })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Slice Cut' })).toBeVisible();
});
