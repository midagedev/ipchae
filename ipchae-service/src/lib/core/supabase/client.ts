import { createClient, type SupabaseClient } from '@supabase/supabase-js';

let client: SupabaseClient | null = null;

function readPublicEnv() {
	const publicUrl =
		import.meta.env.PUBLIC_SUPABASE_URL || import.meta.env.VITE_SUPABASE_URL || '';
	const publicAnonKey =
		import.meta.env.PUBLIC_SUPABASE_ANON_KEY || import.meta.env.VITE_SUPABASE_ANON_KEY || '';

	return {
		publicUrl,
		publicAnonKey
	};
}

export function getSupabaseClient(): SupabaseClient | null {
	if (client) return client;
	const { publicUrl, publicAnonKey } = readPublicEnv();

	if (!publicUrl || !publicAnonKey) {
		return null;
	}

	client = createClient(publicUrl, publicAnonKey, {
		auth: {
			persistSession: true,
			autoRefreshToken: true
		}
	});

	return client;
}

