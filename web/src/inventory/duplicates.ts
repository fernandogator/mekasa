/**
 * Duplicates review rules: labels, the merge preview, photo age, hidden
 * groups and applying a merge to the cached inventory and shopping list.
 *
 * Satisfies: UI-007 AC21 (REQ-INV-021 AC5, AC6)
 * Spec version: 1.0
 */

import type { DuplicateGroup, DuplicateReason, InventoryItem, InventoryMergeResult, ShoppingItem } from '../api/types';

export const REASON_LABELS: Record<DuplicateReason, string> = {
  same_barcode: 'Same barcode',
  same_product: 'Same product',
  same_name: 'Same name',
};

export const EMPTY_TITLE = 'No duplicates found';
export const EMPTY_BODY = 'Your inventory is tidy.';

export function survivorOf(group: DuplicateGroup): InventoryItem {
  return group.items.find((item) => item.id === group.keep_id) ?? group.items[0];
}

/** Items in the order shown: the survivor first, then the rest as the API sent them. */
export function orderedItems(group: DuplicateGroup): InventoryItem[] {
  const keep = survivorOf(group);
  return [keep, ...group.items.filter((item) => item.id !== keep.id)];
}

/** "Merges into Bananas · keeps qty 3 (higher) · newest photo" (REQ-INV-021 AC3, AC5). */
export function mergePreview(group: DuplicateGroup): string {
  const keep = survivorOf(group);
  const quantity = Math.max(...group.items.map((item) => item.quantity));
  const qty = quantity > keep.quantity ? `keeps qty ${quantity} (higher)` : `keeps qty ${quantity}`;
  const photo = keep.image_url ? 'newest photo' : 'no photo';
  return `Merges into ${keep.name} · ${qty} · ${photo}`;
}

export function mergedMessage(count: number, name: string): string {
  return `Merged ${count} items into ${name}`;
}

const DAY_MS = 86_400_000;

/** "Photo today", "Photo 3 days ago", "Photo 2 months ago", or "No photo". */
export function photoAge(item: InventoryItem, now: Date = new Date()): string {
  if (!item.image_url) return 'No photo';
  const stamp = Date.parse(item.image_updated_at ?? item.updated_at);
  if (Number.isNaN(stamp)) return 'Photo';
  const days = Math.max(0, Math.floor((now.getTime() - stamp) / DAY_MS));
  if (days === 0) return 'Photo today';
  if (days === 1) return 'Photo yesterday';
  if (days < 30) return `Photo ${days} days ago`;
  const months = Math.floor(days / 30);
  if (months < 12) return months === 1 ? 'Photo 1 month ago' : `Photo ${months} months ago`;
  const years = Math.floor(months / 12);
  return years === 1 ? 'Photo 1 year ago' : `Photo ${years} years ago`;
}

/** Identifies a group as it is now; any item change gives a new signature. */
export function groupSignature(group: DuplicateGroup): string {
  return group.items
    .map((item) => `${item.id}@${item.updated_at}`)
    .sort()
    .join('|');
}

const storageKey = (householdId: string) => `mekasa.duplicates.hidden.${householdId}`;

/** Groups the user marked "Not duplicates" in this browser for this household. */
export function loadHidden(householdId: string, storage: Storage = localStorage): Set<string> {
  try {
    const raw = storage.getItem(storageKey(householdId));
    const parsed: unknown = raw ? JSON.parse(raw) : [];
    return new Set(Array.isArray(parsed) ? parsed.filter((entry): entry is string => typeof entry === 'string') : []);
  } catch {
    return new Set();
  }
}

/** Saves the hidden signatures, keeping only those that still match a group. */
export function saveHidden(householdId: string, hidden: Set<string>, groups: DuplicateGroup[], storage: Storage = localStorage): void {
  const live = new Set(groups.map(groupSignature));
  const kept = [...hidden].filter((signature) => live.has(signature));
  try {
    storage.setItem(storageKey(householdId), JSON.stringify(kept));
  } catch {
    // Private mode or a full quota: the group just shows again next time.
  }
}

export function visibleGroups(groups: DuplicateGroup[], hidden: Set<string>): DuplicateGroup[] {
  return groups.filter((group) => !hidden.has(groupSignature(group)));
}

/** Inventory after a merge: removed items dropped, the survivor replaced (REQ-INV-021 AC6). */
export function applyMergeToInventory(items: InventoryItem[] | undefined, result: InventoryMergeResult): InventoryItem[] | undefined {
  if (!items) return items;
  const removed = new Set(result.removed_ids);
  return items.filter((item) => !removed.has(item.id)).map((item) => (item.id === result.item.id ? result.item : item));
}

/** Shopping rows the merge relinked to the survivor replace the cached ones. */
export function applyMergeToShopping(rows: ShoppingItem[] | undefined, result: InventoryMergeResult): ShoppingItem[] | undefined {
  if (!rows || result.shopping_list_items.length === 0) return rows;
  const updated = new Map(result.shopping_list_items.map((row) => [row.id, row]));
  return rows.map((row) => updated.get(row.id) ?? row);
}
