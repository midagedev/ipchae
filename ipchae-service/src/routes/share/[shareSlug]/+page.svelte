<script lang="ts">
	import { page } from '$app/state';

	$: shareSlug = page.params.shareSlug ?? '';
</script>

<main class="placeholder-shell">
	<h1>Project Share</h1>
	<p>공유 슬러그: {shareSlug}</p>
	<p>이 페이지는 추후 read-only 3D 뷰어 + clone CTA + OG 경로와 연결됩니다.</p>
</main>

<style>
	.placeholder-shell {
		max-width: 960px;
		margin: 0 auto;
		padding: 56px 24px;
	}
</style>

