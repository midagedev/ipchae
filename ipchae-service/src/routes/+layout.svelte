<script lang="ts">
	import '../app.css';
	import favicon from '$lib/assets/favicon.svg';
	import { onMount } from 'svelte';
	import { hydrateUiLocale } from '$lib/core/i18n/ui-locale';

	let { children } = $props();

	onMount(async () => {
		hydrateUiLocale();
		await Promise.all([
			import('@spectrum-web-components/theme/sp-theme.js'),
			import('@spectrum-web-components/theme/spectrum-two/theme-light.js'),
			import('@spectrum-web-components/theme/spectrum-two/theme-dark.js'),
			import('@spectrum-web-components/theme/spectrum-two/scale-medium.js'),
			import('@spectrum-web-components/theme/spectrum-two/scale-large.js')
		]);
	});
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
</svelte:head>

{@render children()}
