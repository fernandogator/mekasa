/**
 * Shopping list.
 *
 * Satisfies: UI-007 (Desktop Web App) AC7, AC20 (REQ-012, REQ-013, REQ-014, REQ-024)
 * Design: design/exports/superdesign/desktop/02-shopping-list.html
 */

import { Check, Info, ListChecks, Plus, Printer, Store, X } from 'lucide-react';
import { type FormEvent, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';

import { analytics } from '../analytics/analytics';
import type { InventoryItem, ShoppingItem } from '../api/types';
import { Avatar, Button, Card, EmptyState, ErrorNote, IconButton, Select, Spinner, Stepper, Tag } from '../components/ui';
import { useInventory, useShoppingActions, useShoppingList } from '../household/data';
import { useHousehold } from '../household/HouseholdProvider';
import { Shell } from '../layout/Shell';
import { ANY_STORE, listOf, storeName } from '../stores/logic';

type StatusFilter = 'all' | 'pending' | 'approved';
type SortKey = 'category' | 'requester' | 'date';
const ALL_STORES = 'all';

export function categoryOf(item: ShoppingItem, inventory: InventoryItem[]): string {
  return inventory.find((row) => row.id === item.inventory_item_id)?.category ?? 'Other';
}

export function groupShopping(items: ShoppingItem[], inventory: InventoryItem[], sort: SortKey): [string, ShoppingItem[]][] {
  if (sort === 'date') return [['Newest first', [...items].sort((a, b) => b.created_at.localeCompare(a.created_at))]];
  const groups = new Map<string, ShoppingItem[]>();
  for (const item of items) {
    const key = sort === 'category' ? categoryOf(item, inventory) : item.requested_by || 'Household';
    groups.set(key, [...(groups.get(key) ?? []), item]);
  }
  return [...groups.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, rows]) => [key, rows.sort((a, b) => a.name.localeCompare(b.name))]);
}

export function ShoppingList() {
  const { household, isOwner, displayName } = useHousehold();
  const stores = household.stores ?? [];
  const list = useShoppingList();
  const inventory = useInventory();
  const actions = useShoppingActions();
  const [status, setStatus] = useState<StatusFilter>('all');
  const [sort, setSort] = useState<SortKey>('category');
  const [name, setName] = useState('');
  const [quantity, setQuantity] = useState(1);
  const [tab, setTab] = useState<string>(ALL_STORES);
  const [addStore, setAddStore] = useState<string | null>(null);

  const open = useMemo(() => (list.data ?? []).filter((item) => !item.is_checked), [list.data]);
  const activeTab = tab === ALL_STORES || tab === ANY_STORE || stores.some((s) => s.id === tab) ? tab : ALL_STORES;
  const inTab = activeTab === ALL_STORES ? open : open.filter((item) => listOf(item.store_id, stores) === activeTab);
  const visible = inTab.filter((item) => status === 'all' || (status === 'pending' ? item.needs_approval : !item.needs_approval));
  const tabs = [
    { key: ALL_STORES, label: 'All stores', count: open.length },
    ...stores.map((store) => ({ key: store.id, label: store.name, count: open.filter((item) => listOf(item.store_id, stores) === store.id).length })),
    { key: ANY_STORE, label: 'Any store', count: open.filter((item) => listOf(item.store_id, stores) === ANY_STORE).length },
  ];
  const defaultStore = activeTab === ALL_STORES ? ANY_STORE : activeTab;
  const formStore = addStore ?? defaultStore;
  const groups = groupShopping(visible, inventory.data ?? [], sort);
  const purchased = (list.data ?? []).length - open.length;

  function add(event: FormEvent) {
    event.preventDefault();
    if (!name.trim()) return;
    const request = !isOwner;
    actions.add.mutate(
      {
        name: name.trim(),
        quantity,
        needs_approval: request,
        kind: request ? 'request' : 'custom',
        requested_by: displayName,
        store_id: formStore === ANY_STORE ? null : formStore,
      },
      {
        onSuccess: () => {
          analytics.track('shopping_item_added', {});
          setName('');
          setQuantity(1);
          setAddStore(null);
        },
      },
    );
  }

  return (
    <Shell
      title="Shopping List"
      actions={
        <Button size="sm" icon={<Printer aria-hidden className="h-4 w-4" />} onClick={() => window.print()} className="no-print">
          Print List
        </Button>
      }
    >
      <Card className="no-print mb-6 p-5">
        <form onSubmit={add} className="flex flex-wrap items-end gap-4" aria-label="Add to the list">
          <label className="min-w-64 flex-1">
            <span className="label-caps mb-1.5 block">{isOwner ? 'Add item' : 'Ask for an item'}</span>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              maxLength={120}
              placeholder="e.g. Whole milk"
              className="h-11 w-full rounded-md border border-line bg-elevated px-3 text-sm placeholder:text-muted/80 focus:border-accent"
            />
          </label>
          <Stepper label="quantity" value={quantity} min={1} onChange={setQuantity} />
          {stores.length > 0 ? (
            <Select label="Store" value={formStore} onChange={(e) => setAddStore(e.target.value)}>
              {stores.map((store) => (
                <option key={store.id} value={store.id}>
                  {store.name}
                </option>
              ))}
              <option value={ANY_STORE}>Any store</option>
            </Select>
          ) : null}
          <Button type="submit" variant="primary" icon={<Plus aria-hidden className="h-4 w-4" />} busy={actions.add.isPending} disabled={!name.trim()}>
            {isOwner ? 'Add Item' : 'Send request'}
          </Button>
        </form>
        {!isOwner ? (
          <p className="mt-3 flex items-center gap-2 text-sm font-semibold text-muted" data-testid="purchase-notice">
            <Info aria-hidden className="h-4 w-4" /> Only household owners can mark items purchased.
          </p>
        ) : null}
        {stores.length === 0 && isOwner ? (
          <p className="mt-3 flex items-center gap-2 text-sm font-semibold text-muted" data-testid="stores-hint">
            <Store aria-hidden className="h-4 w-4" /> Want a list per store?{' '}
            <Link to="/settings" className="font-bold text-accent-text underline">
              Choose your grocery stores in Settings
            </Link>
          </p>
        ) : null}
      </Card>

      {stores.length > 0 ? (
        <div role="tablist" aria-label="Store" className="no-print mb-5 inline-flex flex-wrap gap-1 rounded-full bg-elevated p-1 shadow-card">
          {tabs.map((t) => (
            <button
              key={t.key}
              type="button"
              role="tab"
              aria-selected={activeTab === t.key}
              onClick={() => {
                setTab(t.key);
                setAddStore(null);
              }}
              className={`h-9 rounded-full px-4 text-sm font-bold ${activeTab === t.key ? 'bg-brand text-on-brand' : 'text-text hover:bg-brand-muted/15'}`}
            >
              {t.label} <span className={activeTab === t.key ? 'text-on-brand-muted' : 'text-muted'}>{t.count}</span>
            </button>
          ))}
        </div>
      ) : null}
      {stores.length > 0 && activeTab !== ALL_STORES ? (
        <h2 className="mb-4 hidden text-xl font-extrabold print:block">{storeName(activeTab, stores)}</h2>
      ) : null}

      <div className="no-print mb-5 flex flex-wrap items-center justify-between gap-3">
        <div className="flex gap-3">
          <Select label="Status" value={status} onChange={(e) => setStatus(e.target.value as StatusFilter)}>
            <option value="all">All Statuses</option>
            <option value="pending">Pending</option>
            <option value="approved">Approved</option>
          </Select>
          <Select label="Sort by" value={sort} onChange={(e) => setSort(e.target.value as SortKey)}>
            <option value="category">Sort by: Category</option>
            <option value="requester">By Requester</option>
            <option value="date">By Date Added</option>
          </Select>
        </div>
        {purchased > 0 ? <p className="text-sm font-semibold text-muted">{purchased} purchased</p> : null}
      </div>

      {list.isLoading ? (
        <Spinner label="Loading list" />
      ) : list.isError ? (
        <ErrorNote onRetry={() => void list.refetch()}>Couldn’t load the shopping list.</ErrorNote>
      ) : visible.length === 0 ? (
        <EmptyState icon={<ListChecks aria-hidden className="h-6 w-6" />} title="List is clear" body="Low-stock items and requests show up here." />
      ) : (
        <div className="space-y-6" data-testid="shopping-groups">
          {groups.map(([group, rows]) => (
            <section key={group} aria-label={group}>
              <h2 className="label-caps mb-2 px-1">{group}</h2>
              <Card as="div" className="divide-y divide-line">
                {rows.map((item) => (
                  <div key={item.id} className="flex items-center gap-4 px-5 py-4" data-testid="shopping-row">
                    {isOwner && !item.needs_approval ? (
                      <button
                        type="button"
                        aria-label={`Mark ${item.name} purchased`}
                        onClick={() => actions.purchase.mutate(item.id, { onSuccess: () => analytics.track('shopping_item_purchased', {}) })}
                        className="no-print flex h-6 w-6 shrink-0 items-center justify-center rounded-sm border-2 border-border hover:border-accent"
                      />
                    ) : (
                      <span aria-hidden className="h-6 w-6 shrink-0" />
                    )}
                    <div className="min-w-0 flex-1">
                      <p className="truncate font-extrabold">{item.name}</p>
                      <p className="text-xs font-semibold text-muted">×{item.quantity_label || item.quantity}</p>
                    </div>
                    {stores.length > 0 && activeTab === ALL_STORES ? (
                      <Tag className="hidden print:inline-flex">{storeName(listOf(item.store_id, stores), stores)}</Tag>
                    ) : null}
                    {stores.length > 0 ? (
                      <Select
                        label={`Store for ${item.name}`}
                        value={listOf(item.store_id, stores)}
                        disabled={actions.move.isPending}
                        onChange={(e) => actions.move.mutate({ id: item.id, storeId: e.target.value === ANY_STORE ? null : e.target.value })}
                        className="no-print h-9 max-w-40 text-xs"
                      >
                        {stores.map((store) => (
                          <option key={store.id} value={store.id}>
                            {store.name}
                          </option>
                        ))}
                        <option value={ANY_STORE}>Any store</option>
                      </Select>
                    ) : null}
                    <span className="flex items-center gap-2 text-sm font-semibold">
                      <Avatar name={item.requested_by || 'Household'} size="sm" />
                      <span className="hidden md:inline">{item.requested_by || 'Household'}</span>
                    </span>
                    {item.needs_approval ? <Tag tone="warning">Pending</Tag> : <Tag tone="success">Approved</Tag>}
                    {isOwner && item.needs_approval ? (
                      <span className="no-print flex">
                        <IconButton
                          label={`Approve ${item.name}`}
                          onClick={() => actions.approve.mutate(item.id, { onSuccess: () => analytics.track('shopping_request_approved', {}) })}
                        >
                          <Check aria-hidden className="h-5 w-5 text-accent-text" />
                        </IconButton>
                        <IconButton
                          label={`Reject ${item.name}`}
                          onClick={() => actions.reject.mutate(item.id, { onSuccess: () => analytics.track('shopping_request_rejected', {}) })}
                        >
                          <X aria-hidden className="h-5 w-5 text-danger" />
                        </IconButton>
                      </span>
                    ) : null}
                  </div>
                ))}
              </Card>
            </section>
          ))}
        </div>
      )}
    </Shell>
  );
}
