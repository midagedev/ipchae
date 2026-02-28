// See https://svelte.dev/docs/kit/types#app.d.ts
// for information about these interfaces
declare global {
	interface ImportMetaEnv {
		readonly PUBLIC_SUPABASE_URL?: string;
		readonly PUBLIC_SUPABASE_ANON_KEY?: string;
		readonly PUBLIC_APP_ENV?: string;
		readonly PUBLIC_STARTER_CATALOG_VERSION?: string;
		readonly PUBLIC_PART_CATALOG_VERSION?: string;
		readonly PUBLIC_ACHIEVEMENT_CATALOG_VERSION?: string;
		readonly PUBLIC_COLLAB_MAX_EDITORS?: string;
		readonly VITE_SUPABASE_URL?: string;
		readonly VITE_SUPABASE_ANON_KEY?: string;
	}

	interface ImportMeta {
		readonly env: ImportMetaEnv;
	}

	namespace App {
		// interface Error {}
		// interface Locals {}
		// interface PageData {}
		// interface PageState {}
		// interface Platform {}
	}
}

export {};
