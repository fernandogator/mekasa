import { SessionEndedError } from '../api/client';
import { endsSession, readIdToken } from './session';

const failing = (code: string) => ({ getIdToken: vi.fn(async () => Promise.reject(Object.assign(new Error(code), { code }))) });

describe('session-ending Firebase errors (UI-007 AC3, REQ-022 AC2)', () => {
  it('treats a refused refresh as the end of the session', () => {
    for (const code of ['auth/user-token-expired', 'auth/invalid-user-token', 'auth/user-disabled', 'auth/user-not-found']) {
      expect(endsSession({ code })).toBe(true);
    }
  });

  it('keeps the session through network and unknown failures', () => {
    expect(endsSession({ code: 'auth/network-request-failed' })).toBe(false);
    expect(endsSession(new Error('boom'))).toBe(false);
    expect(endsSession(null)).toBe(false);
  });
});

describe('readIdToken', () => {
  it('returns null without a user and passes the refresh flag through', async () => {
    expect(await readIdToken(null)).toBeNull();
    const user = { getIdToken: vi.fn(async () => 'tok') };
    expect(await readIdToken(user, true)).toBe('tok');
    expect(user.getIdToken).toHaveBeenCalledWith(true);
  });

  it('turns a refused refresh into SessionEndedError', async () => {
    await expect(readIdToken(failing('auth/user-token-expired'))).rejects.toBeInstanceOf(SessionEndedError);
  });

  it('rethrows network failures unchanged', async () => {
    await expect(readIdToken(failing('auth/network-request-failed'))).rejects.toMatchObject({ code: 'auth/network-request-failed' });
  });
});
