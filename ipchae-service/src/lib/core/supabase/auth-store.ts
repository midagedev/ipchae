import { writable } from 'svelte/store';
import { getSupabaseClient } from '$lib/core/supabase/client';

export type AuthState = {
	status: 'unavailable' | 'anonymous' | 'authenticated';
	userId?: string;
	email?: string;
};

export const authState = writable<AuthState>({
	status: 'unavailable'
});

export async function hydrateAuthState() {
	const supabase = getSupabaseClient();
	if (!supabase) {
		authState.set({
			status: 'unavailable'
		});
		return;
	}

	const {
		data: { session }
	} = await supabase.auth.getSession();

	if (!session?.user) {
		authState.set({
			status: 'anonymous'
		});
		return;
	}

	authState.set({
		status: 'authenticated',
		userId: session.user.id,
		email: session.user.email
	});
}

export async function signInWithOtp(email: string) {
	const supabase = getSupabaseClient();
	if (!supabase) throw new Error('SUPABASE_UNAVAILABLE');

	const { error } = await supabase.auth.signInWithOtp({
		email
	});

	if (error) throw error;
}

export async function signOutSupabase() {
	const supabase = getSupabaseClient();
	if (!supabase) return;
	await supabase.auth.signOut();
	await hydrateAuthState();
}

