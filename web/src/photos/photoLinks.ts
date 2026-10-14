/**
 * Resolves API photo paths to signed links in batches (REQ-023, UI-007 AC12).
 *
 * Satisfies: UI-007 (Desktop Web App)
 * Acceptance criteria: AC12
 *
 * `<img>` cannot send the bearer token, so item and product photo paths are
 * exchanged for signed Cloud Storage links. Requests made in the same tick
 * share one call (up to 100 paths). A link is reused until 5 minutes before
 * it expires. Local API runs return the path itself; those are fetched with
 * the token and shown from an object URL.
 */

import { fetchImageBlob } from '../api/client';
import { api } from '../api/endpoints';
import type { PhotoLink } from '../api/types';

const API_PHOTO = /^\/v1\/(?:households\/[^/]+\/item-photos|product-photos)\/[0-9a-fA-F-]{36}$/;
const BATCH = 100;
const REFRESH_MARGIN_MS = 5 * 60 * 1000;

export type PhotoSource = { kind: 'none' } | { kind: 'placeholder' } | { kind: 'direct'; url: string } | { kind: 'api'; path: string };

export function classifyPhoto(url: string | null | undefined): PhotoSource {
  if (!url) return { kind: 'none' };
  if (url.startsWith('data:')) return { kind: 'direct', url };
  let path = url;
  if (/^https?:\/\//.test(url)) {
    try {
      const parsed = new URL(url);
      if (parsed.hostname === 'placehold.co') return { kind: 'placeholder' };
      path = parsed.pathname;
    } catch {
      return { kind: 'none' };
    }
  }
  if (API_PHOTO.test(path)) return { kind: 'api', path };
  return /^https:\/\//.test(url) ? { kind: 'direct', url } : { kind: 'none' };
}

interface Cached {
  url: string | null;
  expiresAt: number | null;
}

type Waiter = { resolve: (url: string | null) => void; reject: (error: unknown) => void };

export class PhotoLinkResolver {
  private cache = new Map<string, Cached>();
  private pending = new Map<string, Waiter[]>();
  private timer: ReturnType<typeof setTimeout> | null = null;

  constructor(
    private householdId: string,
    private fetchLinks: (householdId: string, paths: string[]) => Promise<Record<string, PhotoLink | null>> = api.photoLinks,
    private fetchBlob: (path: string) => Promise<Blob> = fetchImageBlob,
    private now: () => number = Date.now,
  ) {}

  resolve(path: string): Promise<string | null> {
    const cached = this.cache.get(path);
    if (cached && (cached.expiresAt === null || cached.expiresAt - this.now() > REFRESH_MARGIN_MS)) {
      return Promise.resolve(cached.url);
    }
    return new Promise((resolve, reject) => {
      const waiters = this.pending.get(path) ?? [];
      waiters.push({ resolve, reject });
      this.pending.set(path, waiters);
      this.timer ??= setTimeout(() => void this.flush(), 0);
    });
  }

  private async flush(): Promise<void> {
    this.timer = null;
    const batch = new Map(this.pending);
    this.pending.clear();
    const paths = [...batch.keys()];
    for (let start = 0; start < paths.length; start += BATCH) {
      const chunk = paths.slice(start, start + BATCH);
      try {
        const links = await this.fetchLinks(this.householdId, chunk);
        for (const path of chunk) {
          const link = links[path] ?? null;
          const url = link ? await this.browserUrl(path, link) : null;
          this.cache.set(path, { url, expiresAt: link?.expires_at ? Date.parse(link.expires_at) : null });
          batch.get(path)?.forEach((waiter) => waiter.resolve(url));
        }
      } catch (error) {
        chunk.forEach((path) => batch.get(path)?.forEach((waiter) => waiter.reject(error)));
      }
    }
  }

  private async browserUrl(path: string, link: PhotoLink): Promise<string | null> {
    if (link.url !== path) return link.url;
    try {
      return URL.createObjectURL(await this.fetchBlob(path));
    } catch {
      return null;
    }
  }
}
