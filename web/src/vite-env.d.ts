/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_FIREBASE_API_KEY?: string;
  readonly VITE_FIREBASE_AUTH_DOMAIN?: string;
  readonly VITE_FIREBASE_PROJECT_ID?: string;
  readonly VITE_FIREBASE_APP_ID?: string;
  readonly VITE_FIREBASE_MESSAGING_SENDER_ID?: string;
  readonly VITE_FIREBASE_MEASUREMENT_ID?: string;
  readonly VITE_API_DIRECT_URL?: string;
  readonly VITE_MOCK_AUTH?: string;
  readonly VITE_LIVE_HOSTS?: string;
  readonly VITE_APP_VERSION?: string;
  readonly VITE_APP_BUILD?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
