import { defineConfig, devices } from '@playwright/test';

const PORT = 4173;

/**
 * Layout tests (UI-007, guardrail rule 9). The app runs in mock-auth mode with
 * every `/v1/**` call answered by fixtures, so no backend or Firebase is used.
 * Baselines live in design/baselines/web/ and are compared at the project's
 * 15% structural tolerance.
 */
export default defineConfig({
  testDir: 'tests/layout',
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',
  snapshotPathTemplate: '../design/baselines/web/{arg}{ext}',
  expect: {
    toHaveScreenshot: { maxDiffPixelRatio: 0.15, animations: 'disabled', caret: 'hide' },
  },
  use: {
    baseURL: `http://localhost:${PORT}`,
    timezoneId: 'America/Chicago',
    locale: 'en-US',
    colorScheme: 'light',
    trace: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    command: `npx vite --port ${PORT} --strictPort`,
    url: `http://localhost:${PORT}`,
    reuseExistingServer: !process.env.CI,
    env: { VITE_MOCK_AUTH: '1', VITE_API_DIRECT_URL: '' },
  },
});
