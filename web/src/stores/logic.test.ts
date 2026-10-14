import type { NearbyStore, SavedStore } from '../api/types';
import { ANY_STORE, filterStores, listOf, miles, pickerStores, selectedStores, storeMark, storeName } from './logic';

const costco: SavedStore = { id: 'costco-1', name: 'Costco Wholesale', address: '1 Main St', distance_miles: 6.2 };
const heb: SavedStore = { id: 'heb-1', name: 'H-E-B', address: '9 Oak Ave', distance_miles: 1.4 };

function nearby(store: SavedStore): NearbyStore {
  return { ...store, distance_miles: store.distance_miles ?? 0, latitude: 0, longitude: 0, provider: 'places' };
}

describe('store picker (UI-007 AC19)', () => {
  it('keeps saved stores the search no longer returns and sorts by distance', () => {
    const far: SavedStore = { id: 'old', name: 'Old Market', address: '', distance_miles: null };
    const rows = pickerStores([nearby(costco), nearby(heb)], [far, costco]);
    expect(rows.map((row) => row.id)).toEqual(['heb-1', 'costco-1', 'old']);
  });

  it('filters by name or address, ignoring case', () => {
    expect(filterStores([costco, heb], 'costco')).toEqual([costco]);
    expect(filterStores([costco, heb], 'OAK')).toEqual([heb]);
    expect(filterStores([costco, heb], '  ')).toEqual([costco, heb]);
  });

  it('returns selected stores in list order', () => {
    expect(selectedStores([heb, costco], new Set(['costco-1', 'heb-1']))).toEqual([heb, costco]);
  });

  it('labels the logo with the first word and formats miles', () => {
    expect(storeMark('H-E-B plus!')).toBe('H-E-B');
    expect(storeMark('Supercalifragilistic Foods')).toBe('Supercal');
    expect(miles(1.44)).toBe('1.4 mi');
    expect(miles(12.6)).toBe('13 mi');
    expect(miles(null)).toBe('');
  });
});

describe('shopping list per store (REQ-024, UI-007 AC20)', () => {
  it('puts a row on its saved store list', () => {
    expect(listOf('heb-1', [costco, heb])).toBe('heb-1');
  });

  it('puts rows without a store, or with a removed store, on Any store (REQ-024 AC4, AC5)', () => {
    expect(listOf(null, [costco, heb])).toBe(ANY_STORE);
    expect(listOf(undefined, [costco])).toBe(ANY_STORE);
    expect(listOf('gone', [costco, heb])).toBe(ANY_STORE);
  });

  it('names lists', () => {
    expect(storeName('costco-1', [costco, heb])).toBe('Costco Wholesale');
    expect(storeName(ANY_STORE, [costco, heb])).toBe('Any store');
  });
});
