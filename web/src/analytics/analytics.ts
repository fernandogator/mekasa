/**
 * Usage analytics through Firebase Analytics (GA4).
 *
 * Satisfies: UI-007 (Desktop Web App)
 * Acceptance criteria: AC18
 *
 * Collects only on the live hosts with a measurement ID, never in mock or
 * preview builds, and stops as soon as the user turns it off in Settings.
 * Callers pass only the whitelisted events and parameters below; names,
 * emails, item names, receipt text, barcodes and prices are never sent.
 */

import { firebaseConfig, liveHosts, mockAuth } from '../config';

export type ScreenName =
  | 'dashboard'
  | 'inventory'
  | 'item_detail'
  | 'shopping_list'
  | 'spending'
  | 'members'
  | 'settings'
  | 'sign_in';

export type AnalyticsEvent =
  | { name: 'login'; params: { method: 'google' | 'password' } }
  | {
      name: 'receipt_scan';
      params: { input: 'image' | 'text'; lines: number; identified: number; duration_ms: number; outcome: 'ok' | 'failed' | 'cancelled' };
    }
  | { name: 'receipt_saved'; params: { lines: number } }
  | { name: 'item_added'; params: { source: 'manual' | 'receipt' } }
  | { name: 'shopping_item_added'; params: Record<string, never> }
  | { name: 'shopping_request_approved'; params: Record<string, never> }
  | { name: 'shopping_request_rejected'; params: Record<string, never> }
  | { name: 'shopping_item_purchased'; params: Record<string, never> }
  | { name: 'invite_sent'; params: { role: 'owner' | 'teen' | 'member' } }
  | { name: 'theme_changed'; params: { theme: string } }
  | { name: 'stores_saved'; params: { count: number } };

export interface AnalyticsSink {
  event(name: string, params: Record<string, unknown>): void;
  userId(id: string | null): void;
  userProperties(props: Record<string, string>): void;
  enabled(on: boolean): void;
}

const OPT_OUT_KEY = 'mekasa.analytics';

export function optedOut(storage: Pick<Storage, 'getItem'> = localStorage): boolean {
  return storage.getItem(OPT_OUT_KEY) === 'off';
}

export function collectionAllowed(host: string, measurementId: string, isMock: boolean, isOptedOut: boolean): boolean {
  return !isMock && Boolean(measurementId) && liveHosts.includes(host) && !isOptedOut;
}

export async function hashedUserRef(uid: string): Promise<string> {
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(uid));
  return Array.from(new Uint8Array(bytes))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
    .slice(0, 12);
}

class Analytics {
  private sink: AnalyticsSink | null = null;
  private loading: Promise<void> | null = null;
  private off = false;

  /** Test hook: route events to `sink` regardless of host. */
  useSink(sink: AnalyticsSink | null): void {
    this.sink = sink;
  }

  start(): Promise<void> {
    if (this.sink || this.loading) return this.loading ?? Promise.resolve();
    if (!collectionAllowed(location.hostname, firebaseConfig.measurementId, mockAuth, optedOut())) return Promise.resolve();
    this.loading = this.loadFirebase().catch(() => {
      this.sink = null;
    });
    return this.loading;
  }

  private async loadFirebase(): Promise<void> {
    const mod = await import('firebase/analytics');
    if (!(await mod.isSupported())) return;
    const { firebaseApp } = await import('../firebase');
    const instance = mod.initializeAnalytics(firebaseApp(), {
      config: { send_page_view: false, allow_google_signals: false, allow_ad_personalization_signals: false },
    });
    this.sink = {
      event: (name, params) => mod.logEvent(instance, name, params),
      userId: (id) => mod.setUserId(instance, id),
      userProperties: (props) => mod.setUserProperties(instance, props),
      enabled: (on) => mod.setAnalyticsCollectionEnabled(instance, on),
    };
  }

  track<E extends AnalyticsEvent>(name: E['name'], params: E['params']): void {
    if (!this.off) this.sink?.event(name, params as Record<string, unknown>);
  }

  page(screen: ScreenName): void {
    if (!this.off) this.sink?.event('page_view', { page_title: screen, screen_name: screen });
  }

  async identify(uid: string | null, props: { role?: string; theme?: string } = {}): Promise<void> {
    if (!this.sink || this.off) return;
    this.sink.userId(uid ? await hashedUserRef(uid) : null);
    const clean = Object.fromEntries(Object.entries(props).filter(([, v]) => v)) as Record<string, string>;
    if (Object.keys(clean).length) this.sink.userProperties(clean);
  }

  setOptedOut(off: boolean, storage: Pick<Storage, 'setItem'> = localStorage): void {
    storage.setItem(OPT_OUT_KEY, off ? 'off' : 'on');
    this.off = off;
    this.sink?.enabled(!off);
    if (!off) void this.start();
  }
}

export const analytics = new Analytics();
