/**
 * Item detail side panel.
 *
 * Satisfies: UI-007 (Desktop Web App) AC6 (UI-006 AC2, AC3, AC5; REQ-INV-016–018), AC22 (REQ-INV-020)
 * Design: design/exports/superdesign/desktop/07-item-detail.html, design/pages/item-detail-swipe.html
 */

import { useQueryClient } from '@tanstack/react-query';
import { ChevronLeft, ChevronRight, Copy, Expand, X } from 'lucide-react';
import { type TouchEvent, useEffect, useRef, useState } from 'react';
import { createPortal } from 'react-dom';

import { api } from '../../api/endpoints';
import type { InventoryItem } from '../../api/types';
import { Photo } from '../../components/Photo';
import { useToast } from '../../components/Toast';
import { Button, IconButton, Stepper, Tag } from '../../components/ui';
import { appLog } from '../../diagnostics/appLog';
import { useUpdateItem } from '../../household/data';
import { useHousehold } from '../../household/HouseholdProvider';
import { isTypingTarget, type PagerPosition, positionLabel, swipeDirection } from '../../inventory/pager';

const UNDO_MS = 5000;

export function ItemDetailPanel({
  item,
  position = null,
  onMove,
  onClose,
}: {
  item: InventoryItem;
  /** Where the item sits in the grid; null shows no position or chevrons (UI-007 AC22). */
  position?: PagerPosition | null;
  onMove?: (id: string) => void;
  onClose: () => void;
}) {
  const { household } = useHousehold();
  const client = useQueryClient();
  const toast = useToast();
  const update = useUpdateItem();
  const [name, setName] = useState(item.name);
  const [enlarged, setEnlarged] = useState(false);
  const [copied, setCopied] = useState(false);
  const refreshed = useRef<string | null>(null);
  const closeRef = useRef<HTMLButtonElement>(null);
  const touchStart = useRef<{ x: number; y: number } | null>(null);
  const previousId = onMove ? (position?.previousId ?? null) : null;
  const nextId = onMove ? (position?.nextId ?? null) : null;

  useEffect(() => setName(item.name), [item.id, item.name]);
  useEffect(() => closeRef.current?.focus(), []);

  useEffect(() => {
    if (item.image_url || refreshed.current === item.id) return;
    refreshed.current = item.id;
    api
      .refreshImage(household.id, item.id)
      .then((fresh) => client.setQueryData<InventoryItem[]>(['inventory', household.id], (rows) => rows?.map((row) => (row.id === fresh.id ? fresh : row))))
      .catch(() => undefined);
  }, [item.id, item.image_url, household.id, client]);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && !enlarged) onClose();
      if (isTypingTarget(event.target) || event.altKey || event.ctrlKey || event.metaKey) return;
      const target = event.key === 'ArrowLeft' ? previousId : event.key === 'ArrowRight' ? nextId : null;
      if (target && onMove) {
        event.preventDefault();
        onMove(target);
      }
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose, enlarged, previousId, nextId, onMove]);

  function onTouchStart(event: TouchEvent) {
    const touch = event.touches[0];
    touchStart.current = touch ? { x: touch.clientX, y: touch.clientY } : null;
  }

  function onTouchEnd(event: TouchEvent) {
    const start = touchStart.current;
    const touch = event.changedTouches[0];
    touchStart.current = null;
    if (!start || !touch || !onMove) return;
    const direction = swipeDirection(touch.clientX - start.x, touch.clientY - start.y);
    const target = direction === 'next' ? nextId : direction === 'previous' ? previousId : null;
    if (target) onMove(target);
  }

  const chevrons = (
    <>
      {previousId ? (
        <IconButton
          label="Previous item"
          onClick={(event) => {
            event.stopPropagation();
            onMove?.(previousId);
          }}
          className="absolute left-3 top-1/2 -translate-y-1/2 bg-elevated/90 shadow-card"
          data-testid="pager-previous"
        >
          <ChevronLeft aria-hidden className="h-5 w-5" />
        </IconButton>
      ) : null}
      {nextId ? (
        <IconButton
          label="Next item"
          onClick={(event) => {
            event.stopPropagation();
            onMove?.(nextId);
          }}
          className="absolute right-3 top-1/2 -translate-y-1/2 bg-elevated/90 shadow-card"
          data-testid="pager-next"
        >
          <ChevronRight aria-hidden className="h-5 w-5" />
        </IconButton>
      ) : null}
    </>
  );

  function saveName() {
    const trimmed = name.trim();
    if (!trimmed || trimmed === item.name) {
      setName(item.name);
      return;
    }
    update.mutate({ id: item.id, patch: { name: trimmed } });
  }

  async function copyUpc() {
    if (!item.barcode) return;
    await navigator.clipboard?.writeText(item.barcode).catch(() => undefined);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  }

  async function remove() {
    const key = ['inventory', household.id];
    try {
      await api.deleteInventory(household.id, item.id);
    } catch {
      return;
    }
    client.setQueryData<InventoryItem[]>(key, (rows) => rows?.filter((row) => row.id !== item.id));
    onClose();
    toast.show('Item removed', {
      durationMs: UNDO_MS,
      action: {
        label: 'Undo',
        run: () => {
          void api.restoreInventory(household.id, item.id).finally(() => client.invalidateQueries({ queryKey: key }));
        },
      },
      onExpire: () => {
        void api.purgeInventory(household.id, item.id).catch((error) => appLog.error('inventory.purge', error));
      },
    });
  }

  return createPortal(
    <div className="fixed inset-0 z-30 flex justify-end bg-scrim/25" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <aside role="dialog" aria-modal="false" aria-label={`${item.name} details`} data-testid="item-detail" className="flex h-full w-[440px] max-w-full flex-col bg-elevated shadow-raised" onTouchStart={onTouchStart} onTouchEnd={onTouchEnd}>
        <div className="min-h-0 flex-1 overflow-y-auto p-6">
          {position && onMove ? (
            <p className="label-caps mb-3" aria-live="polite" data-testid="pager-position">
              {positionLabel(position)}
            </p>
          ) : null}
          <div className="relative">
            <button type="button" onClick={() => setEnlarged(true)} aria-label="Enlarge picture" className="block w-full overflow-hidden rounded-lg">
              <Photo url={item.image_url} alt={item.name} category={item.category} className="h-72 w-full" />
            </button>
            <span className="pointer-events-none absolute bottom-3 right-3 rounded-full bg-elevated/90 p-2 shadow-card">
              <Expand aria-hidden className="h-4 w-4" />
            </span>
            <IconButton label="Close details" onClick={onClose} className="absolute right-3 top-3 bg-elevated/90 shadow-card">
              <X aria-hidden className="h-5 w-5" />
            </IconButton>
            {chevrons}
          </div>

          <label className="mt-6 block">
            <span className="label-caps">Product name</span>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              onBlur={saveName}
              onKeyDown={(e) => e.key === 'Enter' && (e.currentTarget as HTMLInputElement).blur()}
              aria-label="Product name"
              className="mt-1 w-full rounded-sm border border-transparent bg-transparent text-3xl font-extrabold text-text hover:border-line focus:border-accent"
            />
          </label>

          <div className="mt-5 flex items-start justify-between gap-4">
            <div>
              <span className="label-caps block">Category</span>
              <span className="mt-2 inline-block rounded-full border border-line px-3 py-1 text-sm font-bold">{item.category}</span>
            </div>
            {item.health?.grade ? (
              <span aria-label={`Health grade ${item.health.grade}`} className="flex h-12 w-12 items-center justify-center rounded-md border-2 border-accent bg-success-tint text-xl font-extrabold text-accent-text">
                {item.health.grade}
              </span>
            ) : null}
          </div>

          {item.barcode ? (
            <div className="mt-5">
              <span className="label-caps block">UPC / barcode</span>
              <button
                type="button"
                onClick={() => void copyUpc()}
                className="mt-2 flex h-11 w-full items-center justify-between rounded-md border border-line px-4 font-mono text-sm hover:border-border"
                aria-label={`Copy UPC ${item.barcode}`}
              >
                <span>{item.barcode}</span>
                <span className="flex items-center gap-1 text-[11px] font-extrabold uppercase tracking-wider text-accent-text">
                  <Copy aria-hidden className="h-3.5 w-3.5" />
                  {copied ? 'Copied' : 'Copy'}
                </span>
              </button>
            </div>
          ) : null}

          <div className="mt-5 grid grid-cols-2 gap-3">
            <div className="rounded-lg border border-line p-4 text-center">
              <span className="label-caps block">Current quantity</span>
              <div className="mt-2">
                <Stepper label="quantity" value={item.quantity} onChange={(quantity) => update.mutate({ id: item.id, patch: { quantity } })} />
              </div>
            </div>
            <div className="rounded-lg border border-line p-4 text-center">
              <span className="label-caps block">Low-stock alert</span>
              <div className="mt-2">
                <Stepper
                  label="low-stock alert"
                  value={item.low_stock_threshold}
                  onChange={(low_stock_threshold) => update.mutate({ id: item.id, patch: { low_stock_threshold } })}
                />
              </div>
            </div>
          </div>
          {item.quantity <= item.low_stock_threshold ? (
            <p className="mt-3">
              <Tag tone="warning">Low stock</Tag>
            </p>
          ) : null}
        </div>
        <footer className="flex items-center justify-between border-t border-line px-6 py-4">
          <Button variant="danger" onClick={() => void remove()}>
            Remove
          </Button>
          <Button ref={closeRef} variant="primary" onClick={onClose}>
            Done
          </Button>
        </footer>
      </aside>

      {enlarged ? (
        <div
          role="dialog"
          aria-label={`${item.name} picture`}
          className="fixed inset-0 z-50 flex items-center justify-center bg-scrim/85 p-10"
          onClick={() => setEnlarged(false)}
          onTouchStart={onTouchStart}
          onTouchEnd={onTouchEnd}
        >
          <Photo url={item.image_url} alt={item.name} category={item.category} className="max-h-full max-w-full rounded-lg" />
          <IconButton label="Close picture" onClick={() => setEnlarged(false)} className="absolute right-6 top-6 bg-elevated">
            <X aria-hidden className="h-5 w-5" />
          </IconButton>
          {chevrons}
        </div>
      ) : null}
    </div>,
    document.body,
  );
}
