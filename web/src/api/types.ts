/** API shapes used by the web app (mirrors backend/app/models.py). */

export type Role = 'owner' | 'teen' | 'member';

export const CATEGORIES = ['Produce', 'Dairy', 'Pantry', 'Meat', 'Frozen', 'Beverages', 'Household', 'Other'] as const;
export type Category = (typeof CATEGORIES)[number];

export interface UserProfile {
  uid: string;
  email?: string | null;
  name?: string | null;
}

export interface Household {
  id: string;
  name: string | null;
  photo_url: string | null;
  owner_uid: string;
  address?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  store_ids?: string[];
  stores?: SavedStore[];
  created_at: string;
  updated_at: string;
}

/** A household's chosen store, as saved with REQ-003 AC6. */
export interface SavedStore {
  id: string;
  name: string;
  address: string;
  distance_miles?: number | null;
}

export interface NearbyStore {
  id: string;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  distance_miles: number;
  provider: 'places' | 'stub';
}

export interface StoreSearch {
  household_id: string;
  radius_miles: number;
  stores: NearbyStore[];
  needs_location?: boolean;
}

export interface ProductHealth {
  grade?: 'A' | 'B' | 'C' | 'D' | 'E' | null;
  allergens?: string[];
}

export interface InventoryItem {
  id: string;
  household_id: string;
  name: string;
  category: string;
  quantity: number;
  low_stock_threshold: number;
  price_paid?: number | null;
  barcode?: string | null;
  image_url?: string | null;
  source: 'manual' | 'barcode' | 'receipt' | 'voice';
  created_at: string;
  updated_at: string;
  deleted?: boolean;
  health?: ProductHealth | null;
  product_id?: string | null;
  image_updated_at?: string | null;
}

export type DuplicateReason = 'same_barcode' | 'same_product' | 'same_name';

/** REQ-INV-021 AC1, AC2: items that look like one product; `keep_id` survives a merge. */
export interface DuplicateGroup {
  reason: DuplicateReason;
  keep_id: string;
  items: InventoryItem[];
}

export interface InventoryMergeResult {
  household_id: string;
  item: InventoryItem;
  removed_ids: string[];
  shopping_list_items: ShoppingItem[];
}

export interface InventoryCreate {
  name: string;
  category: string;
  quantity: number;
  low_stock_threshold?: number;
  price_paid?: number | null;
  barcode?: string | null;
  image_url?: string | null;
  source: InventoryItem['source'];
}

export type InventoryUpdate = Partial<Pick<InventoryItem, 'name' | 'category' | 'quantity' | 'low_stock_threshold'>>;

export interface ShoppingItem {
  id: string;
  household_id: string;
  name: string;
  quantity: number;
  quantity_label?: string | null;
  is_checked: boolean;
  needs_approval: boolean;
  requested_by?: string | null;
  inventory_item_id?: string | null;
  kind: 'auto' | 'custom' | 'request';
  store_id?: string | null;
  created_by_uid: string;
  created_at: string;
  updated_at: string;
}

export interface ShoppingCreate {
  name: string;
  quantity: number;
  needs_approval?: boolean;
  kind?: ShoppingItem['kind'];
  requested_by?: string | null;
  store_id?: string | null;
}

export interface Member {
  uid: string;
  household_id: string;
  name?: string | null;
  email?: string | null;
  role: Role;
  status: 'active' | 'invited' | 'removed';
  created_at: string;
}

export interface Invite {
  id: string;
  name: string;
  email?: string | null;
  role: Role;
  status: 'pending' | 'accepted' | 'revoked';
  created_at: string;
  invite_link?: string | null;
}

export interface InviteCreate {
  name: string;
  email?: string | null;
  role: Role;
}

export type SpendingPeriod = 'week' | 'month' | 'year';

export interface PurchaseEvent {
  id: string;
  name: string;
  category: string;
  price_paid: number;
  quantity: number;
  purchased_at: string;
  created_by_uid: string;
}

export interface SpendingReport {
  household_id: string;
  period: SpendingPeriod;
  currency: string;
  total: number;
  by_category: { category: string; total: number }[];
  events: PurchaseEvent[];
}

export interface ReceiptLine {
  name: string;
  category: string;
  quantity: number;
  price_paid?: number | null;
  barcode?: string | null;
  image_url?: string | null;
  identified: boolean;
  receipt_text?: string | null;
  match_method?: string | null;
}

export interface ReceiptScanResult {
  household_id: string;
  engine: string;
  items: ReceiptLine[];
  store_name?: string | null;
}

export interface ProductHit {
  barcode?: string | null;
  name: string;
  brand?: string | null;
  category: string;
  image_url?: string | null;
}

export interface PhotoLink {
  url: string;
  expires_at: string | null;
}
