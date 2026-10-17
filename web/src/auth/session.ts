/**
 * Which Firebase Auth failures end the session.
 *
 * Satisfies: UI-007 (Desktop Web App) AC3; REQ-022 AC2
 */

import { SessionEndedError } from '../api/client';

/**
 * Codes Firebase returns when the refresh token is no longer accepted.
 * The SDK has no mapping for the server's INVALID_REFRESH_TOKEN, so it
 * surfaces as `auth/invalid-refresh-token`. Anything else,
 * `auth/network-request-failed` in particular, is a transient failure that
 * keeps the session.
 */
const SESSION_ENDING_CODES = new Set([
  'auth/user-token-expired',
  'auth/invalid-refresh-token',
  'auth/invalid-user-token',
  'auth/user-disabled',
  'auth/user-not-found',
]);

export function errorCode(error: unknown): string {
  return typeof error === 'object' && error && 'code' in error ? String((error as { code: unknown }).code) : '';
}

export function endsSession(error: unknown): boolean {
  return SESSION_ENDING_CODES.has(errorCode(error));
}

/** Reads an ID token, turning a refused refresh into `SessionEndedError`. */
export async function readIdToken(user: { getIdToken(forceRefresh?: boolean): Promise<string> } | null, force?: boolean): Promise<string | null> {
  if (!user) return null;
  try {
    return await user.getIdToken(force);
  } catch (error) {
    if (endsSession(error)) throw new SessionEndedError(errorCode(error));
    throw error;
  }
}
