import type { PhotoLink } from '../api/types';
import { classifyPhoto, PhotoLinkResolver } from './photoLinks';

const ITEM = '/v1/households/h1/item-photos/11111111-2222-3333-4444-555555555555';
const PRODUCT = '/v1/product-photos/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

describe('classifyPhoto (UI-007 AC12)', () => {
  it('sorts URLs into the ways the app can show them', () => {
    expect(classifyPhoto(null)).toEqual({ kind: 'none' });
    expect(classifyPhoto('data:image/png;base64,AA')).toEqual({ kind: 'direct', url: 'data:image/png;base64,AA' });
    expect(classifyPhoto('https://placehold.co/200x200?text=Milk')).toEqual({ kind: 'placeholder' });
    expect(classifyPhoto(ITEM)).toEqual({ kind: 'api', path: ITEM });
    expect(classifyPhoto(`https://mekasa-api.run.app${PRODUCT}`)).toEqual({ kind: 'api', path: PRODUCT });
    expect(classifyPhoto('https://images.openfoodfacts.org/x.jpg')).toEqual({ kind: 'direct', url: 'https://images.openfoodfacts.org/x.jpg' });
    expect(classifyPhoto('http://insecure.example/x.jpg')).toEqual({ kind: 'none' });
  });
});

describe('PhotoLinkResolver (REQ-023 AC1, UI-007 AC12)', () => {
  const tick = () => new Promise((resolve) => setTimeout(resolve, 0));

  it('batches same-tick requests into one call and reuses fresh links', async () => {
    const expires = new Date(Date.now() + 60 * 60 * 1000).toISOString();
    const fetchLinks = vi.fn(async (_h: string, paths: string[]) =>
      Object.fromEntries(paths.map((p) => [p, { url: `https://storage.googleapis.com/signed${p}`, expires_at: expires } as PhotoLink])),
    );
    const resolver = new PhotoLinkResolver('h1', fetchLinks, vi.fn());
    const [a, b] = await Promise.all([resolver.resolve(ITEM), resolver.resolve(PRODUCT)]);
    expect(fetchLinks).toHaveBeenCalledTimes(1);
    expect(fetchLinks.mock.calls[0][1]).toEqual([ITEM, PRODUCT]);
    expect(a).toContain('signed');
    expect(b).toContain('signed');
    await resolver.resolve(ITEM);
    expect(fetchLinks).toHaveBeenCalledTimes(1);
  });

  it('asks again once a link is within 5 minutes of expiry', async () => {
    let now = Date.parse('2026-10-13T12:00:00Z');
    const fetchLinks = vi.fn(async () => ({ [ITEM]: { url: 'https://signed/x', expires_at: '2026-10-13T12:10:00Z' } }));
    const resolver = new PhotoLinkResolver('h1', fetchLinks, vi.fn(), () => now);
    await resolver.resolve(ITEM);
    await resolver.resolve(ITEM);
    expect(fetchLinks).toHaveBeenCalledTimes(1);
    now += 6 * 60 * 1000;
    await resolver.resolve(ITEM);
    expect(fetchLinks).toHaveBeenCalledTimes(2);
  });

  it('splits more than 100 paths into several calls', async () => {
    const fetchLinks = vi.fn(async (_h: string, paths: string[]) => Object.fromEntries(paths.map((p) => [p, null])));
    const resolver = new PhotoLinkResolver('h1', fetchLinks, vi.fn());
    const paths = Array.from({ length: 150 }, (_, i) => `/v1/product-photos/00000000-0000-0000-0000-${String(i).padStart(12, '0')}`);
    const urls = await Promise.all(paths.map((p) => resolver.resolve(p)));
    expect(fetchLinks.mock.calls.map((call) => call[1].length)).toEqual([100, 50]);
    expect(urls.every((url) => url === null)).toBe(true);
  });

  it('fetches with the token when the server returns the path itself (no GCS)', async () => {
    const createObjectURL = vi.fn(() => 'blob:local');
    URL.createObjectURL = createObjectURL;
    const fetchBlob = vi.fn(async () => new Blob(['x']));
    const resolver = new PhotoLinkResolver('h1', async () => ({ [ITEM]: { url: ITEM, expires_at: null } }), fetchBlob);
    expect(await resolver.resolve(ITEM)).toBe('blob:local');
    expect(fetchBlob).toHaveBeenCalledWith(ITEM);
  });

  it('rejects every waiter in a batch when the call fails', async () => {
    const resolver = new PhotoLinkResolver('h1', async () => Promise.reject(new Error('offline')), vi.fn());
    const results = Promise.allSettled([resolver.resolve(ITEM), resolver.resolve(PRODUCT)]);
    await tick();
    expect((await results).map((r) => r.status)).toEqual(['rejected', 'rejected']);
  });
});
