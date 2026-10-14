import { ApiError, apiRequest, configureApi, SessionEndedError } from './client';

const json = (status: number, body: unknown = {}) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });

describe('apiRequest session expiry (UI-007 AC3, REQ-022 AC1–AC2)', () => {
  const fetchMock = vi.fn<typeof fetch>();
  const onSessionExpired = vi.fn();

  beforeEach(() => {
    fetchMock.mockReset();
    onSessionExpired.mockReset();
    vi.stubGlobal('fetch', fetchMock);
  });

  afterEach(() => {
    configureApi(null);
    vi.unstubAllGlobals();
  });

  it('refreshes once and retries when the API answers 401', async () => {
    const getToken = vi.fn(async (force?: boolean) => (force ? 'fresh' : 'stale'));
    configureApi({ getToken, onSessionExpired });
    fetchMock.mockResolvedValueOnce(json(401)).mockResolvedValueOnce(json(200, { ok: true }));

    await expect(apiRequest('/v1/me')).resolves.toEqual({ ok: true });
    expect(getToken).toHaveBeenLastCalledWith(true);
    expect(onSessionExpired).not.toHaveBeenCalled();
  });

  it('ends the session when the retry is also refused', async () => {
    configureApi({ getToken: async () => 'tok', onSessionExpired });
    fetchMock.mockResolvedValue(json(401));

    await expect(apiRequest('/v1/me')).rejects.toMatchObject({ status: 401 });
    expect(onSessionExpired).toHaveBeenCalledTimes(1);
  });

  it('ends the session without calling the API when Firebase refuses the refresh', async () => {
    configureApi({
      getToken: async () => {
        throw new SessionEndedError('auth/user-token-expired');
      },
      onSessionExpired,
    });

    const error = await apiRequest('/v1/me').catch((e: unknown) => e);
    expect(error).toBeInstanceOf(ApiError);
    expect((error as ApiError).status).toBe(401);
    expect(fetchMock).not.toHaveBeenCalled();
    expect(onSessionExpired).toHaveBeenCalledTimes(1);
  });

  it('ends the session when the refresh after a 401 is refused', async () => {
    configureApi({
      getToken: async (force?: boolean) => {
        if (force) throw new SessionEndedError('auth/user-disabled');
        return 'stale';
      },
      onSessionExpired,
    });
    fetchMock.mockResolvedValueOnce(json(401));

    await expect(apiRequest('/v1/me')).rejects.toMatchObject({ status: 401 });
    expect(onSessionExpired).toHaveBeenCalledTimes(1);
  });

  it('keeps the session when the token can’t be read because the network is down', async () => {
    configureApi({
      getToken: async () => {
        throw Object.assign(new Error('offline'), { code: 'auth/network-request-failed' });
      },
      onSessionExpired,
    });

    await expect(apiRequest('/v1/me', { quiet: true })).rejects.toMatchObject({ status: 0 });
    expect(onSessionExpired).not.toHaveBeenCalled();
  });
});
