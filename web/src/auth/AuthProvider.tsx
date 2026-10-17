/**
 * Firebase Auth session for the web app.
 *
 * Satisfies: UI-007 (Desktop Web App) AC2, AC3; REQ-022 AC1–AC5
 *
 * The session counts as expired when the API still answers 401 after a
 * token refresh, when Firebase refuses the refresh, or when Firebase signs
 * the user out without the user asking. The tab re-checks the session each
 * time it becomes visible, so a page left open for hours goes to sign-in
 * instead of showing stale data.
 *
 * Mock mode (VITE_MOCK_AUTH=1, layout tests and local design work) signs in
 * a fake user whose token is `test:<uid>`, which the API accepts only when
 * ALLOW_TEST_AUTH is on.
 */

import { createContext, type ReactNode, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';

import { analytics } from '../analytics/analytics';
import { configureApi, SessionEndedError } from '../api/client';
import { mockAuth } from '../config';
import { appLog } from '../diagnostics/appLog';
import { readIdToken } from './session';

export interface SessionUser {
  uid: string;
  email: string | null;
  displayName: string | null;
}

type Status = 'loading' | 'signedOut' | 'signedIn';

interface AuthState {
  status: Status;
  user: SessionUser | null;
  sessionExpired: boolean;
  lastEmail: string;
  signInWithGoogle(): Promise<void>;
  signInWithPassword(email: string, password: string): Promise<void>;
  sendPasswordReset(email: string): Promise<void>;
  signOut(): Promise<void>;
}

const AuthContext = createContext<AuthState | null>(null);
const LAST_EMAIL_KEY = 'mekasa.lastEmail';
const MOCK_UID_KEY = 'mekasa.mockUid';

export function mockUser(): SessionUser {
  const uid = (typeof localStorage !== 'undefined' && localStorage.getItem(MOCK_UID_KEY)) || 'owner-1';
  return { uid, email: `${uid}@example.com`, displayName: uid === 'owner-1' ? 'Leo Rodriguez' : 'Maya Rodriguez' };
}

type FirebaseAuthModule = typeof import('firebase/auth');

export function AuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<Status>('loading');
  const [user, setUser] = useState<SessionUser | null>(null);
  const [sessionExpired, setSessionExpired] = useState(false);
  const [lastEmail, setLastEmail] = useState(() => localStorage.getItem(LAST_EMAIL_KEY) ?? '');
  const authRef = useRef<{ mod: FirebaseAuthModule; auth: import('firebase/auth').Auth } | null>(null);
  const expiringRef = useRef(false);
  const userSignOutRef = useRef(false);

  const rememberEmail = useCallback((email: string | null) => {
    if (!email) return;
    localStorage.setItem(LAST_EMAIL_KEY, email);
    setLastEmail(email);
  }, []);

  const endSession = useCallback(
    async (expired: boolean) => {
      if (expired) {
        appLog.info('session', 'Session expired; signing out');
        setSessionExpired(true);
      }
      if (mockAuth) {
        setUser(null);
        setStatus('signedOut');
        return;
      }
      const ref = authRef.current;
      if (ref) await ref.mod.signOut(ref.auth);
    },
    [],
  );

  const expireSession = useCallback(() => {
    if (expiringRef.current) return;
    expiringRef.current = true;
    void endSession(true).finally(() => {
      expiringRef.current = false;
    });
  }, [endSession]);

  useEffect(() => {
    if (mockAuth) {
      const fake = mockUser();
      configureApi({
        getToken: async () => `test:${fake.uid}`,
        onSessionExpired: expireSession,
      });
      setUser(fake);
      setStatus('signedIn');
      return;
    }
    let unsubscribe = () => {};
    let cancelled = false;
    void (async () => {
      const [{ firebaseApp, firebaseConfigured }, mod] = await Promise.all([import('../firebase'), import('firebase/auth')]);
      if (cancelled) return;
      if (!firebaseConfigured()) {
        appLog.log('warning', 'auth', 'Firebase web config missing; sign-in disabled');
        setStatus('signedOut');
        return;
      }
      const auth = mod.getAuth(firebaseApp());
      authRef.current = { mod, auth };
      configureApi({
        getToken: (force) => readIdToken(auth.currentUser, force),
        onSessionExpired: expireSession,
      });
      let signedIn = false;
      unsubscribe = mod.onAuthStateChanged(auth, (firebaseUser) => {
        if (firebaseUser) {
          signedIn = true;
          userSignOutRef.current = false;
          setUser({ uid: firebaseUser.uid, email: firebaseUser.email, displayName: firebaseUser.displayName });
          rememberEmail(firebaseUser.email);
          setStatus('signedIn');
        } else {
          if (signedIn && !userSignOutRef.current) {
            appLog.info('session', 'Signed out by Firebase Auth; session expired');
            setSessionExpired(true);
          }
          signedIn = false;
          setUser(null);
          setStatus('signedOut');
        }
      });
    })();
    return () => {
      cancelled = true;
      unsubscribe();
    };
  }, [expireSession, rememberEmail]);

  useEffect(() => {
    if (mockAuth || status !== 'signedIn') return;
    const check = () => {
      const ref = authRef.current;
      if (document.visibilityState !== 'visible' || !ref) return;
      readIdToken(ref.auth.currentUser).catch((error: unknown) => {
        if (error instanceof SessionEndedError) expireSession();
        else appLog.log('warning', 'session', 'Session check failed; keeping the session', { fields: { error: String(error) } });
      });
    };
    document.addEventListener('visibilitychange', check);
    return () => document.removeEventListener('visibilitychange', check);
  }, [status, expireSession]);

  const signInWithGoogle = useCallback(async () => {
    const ref = authRef.current;
    if (!ref) throw new Error('Sign-in is not available.');
    await ref.mod.signInWithPopup(ref.auth, new ref.mod.GoogleAuthProvider());
    setSessionExpired(false);
    analytics.track('login', { method: 'google' });
    appLog.info('auth', 'Signed in', { method: 'google' });
  }, []);

  const signInWithPassword = useCallback(
    async (email: string, password: string) => {
      const ref = authRef.current;
      if (!ref) throw new Error('Sign-in is not available.');
      await ref.mod.signInWithEmailAndPassword(ref.auth, email.trim(), password);
      rememberEmail(email.trim());
      setSessionExpired(false);
      analytics.track('login', { method: 'password' });
      appLog.info('auth', 'Signed in', { method: 'password' });
    },
    [rememberEmail],
  );

  const sendPasswordReset = useCallback(async (email: string) => {
    const ref = authRef.current;
    if (!ref) throw new Error('Password reset is not available.');
    await ref.mod.sendPasswordResetEmail(ref.auth, email.trim());
  }, []);

  const signOut = useCallback(async () => {
    appLog.info('auth', 'Signed out');
    userSignOutRef.current = true;
    setSessionExpired(false);
    await endSession(false);
  }, [endSession]);

  const value = useMemo<AuthState>(
    () => ({ status, user, sessionExpired, lastEmail, signInWithGoogle, signInWithPassword, sendPasswordReset, signOut }),
    [status, user, sessionExpired, lastEmail, signInWithGoogle, signInWithPassword, sendPasswordReset, signOut],
  );
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const value = useContext(AuthContext);
  if (!value) throw new Error('useAuth outside AuthProvider');
  return value;
}

export function authErrorMessage(error: unknown): string {
  const code = typeof error === 'object' && error && 'code' in error ? String((error as { code: unknown }).code) : '';
  switch (code) {
    case 'auth/invalid-credential':
    case 'auth/wrong-password':
    case 'auth/user-not-found':
      return 'That email and password don’t match.';
    case 'auth/too-many-requests':
      return 'Too many attempts. Wait a moment and try again.';
    case 'auth/popup-closed-by-user':
    case 'auth/cancelled-popup-request':
      return '';
    case 'auth/network-request-failed':
      return 'Can’t reach the sign-in service. Check your connection.';
    case 'auth/unauthorized-domain':
      return 'This address isn’t allowed to sign in yet.';
    default:
      return error instanceof Error ? error.message : 'Sign-in failed. Try again.';
  }
}
