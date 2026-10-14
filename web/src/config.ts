/**
 * Build-time configuration. The Firebase web config is public client config
 * supplied through Vite env vars from GitHub Actions variables (UI-007 AC17).
 */

const env = import.meta.env;

export const firebaseConfig = {
  apiKey: env.VITE_FIREBASE_API_KEY ?? '',
  authDomain: env.VITE_FIREBASE_AUTH_DOMAIN ?? '',
  projectId: env.VITE_FIREBASE_PROJECT_ID ?? '',
  appId: env.VITE_FIREBASE_APP_ID ?? '',
  messagingSenderId: env.VITE_FIREBASE_MESSAGING_SENDER_ID ?? '',
  measurementId: env.VITE_FIREBASE_MEASUREMENT_ID ?? '',
};

/** Cloud Run service URL for calls that outlast the 60 s Hosting rewrite (UI-007 AC11). */
export const directApiUrl: string = (env.VITE_API_DIRECT_URL ?? '').replace(/\/$/, '');

/** Mock sign-in for layout tests and local design work; never set in deployed builds. */
export const mockAuth: boolean = env.VITE_MOCK_AUTH === '1';

/** Hosts where Analytics may collect (UI-007 AC18). */
export const liveHosts: readonly string[] = (env.VITE_LIVE_HOSTS ?? 'hackathon2025-472017.web.app,hackathon2025-472017.firebaseapp.com')
  .split(',')
  .map((host: string) => host.trim())
  .filter(Boolean);

export const appVersion: string = env.VITE_APP_VERSION ?? '0.1.0';
export const appBuild: string = env.VITE_APP_BUILD ?? 'dev';
