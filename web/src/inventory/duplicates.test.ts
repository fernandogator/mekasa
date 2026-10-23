/**
 * Satisfies: UI-007 AC21 (REQ-INV-021 AC5, AC6)
 */

import type { DuplicateGroup, InventoryItem, InventoryMergeResult, ShoppingItem } from '../api/types';
import {
  applyMergeToInventory,
  applyMergeToShopping,
  groupSignature,
  loadHidden,
  mergedMessage,
  mergePreview,
  orderedItems,
  photoAge,
  REASON_LABELS,
  saveHidden,
  survivorOf,
  visibleGroups,
} from './duplicates';

function item(id: string, name: string, quantity: number, extra: Partial<InventoryItem> = {}): InventoryItem {
  return {
    id,
    household_id: 'hh-1',
    name,
    category: 'Produce',
    quantity,
    low_stock_threshold: 1,
    source: 'manual',
    created_at: '2026-10-01T00:00:00Z',
    updated_at: '2026-10-01T00:00:00Z',
    ...extra,
  };
}

const bananas = item('a', 'Organic Bananas', 1, { image_url: '/v1/product-photos/x', image_updated_at: '2026-10-20T12:00:00Z' });
const banana = item('b', 'Banana', 3);
const group: DuplicateGroup = { reason: 'same_name', keep_id: 'a', items: [banana, bananas] };

describe('duplicates review (UI-007 AC21)', () => {
  it('labels each reason', () => {
    expect(REASON_LABELS.same_barcode).toBe('Same barcode');
    expect(REASON_LABELS.same_product).toBe('Same product');
    expect(REASON_LABELS.same_name).toBe('Same name');
  });

  it('puts the survivor first', () => {
    expect(survivorOf(group).id).toBe('a');
    expect(orderedItems(group).map((row) => row.id)).toEqual(['a', 'b']);
  });

  it('previews the merge with the higher quantity and the newest photo', () => {
    expect(mergePreview(group)).toBe('Merges into Organic Bananas · keeps qty 3 (higher) · newest photo');
    const noPhoto: DuplicateGroup = { reason: 'same_barcode', keep_id: 'b', items: [banana, item('c', 'Banana', 2)] };
    expect(mergePreview(noPhoto)).toBe('Merges into Banana · keeps qty 3 · no photo');
  });

  it('confirms with the merged count and name', () => {
    expect(mergedMessage(2, 'Organic Bananas')).toBe('Merged 2 items into Organic Bananas');
  });

  it('describes photo age from image_updated_at, falling back to updated_at', () => {
    const now = new Date('2026-10-23T12:00:00Z');
    expect(photoAge(bananas, now)).toBe('Photo 3 days ago');
    expect(photoAge(banana, now)).toBe('No photo');
    expect(photoAge(item('d', 'Old', 1, { image_url: 'x', updated_at: '2026-08-01T00:00:00Z' }), now)).toBe('Photo 2 months ago');
    expect(photoAge(item('e', 'New', 1, { image_url: 'x', image_updated_at: '2026-10-23T08:00:00Z' }), now)).toBe('Photo today');
  });

  it('hides a group until one of its items changes', () => {
    const hidden = new Set([groupSignature(group)]);
    expect(visibleGroups([group], hidden)).toEqual([]);
    const changed: DuplicateGroup = { ...group, items: [{ ...banana, updated_at: '2026-10-22T00:00:00Z' }, bananas] };
    expect(visibleGroups([changed], hidden)).toEqual([changed]);
  });

  it('stores hidden groups per household and drops stale ones', () => {
    const storage = window.localStorage;
    storage.clear();
    saveHidden('hh-1', new Set([groupSignature(group), 'gone']), [group], storage);
    expect([...loadHidden('hh-1', storage)]).toEqual([groupSignature(group)]);
    expect(loadHidden('hh-2', storage).size).toBe(0);
    storage.setItem('mekasa.duplicates.hidden.hh-3', 'not json');
    expect(loadHidden('hh-3', storage).size).toBe(0);
  });

  it('applies a merge to the cached inventory and shopping list', () => {
    const merged = { ...bananas, quantity: 3 };
    const row: ShoppingItem = {
      id: 'sh-1',
      household_id: 'hh-1',
      name: 'Banana',
      quantity: 1,
      is_checked: false,
      needs_approval: false,
      inventory_item_id: 'a',
      kind: 'auto',
      created_by_uid: 'u',
      created_at: '',
      updated_at: '',
    } as ShoppingItem;
    const result: InventoryMergeResult = { household_id: 'hh-1', item: merged, removed_ids: ['b'], shopping_list_items: [row] };
    expect(applyMergeToInventory([bananas, banana, item('z', 'Milk', 1)], result)?.map((r) => [r.id, r.quantity])).toEqual([
      ['a', 3],
      ['z', 1],
    ]);
    const stale = { ...row, inventory_item_id: 'b' };
    expect(applyMergeToShopping([stale], result)).toEqual([row]);
    expect(applyMergeToInventory(undefined, result)).toBeUndefined();
  });
});
