import { appLog, type ErrorReport, maskEmails } from './appLog';

describe('appLog (UI-007 AC15, NFR-007)', () => {
  beforeEach(() => {
    appLog.setSender(null);
    appLog.reset();
    appLog.reportsEnabled = true;
  });

  it('masks email addresses', () => {
    expect(maskEmails('login failed for ana.p@example.com')).toBe('login failed for [email]');
  });

  it('keeps the newest 500 entries', () => {
    for (let i = 0; i < 520; i++) appLog.info('test', `entry ${i}`);
    const entries = appLog.recent();
    expect(entries).toHaveLength(500);
    expect(entries[0].message).toBe('entry 20');
  });

  it('queues error reports with breadcrumbs and persists them', () => {
    appLog.info('nav', 'opened inventory');
    appLog.error('inventory.load', new TypeError('bad json from x@y.io'), { status: 500, path: '/v1/households/h/inventory' });
    const [report] = appLog.pendingReports();
    expect(report.error_type).toBe('TypeError');
    expect(report.message).toBe('bad json from [email]');
    expect(report.breadcrumbs.map((b) => b.message)).toEqual(['opened inventory']);
    expect(JSON.parse(localStorage.getItem('mekasa.errorQueue') ?? '[]')).toHaveLength(1);
  });

  it('caps the queue at 50 reports', () => {
    for (let i = 0; i < 60; i++) appLog.error('loop', new Error(`e${i}`));
    const queue = appLog.pendingReports();
    expect(queue).toHaveLength(50);
    expect(queue[0].message).toBe('e10');
  });

  it('sends in batches of 20 and keeps reports when a send fails', async () => {
    for (let i = 0; i < 45; i++) appLog.error('loop', new Error(`e${i}`));
    const batches: number[] = [];
    let fail = false;
    const sender = vi.fn(async (reports: ErrorReport[]) => {
      batches.push(reports.length);
      return !fail;
    });
    appLog.setSender(sender);
    await appLog.flush();
    expect(batches).toEqual([20, 20, 5]);
    expect(appLog.pendingReports()).toHaveLength(0);

    appLog.error('later', new Error('x'));
    fail = true;
    await appLog.flush();
    expect(appLog.pendingReports()).toHaveLength(1);
  });

  it('does not queue reports until reports are enabled', () => {
    appLog.reportsEnabled = false;
    appLog.error('mock', new Error('x'));
    expect(appLog.pendingReports()).toHaveLength(0);
  });
});
