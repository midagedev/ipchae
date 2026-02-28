<script lang="ts">
	import { page } from '$app/state';

	$: partShareSlug = page.params.partShareSlug ?? '';
</script>

<main class="placeholder-shell">
	<h1>Part Share</h1>
	<p>파츠 공유 슬러그: {partShareSlug}</p>
	<p>이 페이지는 추후 파츠 미리보기 + import/remix CTA와 연결됩니다.</p>
</main>

<style>
	.placeholder-shell {
		max-width: 960px;
		margin: 0 auto;
		padding: 56px 24px;
	}
</style>

