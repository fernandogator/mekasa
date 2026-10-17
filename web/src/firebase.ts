import { type FirebaseApp, getApps, initializeApp } from 'firebase/app';

import { firebaseConfig } from './config';

export function firebaseConfigured(): boolean {
  return Boolean(firebaseConfig.apiKey && firebaseConfig.appId && firebaseConfig.projectId);
}

export function firebaseApp(): FirebaseApp {
  return getApps()[0] ?? initializeApp(firebaseConfig);
}
