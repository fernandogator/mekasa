/**
 * Theme selection through `data-theme` on <html> (UI-007 AC13).
 *
 * Satisfies: UI-007 (Desktop Web App)
 * Acceptance criteria: AC13
 */

export const THEMES = ['grounded', 'grounded-dark'] as const;
export type ThemeName = (typeof THEMES)[number];
export type ThemePreference = ThemeName | 'system';

const STORAGE_KEY = 'mekasa.theme';

export function readPreference(storage: Pick<Storage, 'getItem'> = localStorage): ThemePreference {
  const stored = storage.getItem(STORAGE_KEY);
  return stored === 'system' || (THEMES as readonly string[]).includes(stored ?? '')
    ? (stored as ThemePreference)
    : 'system';
}

export function resolveTheme(preference: ThemePreference, prefersDark: boolean): ThemeName {
  if (preference === 'system') return prefersDark ? 'grounded-dark' : 'grounded';
  return preference;
}

export function systemPrefersDark(): boolean {
  return typeof matchMedia === 'function' && matchMedia('(prefers-color-scheme: dark)').matches;
}

export function applyTheme(preference: ThemePreference, root: HTMLElement = document.documentElement): ThemeName {
  const theme = resolveTheme(preference, systemPrefersDark());
  root.dataset.theme = theme;
  return theme;
}

export function savePreference(preference: ThemePreference, storage: Pick<Storage, 'setItem'> = localStorage): void {
  storage.setItem(STORAGE_KEY, preference);
}
