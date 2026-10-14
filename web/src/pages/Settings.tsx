/**
 * Settings: household, appearance, privacy, help and account.
 *
 * Satisfies: UI-007 (Desktop Web App) AC2, AC13, AC15, AC18 (opt-out)
 * Design: design/exports/superdesign/desktop/08-settings.html
 */

import { useQueryClient } from '@tanstack/react-query';
import { Lock, ShieldCheck } from 'lucide-react';
import { type ReactNode, useState } from 'react';

import { analytics, optedOut } from '../analytics/analytics';
import { api } from '../api/endpoints';
import { useAuth } from '../auth/AuthProvider';
import { Button, Card, Field, Switch } from '../components/ui';
import { sendDiagnostics } from '../diagnostics/reporting';
import { useHousehold } from '../household/HouseholdProvider';
import { Shell } from '../layout/Shell';
import { applyTheme, readPreference, savePreference, type ThemePreference } from '../theme/theme';

const THEME_CHOICES: { key: ThemePreference; label: string; swatch: string }[] = [
  { key: 'grounded', label: 'Grounded', swatch: 'bg-surface' },
  { key: 'grounded-dark', label: 'Grounded Dark', swatch: 'bg-brand' },
  { key: 'system', label: 'System', swatch: 'bg-gradient-to-r from-surface to-brand' },
];

function SettingsCard({ title, children }: { title: string; children: ReactNode }) {
  return (
    <Card className="p-6" aria-label={title}>
      <h2 className="label-caps mb-4 text-sm">{title}</h2>
      {children}
    </Card>
  );
}

export function Settings() {
  const { household, isOwner } = useHousehold();
  const { user, signOut } = useAuth();
  const client = useQueryClient();
  const [theme, setTheme] = useState<ThemePreference>(() => readPreference());
  const [sharing, setSharing] = useState(() => !optedOut());
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(household.name ?? '');
  const [saving, setSaving] = useState(false);
  const [diag, setDiag] = useState<{ state: 'idle' | 'sending' | 'sent' | 'failed'; reference?: string }>({ state: 'idle' });

  function chooseTheme(next: ThemePreference) {
    setTheme(next);
    savePreference(next);
    const applied = applyTheme(next);
    analytics.track('theme_changed', { theme: applied });
  }

  async function saveName() {
    setSaving(true);
    try {
      const updated = await api.renameHousehold(household.id, name.trim());
      client.setQueryData(['household', user?.uid], updated);
      setEditing(false);
    } finally {
      setSaving(false);
    }
  }

  async function diagnostics() {
    setDiag({ state: 'sending' });
    try {
      const reference = await sendDiagnostics();
      setDiag({ state: 'sent', reference });
    } catch {
      setDiag({ state: 'failed' });
    }
  }

  return (
    <Shell title="Settings">
      <div className="mx-auto max-w-[880px] space-y-6">
        <SettingsCard title="Household">
          <div className="flex items-center gap-5">
            {household.photo_url ? (
              <img src={household.photo_url} alt="" className="h-16 w-16 rounded-md object-cover" />
            ) : (
              <span aria-hidden className="h-16 w-16 rounded-md bg-surface" />
            )}
            <div className="min-w-0 flex-1">
              {editing ? (
                <div className="flex items-end gap-3">
                  <Field label="Household name" value={name} onChange={(e) => setName(e.target.value)} maxLength={80} className="flex-1" data-autofocus />
                  <Button variant="primary" busy={saving} onClick={() => void saveName()}>
                    Save
                  </Button>
                  <Button variant="ghost" onClick={() => setEditing(false)}>
                    Cancel
                  </Button>
                </div>
              ) : (
                <>
                  <p className="text-2xl font-extrabold">{household.name || 'Your home'}</p>
                  {household.address ? <p className="text-sm text-muted">{household.address}</p> : null}
                </>
              )}
            </div>
            {isOwner && !editing ? <Button onClick={() => setEditing(true)}>Edit</Button> : null}
          </div>
          {isOwner ? (
            <p className="mt-4 flex items-center gap-2 text-xs font-extrabold uppercase tracking-wider text-muted">
              <ShieldCheck aria-hidden className="h-4 w-4" /> You are an owner of this household
            </p>
          ) : null}
        </SettingsCard>

        <SettingsCard title="Appearance">
          <div role="radiogroup" aria-label="Theme" className="grid grid-cols-2 gap-4 md:grid-cols-4">
            {THEME_CHOICES.map((choice) => (
              <button
                key={choice.key}
                type="button"
                role="radio"
                aria-checked={theme === choice.key}
                onClick={() => chooseTheme(choice.key)}
                className={`rounded-lg border-2 p-3 text-left ${theme === choice.key ? 'border-accent' : 'border-line hover:border-border'}`}
              >
                <span className={`block h-20 rounded-md border border-line ${choice.swatch}`} />
                <span className="mt-2 block text-sm font-extrabold">{choice.label}</span>
              </button>
            ))}
            <div aria-disabled="true" className="flex flex-col items-center justify-center rounded-lg border-2 border-dashed border-line p-3 text-center text-xs font-bold text-muted">
              <Lock aria-hidden className="mb-2 h-4 w-4" />
              Seasonal themes — coming soon
            </div>
          </div>
        </SettingsCard>

        <SettingsCard title="Privacy">
          <div className="flex items-start justify-between gap-6">
            <div>
              <p className="font-extrabold">Share usage analytics</p>
              <p className="text-sm text-muted">Helps us improve Mekasa. Never includes names, items or receipts.</p>
            </div>
            <Switch
              label="Share usage analytics"
              checked={sharing}
              onChange={(on) => {
                setSharing(on);
                analytics.setOptedOut(!on);
              }}
            />
          </div>
        </SettingsCard>

        <SettingsCard title="Help">
          <div className="flex items-center justify-between gap-6">
            <div>
              <p className="text-sm text-muted">Sends this browser’s recent app log to Mekasa support.</p>
              {diag.state === 'sent' ? (
                <p role="status" className="mt-1 text-sm font-bold text-accent-text">
                  Sent. Reference {diag.reference}
                </p>
              ) : null}
              {diag.state === 'failed' ? (
                <p role="alert" className="mt-1 text-sm font-bold text-danger">
                  Couldn’t send diagnostics. Try again.
                </p>
              ) : null}
            </div>
            <Button busy={diag.state === 'sending'} onClick={() => void diagnostics()}>
              Send diagnostics
            </Button>
          </div>
        </SettingsCard>

        <SettingsCard title="Account">
          <div className="flex items-center justify-between gap-6">
            <p className="font-semibold">{user?.email ?? 'Signed in'}</p>
            <Button variant="danger" onClick={() => void signOut()}>
              Sign out
            </Button>
          </div>
        </SettingsCard>
      </div>
    </Shell>
  );
}
