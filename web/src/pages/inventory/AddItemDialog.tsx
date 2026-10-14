/**
 * Manual item entry with catalog search.
 *
 * Satisfies: UI-007 (Desktop Web App) AC6 (REQ-006)
 */

import { useQueryClient } from '@tanstack/react-query';
import { Search } from 'lucide-react';
import { type FormEvent, useState } from 'react';

import { analytics } from '../../analytics/analytics';
import { api } from '../../api/endpoints';
import { CATEGORIES, type ProductHit } from '../../api/types';
import { Dialog } from '../../components/Dialog';
import { Photo } from '../../components/Photo';
import { Button, Field, Select, Stepper } from '../../components/ui';
import { useHousehold } from '../../household/HouseholdProvider';

export function ProductSearch({ initial = '', onPick }: { initial?: string; onPick: (hit: ProductHit) => void }) {
  const [query, setQuery] = useState(initial);
  const [results, setResults] = useState<ProductHit[] | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  async function run(event?: FormEvent) {
    event?.preventDefault();
    if (query.trim().length < 2) return;
    setBusy(true);
    setError('');
    try {
      setResults(await api.searchProducts(query.trim()));
    } catch {
      setError('Product search is unavailable right now.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div>
      <div className="flex items-end gap-2">
        <Field
          label="Search the catalog"
          className="flex-1"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && void run(e)}
          placeholder="e.g. oat milk"
          data-autofocus
        />
        <Button onClick={() => void run()} busy={busy} icon={<Search aria-hidden className="h-4 w-4" />}>
          Search
        </Button>
      </div>
      {error ? <p className="mt-2 text-sm font-semibold text-danger">{error}</p> : null}
      {results ? (
        results.length === 0 ? (
          <p className="mt-3 text-sm text-muted">No products found. Enter the details yourself.</p>
        ) : (
          <ul className="mt-3 max-h-56 divide-y divide-line overflow-y-auto rounded-md border border-line" aria-label="Search results">
            {results.map((hit, index) => (
              <li key={`${hit.barcode ?? hit.name}-${index}`}>
                <button type="button" onClick={() => onPick(hit)} className="flex w-full items-center gap-3 px-3 py-2 text-left hover:bg-brand-muted/10">
                  <Photo url={hit.image_url} alt="" category={hit.category} className="h-10 w-10 shrink-0 rounded-sm" />
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-bold">{hit.name}</span>
                    <span className="text-xs text-muted">{[hit.brand, hit.category].filter(Boolean).join(' · ')}</span>
                  </span>
                </button>
              </li>
            ))}
          </ul>
        )
      ) : null}
    </div>
  );
}

export function AddItemDialog({ onClose }: { onClose: () => void }) {
  const { household } = useHousehold();
  const client = useQueryClient();
  const [name, setName] = useState('');
  const [category, setCategory] = useState<string>('Other');
  const [quantity, setQuantity] = useState(1);
  const [picked, setPicked] = useState<ProductHit | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  function pick(hit: ProductHit) {
    setPicked(hit);
    setName(hit.name);
    setCategory((CATEGORIES as readonly string[]).includes(hit.category) ? hit.category : 'Other');
  }

  async function save() {
    setBusy(true);
    setError('');
    try {
      await api.addInventory(household.id, {
        name: name.trim(),
        category,
        quantity,
        barcode: picked?.barcode ?? null,
        image_url: picked?.image_url ?? null,
        source: 'manual',
      });
      analytics.track('item_added', { source: 'manual' });
      await client.invalidateQueries({ queryKey: ['inventory', household.id] });
      onClose();
    } catch {
      setError('Couldn’t add the item. Try again.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog
      title="Add item"
      onClose={onClose}
      testId="add-item-dialog"
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="primary" busy={busy} disabled={!name.trim()} onClick={() => void save()}>
            Add to inventory
          </Button>
        </>
      }
    >
      <ProductSearch onPick={pick} />
      <div className="mt-6 grid grid-cols-[1fr_auto] items-end gap-4">
        <Field label="Name" value={name} onChange={(e) => setName(e.target.value)} maxLength={120} />
        <label>
          <span className="label-caps mb-1.5 block">Category</span>
          <Select label="Category" value={category} onChange={(e) => setCategory(e.target.value)} className="h-11">
            {CATEGORIES.map((c) => (
              <option key={c}>{c}</option>
            ))}
          </Select>
        </label>
      </div>
      <div className="mt-5 flex items-center justify-between">
        <span className="label-caps">Quantity</span>
        <Stepper label="quantity" value={quantity} min={1} onChange={setQuantity} />
      </div>
      {error ? <p className="mt-4 text-sm font-semibold text-danger">{error}</p> : null}
    </Dialog>
  );
}
