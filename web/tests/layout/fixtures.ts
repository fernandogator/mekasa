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

export const household = { id: H, name: 'The Rodriguez Home', photo_url: null, owner_uid: 'owner-1', created_at: now, updated_at: now };

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

export const shopping = [
  { id: 'sh-1', household_id: H, name: 'Whole Milk', quantity: 2, is_checked: false, needs_approval: false, inventory_item_id: 'inv-1', kind: 'auto', created_by_uid: 'owner-1', created_at: now, updated_at: now },
  { id: 'sh-2', household_id: H, name: 'Paper Towels', quantity: 1, is_checked: false, needs_approval: false, inventory_item_id: 'inv-7', kind: 'auto', created_by_uid: 'owner-1', created_at: now, updated_at: now },
  { id: 'sh-3', household_id: H, name: 'Ice Cream', quantity: 1, is_checked: false, needs_approval: true, requested_by: 'Maya Rodriguez', kind: 'request', created_by_uid: 'teen-1', created_at: now, updated_at: now },
  { id: 'sh-4', household_id: H, name: 'Bananas', quantity: 6, is_checked: false, needs_approval: false, kind: 'custom', created_by_uid: 'owner-1', created_at: now, updated_at: now },
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
    if (path === '/v1/households/current') return json(route, household);
    if (path.endsWith('/members')) return json(route, { members });
    if (path.endsWith('/invites')) return json(route, { invites });
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
