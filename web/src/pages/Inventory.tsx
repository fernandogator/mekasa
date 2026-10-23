/**
 * Inventory grid with filters, search and the item detail panel.
 *
 * Satisfies: UI-007 (Desktop Web App) AC6 (UI-006 AC2, AC3, AC5, AC6), AC21, AC22
 * Design: design/exports/superdesign/desktop/01-dashboard.html,
 *   design/exports/superdesign/desktop/07-item-detail.html,
 *   design/pages/inventory-duplicates.html, design/pages/item-detail-swipe.html
 */

import { CopyCheck, PackageOpen, Plus, ScanLine, Search } from 'lucide-react';
import { useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';

import { Photo } from '../components/Photo';
import { Button, Chip, EmptyState, ErrorNote, Select, Spinner, Tag } from '../components/ui';
import { filterInventory, type InventorySort, isLowStock, useInventory } from '../household/data';
import { Shell } from '../layout/Shell';
import { pagerPosition } from '../inventory/pager';
import { useReceipt } from '../receipt/ReceiptContext';
import { AddItemDialog } from './inventory/AddItemDialog';
import { DuplicatesDialog } from './inventory/DuplicatesDialog';
import { ItemDetailPanel } from './inventory/ItemDetailPanel';

export function Inventory() {
  const inventory = useInventory();
  const receipt = useReceipt();
  const navigate = useNavigate();
  const { itemId } = useParams();
  const [query, setQuery] = useState('');
  const [category, setCategory] = useState<string | null>(null);
  const [sort, setSort] = useState<InventorySort>('newest');
  const [adding, setAdding] = useState(false);
  const [reviewing, setReviewing] = useState(false);

  const items = useMemo(() => (inventory.data ?? []).filter((item) => !item.deleted), [inventory.data]);
  const categories = useMemo(() => [...new Set(items.map((item) => item.category))].sort(), [items]);
  const rows = useMemo(() => filterInventory(items, query, category, sort), [items, query, category, sort]);
  const lowCount = items.filter(isLowStock).length;
  const selected = items.find((item) => item.id === itemId) ?? null;
  const position = useMemo(() => pagerPosition(rows.map((item) => item.id), itemId), [rows, itemId]);

  const search = (
    <label className="relative hidden md:block">
      <span className="sr-only">Search inventory</span>
      <Search aria-hidden className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
      <input
        type="search"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Search inventory…"
        className="h-10 w-64 rounded-full border border-line bg-surface pl-9 pr-4 text-sm text-text placeholder:text-muted/80 focus:border-accent"
      />
    </label>
  );

  return (
    <Shell title="Inventory" actions={search}>
      <div className="mb-6 flex flex-wrap items-center justify-between gap-4">
        <div className="flex gap-3">
          <Button variant="primary" icon={<Plus aria-hidden className="h-4 w-4" />} onClick={() => setAdding(true)}>
            Add Item
          </Button>
          <Button icon={<ScanLine aria-hidden className="h-4 w-4" />} onClick={receipt.open}>
            Scan hauls
          </Button>
          <Button icon={<CopyCheck aria-hidden className="h-4 w-4" />} onClick={() => setReviewing(true)} disabled={items.length < 2}>
            Find duplicates
          </Button>
        </div>
        <div className="flex items-center gap-3">
          <p className="text-sm font-semibold text-muted" data-testid="inventory-summary">
            {items.length} items · {lowCount} low
          </p>
          <Select label="Sort by" value={sort} onChange={(e) => setSort(e.target.value as InventorySort)}>
            <option value="newest">Sort by: Newest</option>
            <option value="name">Name A–Z</option>
            <option value="quantity">Quantity low</option>
          </Select>
        </div>
      </div>

      <div role="group" aria-label="Categories" className="mb-6 flex flex-wrap gap-2">
        <Chip selected={category === null} onClick={() => setCategory(null)}>
          All Categories
        </Chip>
        {categories.map((name) => (
          <Chip key={name} selected={category === name} onClick={() => setCategory(category === name ? null : name)}>
            {name}
          </Chip>
        ))}
      </div>

      {inventory.isLoading ? (
        <Spinner label="Loading inventory" />
      ) : inventory.isError ? (
        <ErrorNote onRetry={() => void inventory.refetch()}>Couldn’t load inventory.</ErrorNote>
      ) : items.length === 0 ? (
        <EmptyState
          icon={<PackageOpen aria-hidden className="h-6 w-6" />}
          title="Nothing in the house yet"
          body="Add items one at a time or scan a receipt to add a whole haul."
          action={
            <Button variant="primary" onClick={() => setAdding(true)}>
              Add items
            </Button>
          }
        />
      ) : rows.length === 0 ? (
        <EmptyState icon={<Search aria-hidden className="h-6 w-6" />} title="No items match" body="Try another name or category." />
      ) : (
        <ul className="grid grid-cols-[repeat(auto-fill,minmax(220px,1fr))] gap-5" data-testid="inventory-grid">
          {rows.map((item) => {
            const low = isLowStock(item);
            return (
              <li key={item.id}>
                <Link
                  to={`/inventory/${item.id}`}
                  aria-label={`${item.name}, ${item.quantity} in stock${low ? ', low stock' : ''}`}
                  className={`group block overflow-hidden rounded-lg bg-elevated shadow-card transition-transform hover:-translate-y-1 ${
                    item.id === itemId ? 'ring-2 ring-accent' : ''
                  }`}
                >
                  <div className="relative h-40">
                    <Photo url={item.image_url} alt="" category={item.category} className="h-full w-full" />
                    <span className="absolute left-3 top-3">
                      {low ? <Tag tone="warning">Low stock</Tag> : <Tag tone="success">In stock</Tag>}
                    </span>
                  </div>
                  <div className="flex items-start justify-between gap-2 p-4">
                    <div className="min-w-0">
                      <p className="truncate text-base font-extrabold">{item.name}</p>
                      <p className="label-caps mt-1">{item.category}</p>
                    </div>
                    <span className="text-base font-extrabold tabular-nums">×{item.quantity}</span>
                  </div>
                </Link>
              </li>
            );
          })}
        </ul>
      )}

      {selected ? (
        <ItemDetailPanel
          item={selected}
          position={position}
          onMove={(id) => navigate(`/inventory/${id}`, { replace: true })}
          onClose={() => navigate('/inventory')}
        />
      ) : null}
      {itemId && !selected && inventory.isSuccess ? <ErrorNote>That item is no longer in the inventory.</ErrorNote> : null}
      {adding ? <AddItemDialog onClose={() => setAdding(false)} /> : null}
      {reviewing ? <DuplicatesDialog onClose={() => setReviewing(false)} /> : null}
    </Shell>
  );
}
