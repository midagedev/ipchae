<script lang="ts">
	import { page } from '$app/state';

	$: inviteCode = page.params.inviteCode ?? '';
</script>

<main class="placeholder-shell">
	<h1>Collaboration Join</h1>
	<p>초대 코드: {inviteCode}</p>
	<p>이 라우트는 session join/presence/lock 흐름과 순차적으로 연결됩니다.</p>
</main>

<style>
	.placeholder-shell {
		max-width: 960px;
		margin: 0 auto;
		padding: 56px 24px;
	}
</style>

