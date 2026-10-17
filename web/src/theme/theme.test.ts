import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, cpSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { applyTheme, readPreference, resolveTheme, savePreference } from './theme';

function memoryStorage(initial: Record<string, string> = {}) {
  const data = { ...initial };
  return {
    getItem: (key: string) => data[key] ?? null,
    setItem: (key: string, value: string) => {
      data[key] = value;
    },
    data,
  };
}

describe('theme preference (UI-007 AC13)', () => {
  it('defaults to system and ignores unknown values', () => {
    expect(readPreference(memoryStorage())).toBe('system');
    expect(readPreference(memoryStorage({ 'mekasa.theme': 'halloween' }))).toBe('system');
    expect(readPreference(memoryStorage({ 'mekasa.theme': 'grounded-dark' }))).toBe('grounded-dark');
  });

  it('follows the OS setting only for the system preference', () => {
    expect(resolveTheme('system', true)).toBe('grounded-dark');
    expect(resolveTheme('system', false)).toBe('grounded');
    expect(resolveTheme('grounded', true)).toBe('grounded');
  });

  it('writes data-theme on the root and persists the choice', () => {
    const root = document.createElement('html');
    expect(applyTheme('grounded-dark', root)).toBe('grounded-dark');
    expect(root.dataset.theme).toBe('grounded-dark');
    const storage = memoryStorage();
    savePreference('grounded', storage);
    expect(storage.data['mekasa.theme']).toBe('grounded');
  });
});

describe('token lint (UI-007 AC13)', () => {
  const script = join(process.cwd(), 'scripts/check-tokens.mjs');

  function runOn(files: Record<string, string>): number {
    const dir = mkdtempSync(join(tmpdir(), 'tokens-'));
    mkdirSync(join(dir, 'scripts'));
    cpSync(script, join(dir, 'scripts/check-tokens.mjs'));
    for (const [path, body] of Object.entries(files)) {
      mkdirSync(join(dir, 'src', path, '..'), { recursive: true });
      writeFileSync(join(dir, 'src', path), body);
    }
    try {
      execFileSync('node', [join(dir, 'scripts/check-tokens.mjs')], { stdio: 'pipe' });
      return 0;
    } catch (error) {
      return (error as { status: number }).status;
    }
  }

  it('allows colors only in tokens.css', () => {
    expect(runOn({ 'theme/tokens.css': ':root { --brand: 10 20 30; color: #fff; }', 'a.tsx': 'export const a = "bg-brand";' })).toBe(0);
  });

  it('fails on hex or rgb literals elsewhere', () => {
    expect(runOn({ 'a.tsx': 'export const a = "#ff0000";' })).toBe(1);
    expect(runOn({ 'b.css': '.x { color: rgba(0, 0, 0, 0.5); }' })).toBe(1);
  });
});
