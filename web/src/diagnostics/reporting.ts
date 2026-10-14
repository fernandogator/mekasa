/**
 * Uploads error reports and diagnostics for platform `web`.
 *
 * Satisfies: UI-007 (Desktop Web App) AC15; NFR-007 AC2–AC5
 */

import { apiRequest } from '../api/client';
import { appBuild, appVersion, mockAuth } from '../config';
import { appLog, type ErrorReport } from './appLog';

export function browserInfo(userAgent: string = navigator.userAgent): { os_version: string; device_model: string } {
  const browser = /Edg\/(\d+)/.exec(userAgent)
    ? `Edge ${/Edg\/(\d+)/.exec(userAgent)?.[1]}`
    : /Firefox\/(\d+)/.exec(userAgent)
      ? `Firefox ${/Firefox\/(\d+)/.exec(userAgent)?.[1]}`
      : /Chrome\/(\d+)/.exec(userAgent)
        ? `Chrome ${/Chrome\/(\d+)/.exec(userAgent)?.[1]}`
        : /Version\/(\d+).*Safari/.exec(userAgent)
          ? `Safari ${/Version\/(\d+)/.exec(userAgent)?.[1]}`
          : 'Browser';
  const os = /Windows/.test(userAgent) ? 'Windows' : /Mac OS X/.test(userAgent) ? 'macOS' : /Linux/.test(userAgent) ? 'Linux' : '';
  return { os_version: os, device_model: browser };
}

function appInfo() {
  return { platform: 'web' as const, app_version: appVersion, build: appBuild, ...browserInfo() };
}

async function sendReports(reports: ErrorReport[]): Promise<boolean> {
  try {
    await apiRequest('/v1/client-errors', { method: 'POST', body: { app: appInfo(), reports }, quiet: true });
    return true;
  } catch {
    return false;
  }
}

/** Starts automatic error reports for a signed-in, non-mock session. */
export function startErrorReports(): () => void {
  if (mockAuth) return () => {};
  appLog.reportsEnabled = true;
  appLog.setSender(sendReports);
  const onVisible = () => document.visibilityState === 'visible' && appLog.scheduleFlush(0);
  document.addEventListener('visibilitychange', onVisible);
  return () => {
    document.removeEventListener('visibilitychange', onVisible);
    appLog.setSender(null);
    appLog.reportsEnabled = false;
  };
}

/** Uploads the recent log; returns the support reference (NFR-007 AC4–AC5). */
export async function sendDiagnostics(note?: string): Promise<string> {
  const result = await apiRequest<{ reference: string }>('/v1/client-diagnostics', {
    method: 'POST',
    body: { app: appInfo(), note: note ?? null, entries: appLog.recent() },
    quiet: true,
  });
  return result.reference;
}
