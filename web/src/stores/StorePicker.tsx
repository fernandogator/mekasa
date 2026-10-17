/**
 * "Where do you shop?" store picker.
 *
 * Satisfies: UI-007 (Desktop Web App) AC19; REQ-003 AC3–AC7, AC10
 * Design: design/exports/superdesign/mobile/02-store-selection.html
 */

import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Check, MapPin, Search, Store as StoreIcon } from 'lucide-react';
import { type FormEvent, useMemo, useState } from 'react';

import { analytics } from '../analytics/analytics';
import { api } from '../api/endpoints';
import type { Household } from '../api/types';
import { useAuth } from '../auth/AuthProvider';
import { Dialog } from '../components/Dialog';
import { Button, EmptyState, ErrorNote, Field, Spinner } from '../components/ui';
import { filterStores, miles, pickerStores, selectedStores, storeMark } from './logic';

export function StoreMark({ name, selected = false }: { name: string; selected?: boolean }) {
  return (
    <span
      aria-hidden
      className={`flex h-12 w-12 shrink-0 items-center justify-center overflow-hidden rounded-full text-[11px] font-black text-brand ${selected ? 'bg-elevated' : 'bg-surface'}`}
    >
      {storeMark(name)}
    </span>
  );
}

export function StorePicker({ household, onClose }: { household: Household; onClose: () => void }) {
  const client = useQueryClient();
  const { user } = useAuth();
  const located = household.latitude != null && household.longitude != null;
  const [editingAddress, setEditingAddress] = useState(!household.address || !located);
  const [address, setAddress] = useState(household.address ?? '');
  const [addressError, setAddressError] = useState('');
  const [savingAddress, setSavingAddress] = useState(false);
  const [query, setQuery] = useState('');
  // Households set up before store details were saved hold bare IDs (often old placeholder stores); start from stores we can show.
  const [selected, setSelected] = useState<Set<string>>(() => new Set((household.stores ?? []).map((store) => store.id)));
  const [saving, setSaving] = useState(false);
  const [saveFailed, setSaveFailed] = useState(false);

  const search = useQuery({
    queryKey: ['stores-nearby', household.id, household.latitude, household.longitude],
    queryFn: () => api.nearbyStores(household.id),
    enabled: !editingAddress,
    staleTime: 5 * 60_000,
  });

  const rows = useMemo(() => pickerStores(search.data?.stores ?? [], household.stores ?? []), [search.data, household.stores]);
  const shown = filterStores(rows, query);
  const radius = search.data?.radius_miles ?? 15;

  function setHousehold(updated: Household) {
    client.setQueryData(['household', user?.uid], updated);
  }

  async function saveAddress(event: FormEvent) {
    event.preventDefault();
    if (!address.trim()) return;
    setSavingAddress(true);
    setAddressError('');
    try {
      const updated = await api.updateAddress(household.id, address.trim());
      setHousehold(updated);
      if (updated.latitude == null || updated.longitude == null) {
        setAddressError('We couldn’t find that address. Check it and try again.');
      } else {
        setEditingAddress(false);
      }
    } catch {
      setAddressError('Couldn’t save the address. Try again.');
    } finally {
      setSavingAddress(false);
    }
  }

  function toggle(id: string) {
    setSelected((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  async function confirm() {
    const stores = selectedStores(rows, selected);
    if (stores.length === 0) return;
    setSaving(true);
    setSaveFailed(false);
    try {
      setHousehold(await api.saveStores(household.id, stores));
      analytics.track('stores_saved', { count: stores.length });
      onClose();
    } catch {
      setSaveFailed(true);
    } finally {
      setSaving(false);
    }
  }

  if (editingAddress) {
    return (
      <Dialog title="Where’s home?" subtitle={<p className="text-sm font-semibold text-muted">We look for stores within 15 miles of your home address.</p>} onClose={onClose} testId="store-picker">
        <form onSubmit={(e) => void saveAddress(e)} className="space-y-4" aria-label="Home address">
          <Field
            label="Home address"
            value={address}
            onChange={(e) => setAddress(e.target.value)}
            maxLength={300}
            placeholder="e.g. 1842 Magnolia Ave, Austin, TX"
            error={addressError || undefined}
            data-autofocus
          />
          <div className="flex justify-end gap-3">
            {located ? (
              <Button variant="ghost" onClick={() => setEditingAddress(false)}>
                Cancel
              </Button>
            ) : null}
            <Button type="submit" variant="primary" busy={savingAddress} disabled={!address.trim()}>
              Find stores
            </Button>
          </div>
        </form>
      </Dialog>
    );
  }

  return (
    <Dialog
      title="Where do you shop?"
      subtitle={
        <p className="flex flex-wrap items-center gap-x-2 text-sm font-semibold text-muted">
          <span>
            We’ll look within {radius} miles of {household.address}.
          </span>
          <button type="button" className="font-bold text-accent-text underline-offset-2 hover:underline" onClick={() => setEditingAddress(true)}>
            Change address
          </button>
        </p>
      }
      onClose={onClose}
      testId="store-picker"
      footer={
        <>
          <span className="mr-auto text-sm font-semibold text-muted">{selected.size} selected</span>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="primary" busy={saving} disabled={selected.size === 0} onClick={() => void confirm()}>
            Confirm stores
          </Button>
        </>
      }
    >
      <label className="relative mb-4 block">
        <span className="sr-only">Search for a store</span>
        <Search aria-hidden className="pointer-events-none absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-muted" />
        <input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search for a store..."
          className="h-14 w-full rounded-xl border border-line bg-elevated pl-12 pr-4 font-semibold placeholder:text-muted/80 focus:border-accent"
          data-autofocus
        />
      </label>
      {saveFailed ? (
        <div className="mb-3">
          <ErrorNote onRetry={() => void confirm()}>Couldn’t save your stores.</ErrorNote>
        </div>
      ) : null}
      {search.isLoading ? (
        <Spinner label="Finding stores" />
      ) : search.isError ? (
        <ErrorNote onRetry={() => void search.refetch()}>Couldn’t load nearby stores.</ErrorNote>
      ) : rows.length === 0 ? (
        <EmptyState
          icon={<MapPin aria-hidden className="h-6 w-6" />}
          title="No stores found"
          body={`We didn’t find grocery stores within ${radius} miles of ${household.address}.`}
          action={<Button onClick={() => setEditingAddress(true)}>Change address</Button>}
        />
      ) : shown.length === 0 ? (
        <EmptyState icon={<StoreIcon aria-hidden className="h-6 w-6" />} title="No matching stores" body={`Nothing nearby matches “${query.trim()}”.`} />
      ) : (
        <ul aria-label="Nearby stores" className="space-y-1 rounded-xl border border-line bg-elevated p-2 shadow-card">
          {shown.map((store) => {
            const on = selected.has(store.id);
            return (
              <li key={store.id}>
                <button
                  type="button"
                  role="checkbox"
                  aria-checked={on}
                  onClick={() => toggle(store.id)}
                  className={`flex w-full items-center gap-4 rounded-lg p-3 text-left transition-colors ${on ? 'bg-brand text-on-brand' : 'hover:bg-surface'}`}
                >
                  <StoreMark name={store.name} selected={on} />
                  <span className="min-w-0 flex-1">
                    <span className="block truncate font-extrabold">{store.name}</span>
                    <span className={`block truncate text-xs font-bold uppercase tracking-wider ${on ? 'text-on-brand-muted' : 'text-muted'}`}>
                      {[miles(store.distance_miles), store.address].filter(Boolean).join(' · ')}
                    </span>
                  </span>
                  <span
                    aria-hidden
                    className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full ${on ? 'bg-accent text-on-accent' : 'border-2 border-border'}`}
                  >
                    {on ? <Check className="h-4 w-4" /> : null}
                  </span>
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </Dialog>
  );
}
