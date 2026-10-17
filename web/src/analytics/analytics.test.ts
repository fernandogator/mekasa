import { createHash } from 'node:crypto';

import { analytics, type AnalyticsSink, collectionAllowed, hashedUserRef, optedOut } from './analytics';

function recordingSink() {
  const calls: { kind: string; args: unknown[] }[] = [];
  const sink: AnalyticsSink = {
    event: (...args) => calls.push({ kind: 'event', args }),
    userId: (...args) => calls.push({ kind: 'userId', args }),
    userProperties: (...args) => calls.push({ kind: 'userProperties', args }),
    enabled: (...args) => calls.push({ kind: 'enabled', args }),
  };
  return { sink, calls };
}

describe('analytics gating (UI-007 AC18)', () => {
  const live = 'mekasa.web.app';

  it('collects only on live hosts with a measurement ID, outside mock mode, unless opted out', () => {
    expect(collectionAllowed(live, 'G-TEST', false, false)).toBe(true);
    expect(collectionAllowed('localhost', 'G-TEST', false, false)).toBe(false);
    expect(collectionAllowed('mekasa--pr-12-abc.web.app', 'G-TEST', false, false)).toBe(false);
    expect(collectionAllowed(live, '', false, false)).toBe(false);
    expect(collectionAllowed(live, 'G-TEST', true, false)).toBe(false);
    expect(collectionAllowed(live, 'G-TEST', false, true)).toBe(false);
  });

  it('reads the opt-out flag from storage', () => {
    expect(optedOut({ getItem: () => 'off' })).toBe(true);
    expect(optedOut({ getItem: () => null })).toBe(false);
  });

  it('hashes the uid the same way as the backend user_ref', async () => {
    const expected = createHash('sha256').update('owner-1').digest('hex').slice(0, 12);
    expect(await hashedUserRef('owner-1')).toBe(expected);
  });
});

describe('analytics singleton', () => {
  afterEach(() => {
    analytics.setOptedOut(false, { setItem: () => undefined });
    analytics.useSink(null);
  });

  it('sends events and a hashed user id, never the raw uid', async () => {
    const { sink, calls } = recordingSink();
    analytics.useSink(sink);
    analytics.page('inventory');
    analytics.track('item_added', { source: 'receipt' });
    await analytics.identify('owner-1', { role: 'owner', theme: '' });
    expect(calls[0]).toEqual({ kind: 'event', args: ['page_view', { page_title: 'inventory', screen_name: 'inventory' }] });
    expect(calls[1]).toEqual({ kind: 'event', args: ['item_added', { source: 'receipt' }] });
    expect(calls[2].args[0]).toHaveLength(12);
    expect(calls[2].args[0]).not.toBe('owner-1');
    expect(calls[3]).toEqual({ kind: 'userProperties', args: [{ role: 'owner' }] });
  });

  it('stops sending as soon as the user opts out', () => {
    const { sink, calls } = recordingSink();
    const stored: Record<string, string> = {};
    analytics.useSink(sink);
    analytics.setOptedOut(true, { setItem: (k, v) => void (stored[k] = v) });
    analytics.track('receipt_saved', { lines: 3 });
    analytics.page('dashboard');
    expect(stored['mekasa.analytics']).toBe('off');
    expect(calls).toEqual([{ kind: 'enabled', args: [false] }]);
  });
});
