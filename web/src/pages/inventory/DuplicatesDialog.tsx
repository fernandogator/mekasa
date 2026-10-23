/**
 * Duplicates review: groups of items that look like one product, merged
 * only when the user confirms.
 *
 * Satisfies: UI-007 AC21 (REQ-INV-021 AC5–AC7)
 * Design: design/pages/inventory-duplicates.html
 */

import { useQuery, useQueryClient } from '@tanstack/react-query';
import { CopyCheck, Sparkles } from 'lucide-react';
import { useState } from 'react';

import { api } from '../../api/endpoints';
import { ApiError } from '../../api/client';
import type { DuplicateGroup, InventoryItem, InventoryMergeResult, ShoppingItem } from '../../api/types';
import { Dialog } from '../../components/Dialog';
import { Photo } from '../../components/Photo';
import { useToast } from '../../components/Toast';
import { Button, EmptyState, ErrorNote, Spinner, Tag } from '../../components/ui';
import { appLog } from '../../diagnostics/appLog';
import { useHousehold } from '../../household/HouseholdProvider';
import {
  applyMergeToInventory,
  applyMergeToShopping,
  EMPTY_BODY,
  EMPTY_TITLE,
  groupSignature,
  loadHidden,
  mergedMessage,
  mergePreview,
  orderedItems,
  photoAge,
  REASON_LABELS,
  saveHidden,
  survivorOf,
  visibleGroups,
} from '../../inventory/duplicates';

export function DuplicatesDialog({ onClose }: { onClose: () => void }) {
  const { household } = useHousehold();
  const client = useQueryClient();
  const toast = useToast();
  const groupsQuery = useQuery({
    queryKey: ['duplicates', household.id],
    queryFn: () => api.duplicates(household.id),
    staleTime: 0,
  });
  const [hidden, setHidden] = useState(() => loadHidden(household.id));
  const [busy, setBusy] = useState<string | null>(null);
  const [problem, setProblem] = useState<string | null>(null);

  const groups = visibleGroups(groupsQuery.data ?? [], hidden);

  function applyResult(result: InventoryMergeResult) {
    client.setQueryData<InventoryItem[]>(['inventory', household.id], (items) => applyMergeToInventory(items, result));
    client.setQueryData<ShoppingItem[]>(['shopping', household.id], (rows) => applyMergeToShopping(rows, result));
  }

  async function merge(targets: DuplicateGroup[], key: string) {
    setBusy(key);
    setProblem(null);
    let merged = 0;
    let last: InventoryMergeResult | null = null;
    try {
      for (const group of targets) {
        const result = await api.mergeInventory(
          household.id,
          group.items.map((item) => item.id),
        );
        applyResult(result);
        merged += 1 + result.removed_ids.length;
        last = result;
      }
    } catch (error) {
      if (error instanceof ApiError && (error.status === 404 || error.status === 409)) {
        setProblem('Some of these items changed. The list is up to date now. Review it and try again.');
      } else {
        appLog.error('inventory.merge', error);
        setProblem('Couldn’t merge. Check your connection and try again.');
      }
    } finally {
      setBusy(null);
      void groupsQuery.refetch();
    }
    if (last && targets.length === 1) toast.show(mergedMessage(merged, last.item.name));
    else if (last) toast.show(`Merged ${merged} items`);
  }

  function notDuplicates(group: DuplicateGroup) {
    const next = new Set(hidden).add(groupSignature(group));
    setHidden(next);
    saveHidden(household.id, next, groupsQuery.data ?? []);
  }

  const footer =
    groups.length > 1 ? (
      <div className="flex justify-end">
        <Button variant="primary" busy={busy === 'all'} disabled={busy !== null} onClick={() => void merge(groups, 'all')}>
          Merge all {groups.length}
        </Button>
      </div>
    ) : undefined;

  return (
    <Dialog
      title="Duplicates"
      subtitle="Items that look like the same product. Nothing merges until you choose Merge."
      onClose={onClose}
      width="max-w-3xl"
      testId="duplicates-dialog"
      footer={footer}
    >
      {problem ? <p role="alert" className="mb-4 rounded-md bg-warning-tint p-3 text-sm font-semibold text-text">{problem}</p> : null}
      {groupsQuery.isLoading ? (
        <Spinner label="Looking for duplicates" />
      ) : groupsQuery.isError ? (
        <ErrorNote onRetry={() => void groupsQuery.refetch()}>Couldn’t look for duplicates.</ErrorNote>
      ) : groups.length === 0 ? (
        <EmptyState icon={<Sparkles aria-hidden className="h-6 w-6" />} title={EMPTY_TITLE} body={EMPTY_BODY} />
      ) : (
        <ul className="flex flex-col gap-4" aria-label="Duplicate groups">
          {groups.map((group) => {
            const key = groupSignature(group);
            const keep = survivorOf(group);
            return (
              <li key={key}>
                <article
                  aria-label={`${REASON_LABELS[group.reason]}: ${group.items.length} items, keeps ${keep.name}`}
                  className="rounded-lg border border-line bg-surface p-4"
                  data-testid="duplicate-group"
                >
                  <div className="mb-3 flex items-center justify-between gap-3">
                    <Tag tone="neutral">{REASON_LABELS[group.reason]}</Tag>
                    <span className="text-sm font-semibold text-muted">{group.items.length} items</span>
                  </div>
                  <ul className="flex flex-col gap-2">
                    {orderedItems(group).map((item) => {
                      const keeps = item.id === keep.id;
                      return (
                        <li
                          key={item.id}
                          aria-label={`${item.name}, ${item.category}, quantity ${item.quantity}, ${photoAge(item)}${keeps ? ', keeps this photo' : ''}`}
                          className={`flex items-center gap-3 rounded-md p-2 ${keeps ? 'bg-success-tint' : ''}`}
                        >
                          <Photo url={item.image_url} alt="" category={item.category} className="h-14 w-14 shrink-0 rounded-md" />
                          <div className="min-w-0 flex-1">
                            <p className="truncate text-base font-extrabold">{item.name}</p>
                            <p className="text-xs font-semibold text-muted">
                              {item.category} · qty {item.quantity} · {photoAge(item)}
                            </p>
                          </div>
                          {keeps ? <Tag tone="success">Keeps this photo</Tag> : null}
                        </li>
                      );
                    })}
                  </ul>
                  <p className="mt-3 text-sm font-semibold text-muted" data-testid="merge-preview">
                    {mergePreview(group)}
                  </p>
                  <div className="mt-3 flex justify-end gap-2">
                    <Button size="sm" disabled={busy !== null} onClick={() => notDuplicates(group)}>
                      Not duplicates
                    </Button>
                    <Button
                      size="sm"
                      variant="primary"
                      icon={<CopyCheck aria-hidden className="h-4 w-4" />}
                      busy={busy === key}
                      disabled={busy !== null}
                      onClick={() => void merge([group], key)}
                      aria-label={`Merge ${group.items.length} items into ${keep.name}`}
                    >
                      Merge
                    </Button>
                  </div>
                </article>
              </li>
            );
          })}
        </ul>
      )}
    </Dialog>
  );
}
