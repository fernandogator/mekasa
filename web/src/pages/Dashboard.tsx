/**
 * Dashboard.
 *
 * Satisfies: UI-007 (Desktop Web App) AC5 (UI-004 AC1–AC4)
 * Design: design/exports/superdesign/desktop/01-dashboard.html
 */

import { AlertTriangle, Check, ChevronRight, Plus, ScanLine, ShoppingCart, X } from 'lucide-react';
import { useState } from 'react';
import { Link } from 'react-router-dom';

import { analytics } from '../analytics/analytics';
import { Photo } from '../components/Photo';
import { Button, Card, EmptyState, ErrorNote, IconButton, Spinner, Tag } from '../components/ui';
import { useInventory, useShoppingActions, useShoppingList, isLowStock } from '../household/data';
import { useHousehold } from '../household/HouseholdProvider';
import { Shell } from '../layout/Shell';
import { useReceipt } from '../receipt/ReceiptContext';
import { AddItemDialog } from './inventory/AddItemDialog';

function greeting(now = new Date()): string {
  const hour = now.getHours();
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

export function Dashboard() {
  const { household, isOwner } = useHousehold();
  const inventory = useInventory();
  const shopping = useShoppingList();
  const actions = useShoppingActions();
  const receipt = useReceipt();
  const [adding, setAdding] = useState(false);

  const low = (inventory.data ?? []).filter((item) => !item.deleted && isLowStock(item));
  const open = (shopping.data ?? []).filter((item) => !item.is_checked && !item.needs_approval);
  const pending = (shopping.data ?? []).filter((item) => item.needs_approval);

  return (
    <Shell title="Dashboard">
      <section
        data-testid="home-hero"
        className="relative mb-7 flex h-56 items-end overflow-hidden rounded-xl bg-brand p-8 shadow-card"
        aria-label="Home"
      >
        {household.photo_url ? <img src={household.photo_url} alt="" className="absolute inset-0 h-full w-full object-cover" /> : null}
        <div className="absolute inset-0 bg-gradient-to-t from-scrim/70 via-scrim/20 to-transparent" />
        <div className="relative">
          <p className="text-[11px] font-extrabold uppercase tracking-[0.2em] text-on-brand/85">{greeting()}</p>
          <h2 className="mt-1 text-4xl font-extrabold text-on-brand">{household.name || 'Your home'}</h2>
        </div>
      </section>

      <div className="mb-7 flex flex-wrap gap-3">
        <Button variant="primary" icon={<Plus aria-hidden className="h-4 w-4" />} onClick={() => setAdding(true)}>
          Add Item
        </Button>
        <Button icon={<ScanLine aria-hidden className="h-4 w-4" />} onClick={receipt.open}>
          Scan hauls
        </Button>
      </div>

      <div className="grid gap-6 xl:grid-cols-3">
        <Card className="p-6 xl:col-span-2" aria-labelledby="low-stock-title">
          <div className="mb-4 flex items-center justify-between">
            <h3 id="low-stock-title" className="flex items-center gap-2 text-lg font-extrabold">
              <AlertTriangle aria-hidden className="h-5 w-5 text-warning" /> Low stock
            </h3>
            <Link to="/inventory" className="text-sm font-bold text-accent-text hover:underline">
              View inventory
            </Link>
          </div>
          {inventory.isLoading ? (
            <Spinner />
          ) : inventory.isError ? (
            <ErrorNote onRetry={() => void inventory.refetch()}>Couldn’t load inventory.</ErrorNote>
          ) : low.length === 0 ? (
            <EmptyState icon={<Check aria-hidden className="h-6 w-6" />} title="Everything is stocked" body="Items at or below their low-stock alert show up here." />
          ) : (
            <ul className="grid gap-3 sm:grid-cols-2" data-testid="low-stock-list">
              {low.slice(0, 8).map((item) => (
                <li key={item.id}>
                  <Link to={`/inventory/${item.id}`} className="flex items-center gap-3 rounded-md border border-line p-3 hover:border-border">
                    <Photo url={item.image_url} alt="" category={item.category} className="h-12 w-12 shrink-0 rounded-sm" />
                    <span className="min-w-0 flex-1">
                      <span className="block truncate font-bold">{item.name}</span>
                      <span className="text-xs font-semibold text-muted">{item.category}</span>
                    </span>
                    <Tag tone="warning">×{item.quantity}</Tag>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <div className="flex flex-col gap-6">
          <Card className="p-6" aria-labelledby="teaser-title">
            <Link to="/shopping" className="group flex items-center justify-between" data-testid="shopping-teaser">
              <span className="flex items-center gap-3">
                <span className="flex h-11 w-11 items-center justify-center rounded-full bg-success-tint text-accent-text">
                  <ShoppingCart aria-hidden className="h-5 w-5" />
                </span>
                <span>
                  <span id="teaser-title" className="block text-lg font-extrabold">
                    {open.length === 0 ? 'List is clear' : `${open.length} ${open.length === 1 ? 'item' : 'items'} to pick up`}
                  </span>
                  <span className="text-xs font-semibold text-muted">Shopping list</span>
                </span>
              </span>
              <ChevronRight aria-hidden className="h-5 w-5 text-muted group-hover:text-text" />
            </Link>
            {open.length > 0 ? (
              <ul className="mt-4 space-y-2 border-t border-line pt-4 text-sm">
                {open.slice(0, 4).map((item) => (
                  <li key={item.id} className="flex justify-between gap-2">
                    <span className="truncate font-semibold">{item.name}</span>
                    <span className="text-muted">×{item.quantity}</span>
                  </li>
                ))}
              </ul>
            ) : null}
          </Card>

          {isOwner ? (
            <Card className="p-6" aria-labelledby="requests-title" data-testid="pending-requests">
              <h3 id="requests-title" className="mb-3 text-lg font-extrabold">
                Pending requests
              </h3>
              {pending.length === 0 ? (
                <p className="text-sm text-muted">No requests waiting.</p>
              ) : (
                <ul className="space-y-2">
                  {pending.map((item) => (
                    <li key={item.id} className="flex items-center gap-2 rounded-md bg-warning-tint/60 px-3 py-2">
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-sm font-bold">{item.name}</span>
                        <span className="text-xs text-muted">{item.requested_by ?? 'Member'} asked</span>
                      </span>
                      <IconButton
                        label={`Approve ${item.name}`}
                        onClick={() =>
                          actions.approve.mutate(item.id, { onSuccess: () => analytics.track('shopping_request_approved', {}) })
                        }
                      >
                        <Check aria-hidden className="h-4 w-4 text-accent-text" />
                      </IconButton>
                      <IconButton
                        label={`Reject ${item.name}`}
                        onClick={() =>
                          actions.reject.mutate(item.id, { onSuccess: () => analytics.track('shopping_request_rejected', {}) })
                        }
                      >
                        <X aria-hidden className="h-4 w-4 text-danger" />
                      </IconButton>
                    </li>
                  ))}
                </ul>
              )}
            </Card>
          ) : null}
        </div>
      </div>
      {adding ? <AddItemDialog onClose={() => setAdding(false)} /> : null}
    </Shell>
  );
}
