/** Typed calls for each API route the web app uses. */

import { apiRequest } from './client';
import type {
  Household,
  InventoryCreate,
  InventoryItem,
  InventoryUpdate,
  Invite,
  InviteCreate,
  Member,
  PhotoLink,
  ProductHit,
  ReceiptScanResult,
  ShoppingCreate,
  ShoppingItem,
  SpendingPeriod,
  SpendingReport,
  UserProfile,
} from './types';

const hh = (id: string) => `/v1/households/${encodeURIComponent(id)}`;

export const api = {
  me: () => apiRequest<UserProfile>('/v1/me'),
  currentHousehold: () => apiRequest<Household>('/v1/households/current'),
  renameHousehold: (id: string, name: string) =>
    apiRequest<Household>(`${hh(id)}/name`, { method: 'PUT', body: { name }, where: 'household.rename' }),

  inventory: (id: string) => apiRequest<{ items: InventoryItem[] }>(`${hh(id)}/inventory`).then((r) => r.items),
  addInventory: (id: string, item: InventoryCreate, correlationId?: string) =>
    apiRequest<InventoryItem>(`${hh(id)}/inventory`, { method: 'POST', body: item, correlationId, where: 'inventory.add' }),
  updateInventory: (id: string, itemId: string, patch: InventoryUpdate) =>
    apiRequest<InventoryItem>(`${hh(id)}/inventory/${itemId}`, { method: 'PATCH', body: patch, where: 'inventory.update' }),
  deleteInventory: (id: string, itemId: string) =>
    apiRequest<void>(`${hh(id)}/inventory/${itemId}`, { method: 'DELETE', where: 'inventory.delete' }),
  restoreInventory: (id: string, itemId: string) =>
    apiRequest<InventoryItem>(`${hh(id)}/inventory/${itemId}/restore`, { method: 'POST', where: 'inventory.restore' }),
  purgeInventory: (id: string, itemId: string) =>
    apiRequest<void>(`${hh(id)}/inventory/${itemId}/purge`, { method: 'POST', where: 'inventory.purge' }),
  refreshImage: (id: string, itemId: string) =>
    apiRequest<InventoryItem>(`${hh(id)}/inventory/${itemId}/refresh-image`, { method: 'POST', where: 'inventory.refreshImage' }),

  shoppingList: (id: string) => apiRequest<{ items: ShoppingItem[] }>(`${hh(id)}/shopping-list`).then((r) => r.items),
  addShopping: (id: string, item: ShoppingCreate) =>
    apiRequest<ShoppingItem>(`${hh(id)}/shopping-list`, { method: 'POST', body: item, where: 'shopping.add' }),
  checkShopping: (id: string, itemId: string, checked: boolean) =>
    apiRequest<ShoppingItem>(`${hh(id)}/shopping-list/${itemId}`, { method: 'PATCH', body: { is_checked: checked }, where: 'shopping.purchase' }),
  approveShopping: (id: string, itemId: string) =>
    apiRequest<ShoppingItem>(`${hh(id)}/shopping-list/${itemId}/approve`, { method: 'POST', where: 'shopping.approve' }),
  rejectShopping: (id: string, itemId: string) =>
    apiRequest<void>(`${hh(id)}/shopping-list/${itemId}/reject`, { method: 'POST', where: 'shopping.reject' }),

  spending: (id: string, period: SpendingPeriod) => apiRequest<SpendingReport>(`${hh(id)}/spending?period=${period}`),

  members: (id: string) => apiRequest<{ members: Member[] }>(`${hh(id)}/members`).then((r) => r.members),
  invites: (id: string) => apiRequest<{ invites: Invite[] }>(`${hh(id)}/invites`).then((r) => r.invites),
  createInvite: (id: string, invite: InviteCreate) =>
    apiRequest<Invite>(`${hh(id)}/invites`, { method: 'POST', body: invite, where: 'members.invite' }),

  searchProducts: (query: string) =>
    apiRequest<{ results: ProductHit[] }>(`/v1/products/search?q=${encodeURIComponent(query)}`).then((r) => r.results),

  scanReceipt: (id: string, body: { image_base64?: string; raw_text?: string }, signal: AbortSignal, correlationId: string) =>
    apiRequest<ReceiptScanResult>(`${hh(id)}/receipts/scan`, {
      method: 'POST',
      body,
      signal,
      correlationId,
      direct: true,
      where: 'receipt.scan',
    }),

  photoLinks: (id: string, photos: string[]) =>
    apiRequest<{ links: Record<string, PhotoLink | null> }>(`${hh(id)}/photo-links`, {
      method: 'POST',
      body: { photos },
      where: 'photos.links',
    }).then((r) => r.links),
};
