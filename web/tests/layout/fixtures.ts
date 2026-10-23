import type { Page, Route } from '@playwright/test';

const H = 'hh-rodriguez';
const now = '2026-10-13T15:00:00Z';

const item = (id: string, name: string, category: string, quantity: number, threshold: number, extra: Record<string, unknown> = {}) => ({
  id,
  household_id: H,
  name,
  category,
  quantity,
  low_stock_threshold: threshold,
  source: 'manual',
  created_at: `2026-10-${String(10 - Number(id.slice(-1))).padStart(2, '0')}T12:00:00Z`,
  updated_at: now,
  ...extra,
});

export const savedStores = [
  { id: 'place-costco', name: 'Costco Wholesale', address: '4301 W William Cannon Dr, Austin', distance_miles: 6.2 },
  { id: 'place-heb', name: 'H-E-B', address: '5808 Burnet Rd, Austin', distance_miles: 1.4 },
];

export const nearbyStores = [
  ...savedStores,
  { id: 'place-target', name: 'Target', address: '8601 Research Blvd, Austin', distance_miles: 3.8 },
  { id: 'place-wfm', name: 'Whole Foods Market', address: '525 N Lamar Blvd, Austin', distance_miles: 4.9 },
  { id: 'place-walmart', name: 'Walmart Supercenter', address: '9300 S IH-35, Austin', distance_miles: 11.3 },
].map((store) => ({ ...store, latitude: 30.3, longitude: -97.7, provider: 'places' }));

export const household = {
  id: H,
  name: 'The Rodriguez Home',
  photo_url: null,
  owner_uid: 'owner-1',
  address: '2100 Elm St, Austin, TX',
  latitude: 30.31,
  longitude: -97.74,
  store_ids: savedStores.map((store) => store.id),
  stores: savedStores,
  created_at: now,
  updated_at: now,
};

export const members = [
  { uid: 'owner-1', household_id: H, name: 'Leo Rodriguez', email: 'leo@example.com', role: 'owner', status: 'active', created_at: now },
  { uid: 'teen-1', household_id: H, name: 'Maya Rodriguez', email: 'maya@example.com', role: 'teen', status: 'active', created_at: now },
  { uid: 'member-1', household_id: H, name: 'Sofia Rodriguez', email: 'sofia@example.com', role: 'member', status: 'active', created_at: now },
];

export const inventory = [
  item('inv-1', 'Whole Milk', 'Dairy', 1, 2, { barcode: '041303001486', price_paid: 4.29, health: { grade: 'B', allergens: ['milk'] } }),
  item('inv-2', 'Honeycrisp Apples', 'Produce', 6, 2),
  item('inv-3', 'Sourdough Bread', 'Pantry', 0, 1),
  item('inv-4', 'Chicken Thighs', 'Meat', 2, 1),
  item('inv-5', 'Frozen Peas', 'Frozen', 3, 1),
  item('inv-6', 'Sparkling Water', 'Beverages', 12, 6),
  item('inv-7', 'Paper Towels', 'Household', 1, 2),
  item('inv-8', 'Greek Yogurt', 'Dairy', 4, 2),
];

/** REQ-INV-021: two groups for the Duplicates review (UI-007 AC21). */
export const duplicates = [
  {
    reason: 'same_barcode',
    keep_id: 'inv-1',
    items: [inventory[0], item('dup-1', 'Whole Milk 1 gal', 'Dairy', 2, 1, { barcode: '041303001486' })],
  },
  {
    reason: 'same_name',
    keep_id: 'inv-2',
    items: [item('dup-2', 'Honeycrisp apple', 'Produce', 2, 1), inventory[1]],
  },
];

export const shopping = [
  { id: 'sh-1', household_id: H, name: 'Whole Milk', quantity: 2, is_checked: false, needs_approval: false, inventory_item_id: 'inv-1', store_id: 'place-heb', kind: 'auto', created_by_uid: 'owner-1', created_at: now, updated_at: now },
  { id: 'sh-2', household_id: H, name: 'Paper Towels', quantity: 1, is_checked: false, needs_approval: false, inventory_item_id: 'inv-7', store_id: 'place-costco', kind: 'auto', created_by_uid: 'owner-1', created_at: now, updated_at: now },
  { id: 'sh-3', household_id: H, name: 'Ice Cream', quantity: 1, is_checked: false, needs_approval: true, requested_by: 'Maya Rodriguez', kind: 'request', created_by_uid: 'teen-1', created_at: now, updated_at: now },
  { id: 'sh-4', household_id: H, name: 'Bananas', quantity: 6, is_checked: false, needs_approval: false, store_id: 'place-heb', kind: 'custom', created_by_uid: 'owner-1', created_at: now, updated_at: now },
];

const purchase = (id: string, name: string, category: string, price: number, day: number, uid: string) => ({
  id,
  name,
  category,
  price_paid: price,
  quantity: 1,
  purchased_at: `2026-10-${String(day).padStart(2, '0')}T17:00:00Z`,
  created_by_uid: uid,
});

const events = [
  purchase('p1', 'Whole Milk', 'Dairy', 4.29, 2, 'owner-1'),
  purchase('p2', 'Chicken Thighs', 'Meat', 12.5, 3, 'owner-1'),
  purchase('p3', 'Apples', 'Produce', 6.4, 8, 'member-1'),
  purchase('p4', 'Paper Towels', 'Household', 9.99, 9, 'owner-1'),
  purchase('p5', 'Sparkling Water', 'Beverages', 5.49, 11, 'teen-1'),
  purchase('p6', 'Frozen Peas', 'Frozen', 2.99, 12, 'member-1'),
];

export const spending = {
  household_id: H,
  period: 'month',
  currency: 'USD',
  total: 41.66,
  by_category: [
    { category: 'Meat', total: 12.5 },
    { category: 'Household', total: 9.99 },
    { category: 'Produce', total: 6.4 },
    { category: 'Beverages', total: 5.49 },
    { category: 'Dairy', total: 4.29 },
    { category: 'Frozen', total: 2.99 },
  ],
  events,
};

export const invites = [{ id: 'inv-a', name: 'Grandma Rosa', email: null, role: 'member', status: 'pending', created_at: now, invite_link: 'https://hackathon2025-472017.web.app/join/abc' }];

export const receipt = {
  household_id: H,
  engine: 'gemini',
  store_name: 'H-E-B',
  items: [
    { name: 'Whole Milk', category: 'Dairy', quantity: 1, price_paid: 4.29, barcode: '041303001486', identified: true, receipt_text: 'HEB WHL MILK GAL' },
    { name: 'Bananas', category: 'Produce', quantity: 1, price_paid: 1.62, identified: true, receipt_text: 'BANANAS 2.7LB' },
    { name: 'KRNCH MIX 12OZ', category: 'Other', quantity: 1, price_paid: 3.98, identified: false, receipt_text: 'KRNCH MIX 12OZ' },
  ],
};

const json = (route: Route, body: unknown, status = 200) => route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });

export interface FixtureOptions {
  uid?: 'owner-1' | 'teen-1';
  signedOut?: boolean;
  empty?: boolean;
  failMembers?: boolean;
  /** Household with no address and no saved stores. */
  noStores?: boolean;
  /** Household saved before store details were kept: bare placeholder IDs, no details. */
  legacyStoreIds?: boolean;
  /** The duplicates search finds nothing. */
  noDuplicates?: boolean;
}

/** Answers every API call the app makes from in-memory fixtures. */
export async function useFixtures(page: Page, options: FixtureOptions = {}): Promise<void> {
  const uid = options.uid ?? 'owner-1';
  await page.addInitScript(
    ([mockUid, lastEmail]) => {
      localStorage.setItem('mekasa.mockUid', mockUid);
      localStorage.setItem('mekasa.theme', 'grounded');
      if (lastEmail) localStorage.setItem('mekasa.lastEmail', lastEmail);
    },
    [uid, options.signedOut ? 'leo@example.com' : ''] as const,
  );
  await page.route('**/v1/**', async (route) => {
    const url = new URL(route.request().url());
    const path = url.pathname;
    const method = route.request().method();
    if (options.signedOut) return json(route, { detail: 'expired' }, 401);
    if (path === '/v1/me') return json(route, { uid, email: `${uid}@example.com`, name: null });
    const home = options.noStores
      ? { ...household, address: null, latitude: null, longitude: null, store_ids: [], stores: [] }
      : options.legacyStoreIds
        ? { ...household, store_ids: ['stub-heb', 'stub-costco', 'stub-walmart'], stores: [] }
        : household;
    if (path === '/v1/households/current') return json(route, home);
    if (path.endsWith('/stores/nearby')) return json(route, { household_id: H, radius_miles: 15, stores: nearbyStores });
    if (path.endsWith('/stores') && method === 'PUT') {
      const body = route.request().postDataJSON() as { store_ids: string[]; stores: unknown[] };
      return json(route, { ...home, store_ids: body.store_ids, stores: body.stores });
    }
    if (path.endsWith('/address') && method === 'PUT') {
      const body = route.request().postDataJSON() as { address: string };
      return json(route, { ...home, address: body.address, latitude: 30.31, longitude: -97.74 });
    }
    if (path.endsWith('/shopping-list') && method === 'POST') {
      const body = route.request().postDataJSON() as Record<string, unknown>;
      return json(route, { id: 'sh-new', household_id: H, is_checked: false, created_by_uid: uid, created_at: now, updated_at: now, ...body }, 201);
    }
    const row = path.match(/\/shopping-list\/([^/]+)$/);
    if (row && method === 'PATCH') {
      const found = shopping.find((entry) => entry.id === row[1]);
      return json(route, { ...found, ...(route.request().postDataJSON() as object) });
    }
    if (path.endsWith('/members')) return options.failMembers ? json(route, { detail: 'boom' }, 500) : json(route, { members });
    if (path.endsWith('/invites')) return json(route, { invites });
    if (path.endsWith('/inventory/duplicates')) return json(route, { household_id: H, groups: options.noDuplicates ? [] : duplicates });
    if (path.endsWith('/inventory/merge') && method === 'POST') {
      const ids = (route.request().postDataJSON() as { item_ids: string[] }).item_ids;
      const group = duplicates.find((entry) => entry.items.some((member) => ids.includes(member.id))) ?? duplicates[0];
      const keep = group.items.find((member) => member.id === group.keep_id) ?? group.items[0];
      const quantity = Math.max(...group.items.map((member) => member.quantity));
      return json(route, { household_id: H, item: { ...keep, quantity }, removed_ids: ids.filter((id) => id !== keep.id), shopping_list_items: [] });
    }
    if (path.endsWith('/inventory') && method === 'GET') return json(route, { items: options.empty ? [] : inventory });
    if (path.endsWith('/shopping-list') && method === 'GET') return json(route, { items: options.empty ? [] : shopping });
    if (path.endsWith('/spending')) return json(route, options.empty ? { ...spending, total: 0, by_category: [], events: [] } : spending);
    if (path.endsWith('/photo-links')) {
      const photos = (route.request().postDataJSON() as { photos: string[] }).photos;
      return json(route, { links: Object.fromEntries(photos.map((p) => [p, null])) });
    }
    if (path.endsWith('/receipts/scan')) return json(route, receipt);
    if (path.startsWith('/v1/products/search')) return json(route, { results: [] });
    if (path.startsWith('/v1/client-')) return json(route, { accepted: 0 });
    return json(route, { detail: `no fixture for ${method} ${path}` }, 404);
  });
}
