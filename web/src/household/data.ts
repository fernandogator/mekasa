/** React Query hooks for household data. */

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import { api } from '../api/endpoints';
import type { InventoryItem, InventoryUpdate, ShoppingCreate, ShoppingItem, SpendingPeriod } from '../api/types';
import { useHousehold } from './HouseholdProvider';

export function useInventory() {
  const { household } = useHousehold();
  return useQuery({ queryKey: ['inventory', household.id], queryFn: () => api.inventory(household.id) });
}

export function useShoppingList() {
  const { household } = useHousehold();
  return useQuery({ queryKey: ['shopping', household.id], queryFn: () => api.shoppingList(household.id) });
}

export function useSpending(period: SpendingPeriod) {
  const { household } = useHousehold();
  return useQuery({ queryKey: ['spending', household.id, period], queryFn: () => api.spending(household.id, period) });
}

export function useMembers() {
  const { household } = useHousehold();
  return useQuery({ queryKey: ['members', household.id], queryFn: () => api.members(household.id) });
}

export function useInvites(enabled: boolean) {
  const { household } = useHousehold();
  return useQuery({ queryKey: ['invites', household.id], queryFn: () => api.invites(household.id), enabled });
}

export function useUpdateItem() {
  const { household } = useHousehold();
  const client = useQueryClient();
  return useMutation({
    mutationFn: ({ id, patch }: { id: string; patch: InventoryUpdate }) => api.updateInventory(household.id, id, patch),
    onSuccess: (item) => {
      client.setQueryData<InventoryItem[]>(['inventory', household.id], (items) => items?.map((row) => (row.id === item.id ? item : row)));
    },
  });
}

export function useShoppingActions() {
  const { household } = useHousehold();
  const client = useQueryClient();
  const key = ['shopping', household.id];
  const refresh = () => client.invalidateQueries({ queryKey: key });
  const replace = (item: ShoppingItem) =>
    client.setQueryData<ShoppingItem[]>(key, (items) => items?.map((row) => (row.id === item.id ? item : row)));
  return {
    add: useMutation({ mutationFn: (item: ShoppingCreate) => api.addShopping(household.id, item), onSuccess: refresh }),
    approve: useMutation({ mutationFn: (id: string) => api.approveShopping(household.id, id), onSuccess: replace }),
    reject: useMutation({ mutationFn: (id: string) => api.rejectShopping(household.id, id), onSuccess: refresh }),
    purchase: useMutation({ mutationFn: (id: string) => api.checkShopping(household.id, id, true), onSuccess: refresh }),
    move: useMutation({
      mutationFn: ({ id, storeId }: { id: string; storeId: string | null }) => api.moveShopping(household.id, id, storeId),
      onSuccess: replace,
    }),
  };
}

export function isLowStock(item: InventoryItem): boolean {
  return item.quantity <= item.low_stock_threshold;
}

export type InventorySort = 'newest' | 'name' | 'quantity';

export function filterInventory(items: InventoryItem[], query: string, category: string | null, sort: InventorySort): InventoryItem[] {
  const needle = query.trim().toLowerCase();
  const rows = items.filter(
    (item) =>
      !item.deleted &&
      (!category || item.category === category) &&
      (!needle || item.name.toLowerCase().includes(needle) || item.category.toLowerCase().includes(needle)),
  );
  const sorted = [...rows];
  if (sort === 'name') sorted.sort((a, b) => a.name.localeCompare(b.name));
  else if (sort === 'quantity') sorted.sort((a, b) => a.quantity - a.low_stock_threshold - (b.quantity - b.low_stock_threshold) || a.name.localeCompare(b.name));
  else sorted.sort((a, b) => b.created_at.localeCompare(a.created_at));
  return sorted;
}
