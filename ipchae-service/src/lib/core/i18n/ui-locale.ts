import { writable } from 'svelte/store';

export type UiLocale = 'ko' | 'en' | 'ja';

const UI_LOCALE_STORAGE_KEY = 'ipchae-ui-locale-v1';
const DEFAULT_UI_LOCALE: UiLocale = 'ko';

export const uiLocale = writable<UiLocale>(DEFAULT_UI_LOCALE);

function isUiLocale(value: string | null | undefined): value is UiLocale {
	return value === 'ko' || value === 'en' || value === 'ja';
}

export function hydrateUiLocale() {
	if (typeof window === 'undefined') return;
	try {
		const fromStorage = window.localStorage.getItem(UI_LOCALE_STORAGE_KEY);
		if (isUiLocale(fromStorage)) {
			uiLocale.set(fromStorage);
			return;
		}
	} catch {
		// ignore storage failures
	}
	uiLocale.set(DEFAULT_UI_LOCALE);
}

export function setUiLocale(locale: UiLocale) {
	uiLocale.set(locale);
	if (typeof window === 'undefined') return;
	try {
		window.localStorage.setItem(UI_LOCALE_STORAGE_KEY, locale);
	} catch {
		// ignore storage failures
	}
}
