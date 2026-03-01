import { expect, test } from '@playwright/test';

test('home renders starter cards', async ({ page }) => {
	await page.goto('/');
	await expect(page.getByRole('heading', { name: /Quick Start|빠른 시작|クイックスタート/i })).toBeVisible();
	await expect(page.getByRole('button', { name: /Blank|빈 캔버스|ブランク/i })).toBeVisible();
	await expect(page.getByRole('button', { name: /Free Draw First|자유 드로잉|フリードロー/i })).toBeVisible();
	await expect(page.getByRole('button', { name: /Starter Scaffold|스타터 템플릿|スターターテンプレート/i })).toBeVisible();
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
	await page.getByRole('button', { name: 'Copy' }).click();
	await expect(page.getByText('선택된 메시가 없습니다. Select 또는 Select All 후 다시 시도하세요.')).toBeVisible();
	await page.getByRole('button', { name: '초등 모드' }).click();
	await expect(page.getByRole('button', { name: /Import|가져오기|読み込み/i })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Group', exact: true })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Sphere' })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Pivot Sel' })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Plane Cut +' })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Delete' })).toBeVisible();
	await expect(page.getByRole('button', { name: 'Slice Cut' })).toBeVisible();
	await page.getByRole('button', { name: 'Plane Cut +' }).click();
	await expect(page.getByText('Slice Mode가 꺼져 있습니다. 먼저 Slice Mode를 켜주세요.')).toBeVisible();
});
