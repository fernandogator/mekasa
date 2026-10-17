import type { Household, InventoryItem, Member, PurchaseEvent, ReceiptLine, ShoppingItem } from '../api/types';
import { contributions, trendBuckets } from '../pages/Spending';
import { groupShopping } from '../pages/ShoppingList';
import { scaledSize, validateReceiptFile } from '../receipt/image';
import { summary } from '../receipt/ReceiptDialog';
import { filterInventory, isLowStock } from './data';
import { roleFor } from './HouseholdProvider';

function item(over: Partial<InventoryItem>): InventoryItem {
  return {
    id: over.name ?? 'id',
    household_id: 'h1',
    name: 'Milk',
    category: 'Dairy',
    quantity: 2,
    low_stock_threshold: 1,
    source: 'manual',
    created_at: '2026-10-01T00:00:00Z',
    updated_at: '2026-10-01T00:00:00Z',
    ...over,
  };
}

function shopping(over: Partial<ShoppingItem>): ShoppingItem {
  return {
    id: over.name ?? 'id',
    household_id: 'h1',
    name: 'Milk',
    quantity: 1,
    is_checked: false,
    needs_approval: false,
    kind: 'custom',
    created_by_uid: 'owner-1',
    created_at: '2026-10-01T00:00:00Z',
    updated_at: '2026-10-01T00:00:00Z',
    ...over,
  };
}

function member(uid: string, role: Member['role'], name: string): Member {
  return { uid, household_id: 'h1', name, role, status: 'active', created_at: '2026-01-01T00:00:00Z' };
}

describe('filterInventory (UI-007 AC6)', () => {
  const items = [
    item({ name: 'Milk', category: 'Dairy', quantity: 1, created_at: '2026-10-03T00:00:00Z' }),
    item({ name: 'Apples', category: 'Produce', quantity: 6, created_at: '2026-10-01T00:00:00Z' }),
    item({ name: 'Bread', category: 'Pantry', quantity: 0, created_at: '2026-10-02T00:00:00Z' }),
    item({ name: 'Gone', deleted: true }),
  ];

  it('drops deleted items and sorts newest first by default', () => {
    expect(filterInventory(items, '', null, 'newest').map((i) => i.name)).toEqual(['Milk', 'Bread', 'Apples']);
  });

  it('searches name and category, and filters by category chip', () => {
    expect(filterInventory(items, 'prod', null, 'name').map((i) => i.name)).toEqual(['Apples']);
    expect(filterInventory(items, ' MILK ', null, 'name').map((i) => i.name)).toEqual(['Milk']);
    expect(filterInventory(items, '', 'Pantry', 'name').map((i) => i.name)).toEqual(['Bread']);
  });

  it('sorts by how close each item is to its low-stock threshold', () => {
    expect(filterInventory(items, '', null, 'quantity').map((i) => i.name)).toEqual(['Bread', 'Milk', 'Apples']);
    expect(isLowStock(items[0])).toBe(true);
    expect(isLowStock(items[1])).toBe(false);
  });
});

describe('groupShopping (UI-007 AC7)', () => {
  const inventory = [item({ id: 'inv-milk', name: 'Milk', category: 'Dairy' })];
  const list = [
    shopping({ name: 'Milk', inventory_item_id: 'inv-milk', created_at: '2026-10-02T00:00:00Z' }),
    shopping({ name: 'Batteries', requested_by: 'Leo', created_at: '2026-10-03T00:00:00Z' }),
    shopping({ name: 'Apples', created_at: '2026-10-01T00:00:00Z' }),
  ];

  it('groups by the linked inventory category, falling back to Other', () => {
    expect(groupShopping(list, inventory, 'category').map(([k, rows]) => [k, rows.map((r) => r.name)])).toEqual([
      ['Dairy', ['Milk']],
      ['Other', ['Apples', 'Batteries']],
    ]);
  });

  it('groups by requester and lists by date', () => {
    expect(groupShopping(list, inventory, 'requester').map(([k]) => k)).toEqual(['Household', 'Leo']);
    expect(groupShopping(list, inventory, 'date')[0][1].map((r) => r.name)).toEqual(['Batteries', 'Milk', 'Apples']);
  });
});

describe('spending helpers (UI-007 AC8)', () => {
  const event = (uid: string, price: number, at: string): PurchaseEvent => ({
    id: `${uid}-${at}`,
    name: 'x',
    category: 'Dairy',
    price_paid: price,
    quantity: 1,
    purchased_at: at,
    created_by_uid: uid,
  });
  const events = [event('owner-1', 4.5, '2026-10-05T12:00:00'), event('teen-1', 2.25, '2026-10-05T15:00:00'), event('owner-1', 10, '2026-10-29T12:00:00')];

  it('buckets the trend by month week and by month of the year', () => {
    const month = trendBuckets(events, 'month');
    expect(month.map((b) => b.total)).toEqual([6.75, 0, 0, 0, 10]);
    const year = trendBuckets(events, 'year');
    expect(year[9]).toEqual({ label: 'Oct', total: 16.75 });
  });

  it('totals contribution per member, biggest first', () => {
    const rows = contributions(events, [member('owner-1', 'owner', 'Ana'), member('teen-1', 'teen', 'Leo')]);
    expect(rows).toEqual([
      { uid: 'owner-1', name: 'Ana', total: 14.5 },
      { uid: 'teen-1', name: 'Leo', total: 2.25 },
    ]);
    expect(contributions([event('gone', 1, '2026-10-01T00:00:00')], [])[0].name).toBe('Household member');
  });
});

describe('roleFor (UI-007 AC2)', () => {
  const household = { id: 'h1', owner_uid: 'owner-1' } as Household;
  it('treats the household owner as owner and others by membership', () => {
    const members = [member('teen-1', 'teen', 'Leo')];
    expect(roleFor(household, members, 'owner-1')).toBe('owner');
    expect(roleFor(household, members, 'teen-1')).toBe('teen');
    expect(roleFor(household, members, 'stranger')).toBe('member');
  });
});

describe('receipt helpers (UI-007 AC10)', () => {
  it('accepts JPEG, PNG and WebP up to 10 MB', () => {
    expect(validateReceiptFile({ type: 'image/jpeg', size: 1000 })).toBeNull();
    expect(validateReceiptFile({ type: 'image/heic', size: 1000 })).toMatch(/JPEG, PNG or WebP/);
    expect(validateReceiptFile({ type: 'image/png', size: 11 * 1024 * 1024 })).toMatch(/10 MB/);
  });

  it('scales the long edge down to 2048 px and never up', () => {
    expect(scaledSize(4032, 3024)).toEqual({ width: 2048, height: 1536 });
    expect(scaledSize(1000, 3000)).toEqual({ width: 683, height: 2048 });
    expect(scaledSize(800, 600)).toEqual({ width: 800, height: 600 });
  });

  it('summarises matched and unmatched lines', () => {
    const line = (identified: boolean): ReceiptLine => ({ name: 'x', category: 'Other', quantity: 1, identified });
    expect(summary([line(true), line(false), line(true)], 'Kroger')).toBe('Kroger · 3 lines · 2 matched · 1 need review');
    expect(summary([line(true)])).toBe('1 line · 1 matched');
  });
});
