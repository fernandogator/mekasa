/**
 * Spending analytics.
 *
 * Satisfies: UI-007 (Desktop Web App) AC8 (REQ-017, REQ-018)
 * Design: design/exports/superdesign/desktop/03-spending-analytics.html
 */

import { Receipt } from 'lucide-react';
import { useState } from 'react';

import type { Member, PurchaseEvent, SpendingPeriod } from '../api/types';
import { Avatar, Card, EmptyState, ErrorNote, money, Spinner } from '../components/ui';
import { useSpending } from '../household/data';
import { useHousehold } from '../household/HouseholdProvider';
import { Shell } from '../layout/Shell';

const PERIODS: { key: SpendingPeriod; label: string }[] = [
  { key: 'week', label: 'This Week' },
  { key: 'month', label: 'This Month' },
  { key: 'year', label: 'This Year' },
];

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

export function trendBuckets(events: PurchaseEvent[], period: SpendingPeriod): { label: string; total: number }[] {
  const labels = period === 'week' ? DAYS : period === 'month' ? ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5'] : MONTHS;
  const totals = labels.map(() => 0);
  for (const event of events) {
    const date = new Date(event.purchased_at);
    const index = period === 'week' ? date.getDay() : period === 'month' ? Math.min(4, Math.floor((date.getDate() - 1) / 7)) : date.getMonth();
    totals[index] += event.price_paid;
  }
  return labels.map((label, i) => ({ label, total: Math.round(totals[i] * 100) / 100 }));
}

export function contributions(events: PurchaseEvent[], members: Member[]): { uid: string; name: string; total: number }[] {
  const totals = new Map<string, number>();
  for (const event of events) totals.set(event.created_by_uid, (totals.get(event.created_by_uid) ?? 0) + event.price_paid);
  return [...totals.entries()]
    .map(([uid, total]) => ({ uid, name: members.find((m) => m.uid === uid)?.name || 'Household member', total }))
    .sort((a, b) => b.total - a.total);
}

function Trend({ data }: { data: { label: string; total: number }[] }) {
  const max = Math.max(1, ...data.map((d) => d.total));
  return (
    <svg role="img" aria-label="Spending trend" viewBox={`0 0 ${data.length * 60} 180`} className="h-56 w-full" preserveAspectRatio="none">
      {data.map((d, i) => {
        const h = (d.total / max) * 140;
        return (
          <g key={d.label}>
            <title>{`${d.label}: ${money(d.total)}`}</title>
            <rect x={i * 60 + 14} y={150 - h} width={32} height={Math.max(h, 2)} rx={8} className="fill-accent" />
            <text x={i * 60 + 30} y={172} textAnchor="middle" className="fill-muted text-[11px] font-bold">
              {d.label}
            </text>
          </g>
        );
      })}
    </svg>
  );
}

export function Spending() {
  const { members } = useHousehold();
  const [period, setPeriod] = useState<SpendingPeriod>('month');
  const report = useSpending(period);
  const data = report.data;

  return (
    <Shell title="Spending">
      <div role="tablist" aria-label="Period" className="mb-6 inline-flex rounded-full bg-elevated p-1 shadow-card">
        {PERIODS.map((p) => (
          <button
            key={p.key}
            role="tab"
            aria-selected={period === p.key}
            onClick={() => setPeriod(p.key)}
            className={`h-9 rounded-full px-5 text-sm font-bold ${period === p.key ? 'bg-brand text-on-brand' : 'text-text hover:bg-brand-muted/15'}`}
          >
            {p.label}
          </button>
        ))}
      </div>

      {report.isLoading ? (
        <Spinner label="Loading spending" />
      ) : report.isError || !data ? (
        <ErrorNote onRetry={() => void report.refetch()}>Couldn’t load spending.</ErrorNote>
      ) : data.events.length === 0 && data.total === 0 ? (
        <EmptyState icon={<Receipt aria-hidden className="h-6 w-6" />} title="No purchases yet" body="Prices from scanned receipts show up here." />
      ) : (
        <div className="grid gap-6 xl:grid-cols-3" data-testid="spending-report">
          <Card className="p-6">
            <p className="label-caps">Total spend</p>
            <p className="mt-2 text-4xl font-extrabold tabular-nums" data-testid="spending-total">
              {money(data.total, data.currency)}
            </p>
            <p className="mt-1 text-sm text-muted">{data.events.length} purchases</p>
          </Card>

          <Card className="p-6 xl:col-span-2" aria-labelledby="breakdown-title">
            <h2 id="breakdown-title" className="mb-4 text-lg font-extrabold">
              Category breakdown
            </h2>
            <ul className="space-y-3">
              {data.by_category.map((row) => {
                const share = data.total ? Math.round((row.total / data.total) * 100) : 0;
                return (
                  <li key={row.category}>
                    <div className="mb-1 flex justify-between text-sm font-bold">
                      <span>{row.category}</span>
                      <span className="tabular-nums">
                        {money(row.total, data.currency)} <span className="text-muted">· {share}%</span>
                      </span>
                    </div>
                    <div className="h-2.5 rounded-full bg-surface">
                      <div className="h-2.5 rounded-full bg-accent" style={{ width: `${share}%` }} />
                    </div>
                  </li>
                );
              })}
            </ul>
          </Card>

          <Card className="p-6" aria-labelledby="members-title">
            <h2 id="members-title" className="text-lg font-extrabold">
              Member contribution
            </h2>
            <p className="mb-4 text-sm text-muted">Who’s buying the most</p>
            <ul className="space-y-3">
              {contributions(data.events, members).map((row) => (
                <li key={row.uid} className="flex items-center gap-3">
                  <Avatar name={row.name} />
                  <span className="flex-1 font-bold">{row.name}</span>
                  <span className="text-sm font-semibold tabular-nums">
                    {money(row.total, data.currency)} <span className="text-muted">({data.total ? Math.round((row.total / data.total) * 100) : 0}%)</span>
                  </span>
                </li>
              ))}
            </ul>
          </Card>

          <Card className="p-6 xl:col-span-2" aria-labelledby="trend-title">
            <h2 id="trend-title" className="mb-2 text-lg font-extrabold">
              Spending trend
            </h2>
            <Trend data={trendBuckets(data.events, period)} />
          </Card>
        </div>
      )}
    </Shell>
  );
}
