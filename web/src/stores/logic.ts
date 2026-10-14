/**
 * Store picker rules that don't need React.
 *
 * Satisfies: UI-007 (Desktop Web App) AC19; REQ-003 AC4–AC6
 */

import type { NearbyStore, SavedStore } from '../api/types';

/** Nearby stores plus saved ones the search no longer returns, sorted by distance. */
export function pickerStores(nearby: NearbyStore[], saved: SavedStore[]): SavedStore[] {
  const rows: SavedStore[] = nearby.map(({ id, name, address, distance_miles }) => ({ id, name, address, distance_miles }));
  const seen = new Set(rows.map((row) => row.id));
  for (const store of saved) if (!seen.has(store.id)) rows.push(store);
  return rows.sort((a, b) => (a.distance_miles ?? Infinity) - (b.distance_miles ?? Infinity));
}

export function filterStores(stores: SavedStore[], query: string): SavedStore[] {
  const needle = query.trim().toLowerCase();
  if (!needle) return stores;
  return stores.filter((store) => `${store.name} ${store.address}`.toLowerCase().includes(needle));
}

/** Selected rows in list order, ready to save with their details. */
export function selectedStores(stores: SavedStore[], selected: ReadonlySet<string>): SavedStore[] {
  return stores.filter((store) => selected.has(store.id));
}

/** Short label for the logo circle: the first word of the name, e.g. "H-E-B" or "Walmart". */
export function storeMark(name: string): string {
  return (name.trim().split(/\s+/)[0] ?? '').slice(0, 8);
}

export function miles(distance: number | null | undefined): string {
  if (distance == null) return '';
  return `${distance < 10 ? distance.toFixed(1) : Math.round(distance)} mi`;
}

/** Tab key for the "Any store" list (REQ-024). */
export const ANY_STORE = 'any';

/**
 * Which list a shopping row is on: its store, or "Any store" when it has
 * none or its store is no longer saved (REQ-024 AC5).
 */
export function listOf(storeId: string | null | undefined, saved: SavedStore[]): string {
  return storeId && saved.some((store) => store.id === storeId) ? storeId : ANY_STORE;
}

export function storeName(listKey: string, saved: SavedStore[]): string {
  return saved.find((store) => store.id === listKey)?.name ?? 'Any store';
}
