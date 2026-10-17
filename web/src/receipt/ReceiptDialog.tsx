/**
 * Receipt upload, parse and review.
 *
 * Satisfies: UI-007 (Desktop Web App) AC10, AC11, AC18 (REQ-005 AC1–AC7)
 * Design: design/exports/superdesign/desktop/06-receipt-upload-review.html
 */

import { useQueryClient } from '@tanstack/react-query';
import { CloudUpload, Loader2, Search, Trash2 } from 'lucide-react';
import { type DragEvent, useEffect, useRef, useState } from 'react';

import { analytics } from '../analytics/analytics';
import { ApiError } from '../api/client';
import { api } from '../api/endpoints';
import { CATEGORIES, type ProductHit, type ReceiptLine } from '../api/types';
import { Dialog } from '../components/Dialog';
import { Photo } from '../components/Photo';
import { Button, Select, Stepper, Tag } from '../components/ui';
import { appLog, newId } from '../diagnostics/appLog';
import { useHousehold } from '../household/HouseholdProvider';
import { ProductSearch } from '../pages/inventory/AddItemDialog';
import { toReceiptJpegBase64, validateReceiptFile } from './image';

export const SCAN_TIMEOUT_MS = 120_000;

type Stage = 'input' | 'parsing' | 'review';
interface Line extends ReceiptLine {
  key: string;
}

export function summary(lines: ReceiptLine[], store?: string | null): string {
  const matched = lines.filter((line) => line.identified).length;
  const parts = [`${lines.length} ${lines.length === 1 ? 'line' : 'lines'}`, `${matched} matched`];
  if (lines.length - matched > 0) parts.push(`${lines.length - matched} need review`);
  return [store, ...parts].filter(Boolean).join(' · ');
}

export function ReceiptDialog({ onClose }: { onClose: () => void }) {
  const { household } = useHousehold();
  const client = useQueryClient();
  const [tab, setTab] = useState<'photo' | 'text'>('photo');
  const [stage, setStage] = useState<Stage>('input');
  const [text, setText] = useState('');
  const [error, setError] = useState('');
  const [lines, setLines] = useState<Line[]>([]);
  const [store, setStore] = useState<string | null>(null);
  const [searching, setSearching] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [dragging, setDragging] = useState(false);
  const abort = useRef<AbortController | null>(null);
  const flowId = useRef(newId());
  const fileInput = useRef<HTMLInputElement>(null);

  useEffect(() => () => abort.current?.abort(), []);

  async function scan(body: { image_base64?: string; raw_text?: string }, input: 'image' | 'text') {
    setStage('parsing');
    setError('');
    const controller = new AbortController();
    abort.current = controller;
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      controller.abort();
    }, SCAN_TIMEOUT_MS);
    const started = performance.now();
    appLog.log('info', 'receipt', 'Receipt scan started', { correlation_id: flowId.current, fields: { input } });
    try {
      const result = await api.scanReceipt(household.id, body, controller.signal, flowId.current);
      const identified = result.items.filter((line) => line.identified).length;
      analytics.track('receipt_scan', { input, lines: result.items.length, identified, duration_ms: Math.round(performance.now() - started), outcome: 'ok' });
      appLog.log('info', 'receipt', 'Receipt scan finished', { correlation_id: flowId.current, fields: { lines: result.items.length, identified } });
      if (result.items.length === 0) {
        setError('No items found on that receipt. Try a clearer photo or paste the text.');
        setStage('input');
        return;
      }
      setStore(result.store_name ?? null);
      setLines(result.items.map((line) => ({ ...line, key: newId() })));
      setStage('review');
    } catch (err) {
      const cancelled = err instanceof DOMException && err.name === 'AbortError' && !timedOut;
      analytics.track('receipt_scan', { input, lines: 0, identified: 0, duration_ms: Math.round(performance.now() - started), outcome: cancelled ? 'cancelled' : 'failed' });
      if (timedOut) appLog.error('receipt.scan', new Error('Timed out after 120 s'), { category: 'receipt', correlation_id: flowId.current });
      setStage('input');
      if (!cancelled) {
        setError(
          timedOut
            ? 'Reading the receipt took too long. Try again.'
            : err instanceof ApiError && err.status === 413
              ? 'That photo is too large.'
              : 'Couldn’t read that receipt. Try again.',
        );
      }
    } finally {
      clearTimeout(timer);
      abort.current = null;
    }
  }

  async function chooseFile(file: File | undefined) {
    if (!file) return;
    const problem = validateReceiptFile(file);
    if (problem) {
      setError(problem);
      return;
    }
    try {
      await scan({ image_base64: await toReceiptJpegBase64(file) }, 'image');
    } catch (err) {
      appLog.error('receipt.prepare', err, { category: 'receipt' });
      setError('Couldn’t open that photo.');
      setStage('input');
    }
  }

  function onDrop(event: DragEvent) {
    event.preventDefault();
    setDragging(false);
    void chooseFile(event.dataTransfer.files[0]);
  }

  function patch(key: string, change: Partial<Line>) {
    setLines((rows) => rows.map((row) => (row.key === key ? { ...row, ...change } : row)));
  }

  function applyHit(key: string, hit: ProductHit) {
    patch(key, {
      name: hit.name,
      barcode: hit.barcode ?? null,
      image_url: hit.image_url ?? null,
      category: (CATEGORIES as readonly string[]).includes(hit.category) ? hit.category : 'Other',
      identified: true,
    });
    setSearching(null);
  }

  async function save() {
    setSaving(true);
    setError('');
    const remaining: Line[] = [];
    let saved = 0;
    for (const line of lines) {
      try {
        await api.addInventory(
          household.id,
          {
            name: line.name.trim() || 'Item',
            category: line.category,
            quantity: line.quantity,
            price_paid: line.price_paid ?? null,
            barcode: line.barcode ?? null,
            image_url: line.image_url ?? null,
            source: 'receipt',
          },
          flowId.current,
        );
        saved += 1;
        analytics.track('item_added', { source: 'receipt' });
      } catch {
        remaining.push(line);
      }
    }
    await Promise.all([
      client.invalidateQueries({ queryKey: ['inventory', household.id] }),
      client.invalidateQueries({ queryKey: ['spending', household.id] }),
    ]);
    appLog.log('info', 'receipt', 'Receipt items saved', { correlation_id: flowId.current, fields: { saved, failed: remaining.length } });
    if (saved > 0) analytics.track('receipt_saved', { lines: saved });
    setSaving(false);
    if (remaining.length === 0) {
      onClose();
      return;
    }
    setLines(remaining);
    setError(`${remaining.length} ${remaining.length === 1 ? 'item wasn’t' : 'items weren’t'} saved. Try again.`);
  }

  const reviewing = stage === 'review';
  return (
    <Dialog
      title="Add a receipt"
      subtitle={reviewing ? <p className="label-caps">{summary(lines, store)}</p> : <p className="text-sm text-muted">Photo or text from a store receipt</p>}
      onClose={onClose}
      width="max-w-5xl"
      testId="receipt-dialog"
      footer={
        reviewing ? (
          <>
            <Button variant="ghost" onClick={onClose}>
              Cancel
            </Button>
            <Button variant="primary" busy={saving} disabled={lines.length === 0} onClick={() => void save()}>
              Save {lines.length} {lines.length === 1 ? 'item' : 'items'} to inventory
            </Button>
          </>
        ) : undefined
      }
    >
      {stage === 'parsing' ? (
        <div role="status" className="flex flex-col items-center justify-center gap-4 py-20" data-testid="receipt-parsing">
          <Loader2 aria-hidden className="h-10 w-10 animate-spin text-accent-text" />
          <p className="text-lg font-extrabold">Reading your receipt…</p>
          <Button variant="ghost" onClick={() => abort.current?.abort()}>
            Cancel
          </Button>
        </div>
      ) : stage === 'input' ? (
        <div>
          <div role="tablist" aria-label="Receipt input" className="mb-5 flex gap-6 border-b border-line">
            {(['photo', 'text'] as const).map((key) => (
              <button
                key={key}
                role="tab"
                aria-selected={tab === key}
                onClick={() => setTab(key)}
                className={`-mb-px border-b-2 pb-3 text-sm font-extrabold uppercase tracking-wider ${tab === key ? 'border-accent text-text' : 'border-transparent text-muted hover:text-text'}`}
              >
                {key === 'photo' ? 'Photo' : 'Paste text'}
              </button>
            ))}
          </div>
          {tab === 'photo' ? (
            <div
              onDragOver={(e) => {
                e.preventDefault();
                setDragging(true);
              }}
              onDragLeave={() => setDragging(false)}
              onDrop={onDrop}
              className={`flex flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed px-6 py-14 text-center ${dragging ? 'border-accent bg-success-tint/50' : 'border-border/60'}`}
            >
              <CloudUpload aria-hidden className="h-8 w-8 text-accent-text" />
              <p className="font-extrabold">Drop a receipt photo or choose a file</p>
              <p className="text-sm text-muted">JPEG, PNG or WebP up to 10 MB</p>
              <Button className="mt-3" onClick={() => fileInput.current?.click()} data-autofocus>
                Choose a file
              </Button>
              <input
                ref={fileInput}
                type="file"
                accept="image/jpeg,image/png,image/webp"
                className="sr-only"
                aria-label="Receipt photo"
                onChange={(e) => void chooseFile(e.target.files?.[0])}
              />
            </div>
          ) : (
            <div>
              <label className="block">
                <span className="label-caps mb-1.5 block">Receipt text</span>
                <textarea
                  value={text}
                  onChange={(e) => setText(e.target.value)}
                  rows={10}
                  placeholder="Paste the text of an emailed or online receipt"
                  className="w-full rounded-md border border-line bg-elevated p-3 font-mono text-sm placeholder:text-muted/80 focus:border-accent"
                />
              </label>
              <div className="mt-4 flex justify-end">
                <Button variant="primary" disabled={!text.trim()} onClick={() => void scan({ raw_text: text }, 'text')}>
                  Read receipt
                </Button>
              </div>
            </div>
          )}
          {error ? (
            <p role="alert" className="mt-4 text-sm font-semibold text-danger">
              {error}
            </p>
          ) : null}
        </div>
      ) : (
        <div>
          {error ? (
            <p role="alert" className="mb-4 text-sm font-semibold text-danger">
              {error}
            </p>
          ) : null}
          <table className="w-full text-left text-sm" data-testid="receipt-review">
            <thead>
              <tr className="label-caps border-b border-line">
                <th scope="col" className="py-3 pr-3">Item</th>
                <th scope="col" className="py-3 pr-3">Name</th>
                <th scope="col" className="py-3 pr-3">Qty</th>
                <th scope="col" className="py-3 pr-3">Price paid</th>
                <th scope="col" className="py-3 pr-3">Category</th>
                <th scope="col" className="py-3"><span className="sr-only">Remove</span></th>
              </tr>
            </thead>
            <tbody>
              {lines.map((line) => (
                <ReviewRow
                  key={line.key}
                  line={line}
                  searching={searching === line.key}
                  onSearch={() => setSearching(searching === line.key ? null : line.key)}
                  onPick={(hit) => applyHit(line.key, hit)}
                  onChange={(change) => patch(line.key, change)}
                  onRemove={() => setLines((rows) => rows.filter((row) => row.key !== line.key))}
                />
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Dialog>
  );
}

function ReviewRow({
  line,
  searching,
  onSearch,
  onPick,
  onChange,
  onRemove,
}: {
  line: Line;
  searching: boolean;
  onSearch: () => void;
  onPick: (hit: ProductHit) => void;
  onChange: (change: Partial<Line>) => void;
  onRemove: () => void;
}) {
  const review = !line.identified;
  return (
    <>
      <tr className={`border-b border-line ${review ? 'bg-warning-tint/60' : ''}`} data-testid="receipt-line" data-review={review || undefined}>
        <td className="py-3 pr-3">
          <Photo url={line.image_url} alt="" category={line.category} className="h-11 w-11 rounded-sm" />
        </td>
        <td className="py-3 pr-3">
          <input
            aria-label="Name"
            value={line.name}
            onChange={(e) => onChange({ name: e.target.value })}
            maxLength={120}
            className="w-full rounded-sm border border-transparent bg-transparent px-1 py-1 font-bold hover:border-line focus:border-accent"
          />
          {review ? (
            <span className="mt-1 flex items-center gap-2">
              <Tag tone="warning">Needs review</Tag>
              <button type="button" onClick={onSearch} className="flex items-center gap-1 text-[11px] font-extrabold uppercase tracking-wider text-accent-text hover:underline">
                <Search aria-hidden className="h-3 w-3" /> Find product
              </button>
            </span>
          ) : null}
        </td>
        <td className="py-3 pr-3">
          <Stepper label="quantity" value={line.quantity} min={1} onChange={(quantity) => onChange({ quantity })} />
        </td>
        <td className="py-3 pr-3">
          <input
            aria-label="Price paid"
            type="number"
            min={0}
            step="0.01"
            value={line.price_paid ?? ''}
            onChange={(e) => onChange({ price_paid: e.target.value === '' ? null : Number(e.target.value) })}
            className="h-9 w-24 rounded-sm border border-line bg-elevated px-2 text-right font-bold tabular-nums focus:border-accent"
          />
        </td>
        <td className="py-3 pr-3">
          <Select label="Category" value={line.category} onChange={(e) => onChange({ category: e.target.value })}>
            {CATEGORIES.map((c) => (
              <option key={c}>{c}</option>
            ))}
          </Select>
        </td>
        <td className="py-3 text-right">
          <button type="button" aria-label={`Remove ${line.name}`} onClick={onRemove} className="rounded-full p-2 text-muted hover:bg-danger/10 hover:text-danger">
            <Trash2 aria-hidden className="h-4 w-4" />
          </button>
        </td>
      </tr>
      {searching ? (
        <tr className="border-b border-line bg-surface/60">
          <td colSpan={6} className="p-4">
            <ProductSearch initial={line.name} onPick={onPick} />
          </td>
        </tr>
      ) : null}
    </>
  );
}
