/**
 * Family members and invites.
 *
 * Satisfies: UI-007 (Desktop Web App) AC9 (REQ-019)
 * Design: design/exports/superdesign/desktop/04-family-members.html
 */

import { useQueryClient } from '@tanstack/react-query';
import { Copy, UserPlus } from 'lucide-react';
import { useState } from 'react';

import { analytics } from '../analytics/analytics';
import { api } from '../api/endpoints';
import type { Invite, Role } from '../api/types';
import { Dialog } from '../components/Dialog';
import { Avatar, Button, Card, Field, Select, Tag } from '../components/ui';
import { useInvites } from '../household/data';
import { useHousehold } from '../household/HouseholdProvider';
import { Shell } from '../layout/Shell';

const ROLE_LABEL: Record<Role, string> = { owner: 'Owner', teen: 'Teen', member: 'Member' };
const ROLE_HELP: Record<Role, string> = {
  owner: 'Manages members and household settings, approves requests and marks items purchased.',
  teen: 'Adds and uses items and asks for things on the shopping list. Requests wait for an owner.',
  member: 'Adds and uses items and asks for things on the shopping list. Requests wait for an owner.',
};

function joined(date: string): string {
  return new Date(date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

function InviteDialog({ onClose }: { onClose: () => void }) {
  const { household } = useHousehold();
  const client = useQueryClient();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [role, setRole] = useState<Role>('member');
  const [created, setCreated] = useState<Invite | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  async function send() {
    setBusy(true);
    setError('');
    try {
      const invite = await api.createInvite(household.id, { name: name.trim(), email: email.trim() || null, role });
      analytics.track('invite_sent', { role });
      setCreated(invite);
      await client.invalidateQueries({ queryKey: ['invites', household.id] });
    } catch {
      setError('Couldn’t create the invite. Try again.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog
      title={created ? 'Invite ready' : 'Invite member'}
      onClose={onClose}
      footer={
        created ? (
          <Button variant="primary" onClick={onClose}>
            Done
          </Button>
        ) : (
          <>
            <Button variant="ghost" onClick={onClose}>
              Cancel
            </Button>
            <Button variant="primary" busy={busy} disabled={!name.trim()} onClick={() => void send()}>
              Create invite
            </Button>
          </>
        )
      }
    >
      {created ? (
        <div className="space-y-3">
          <p className="text-sm text-muted">Share this link with {created.name}. Signing in with it joins your household.</p>
          {created.invite_link ? (
            <button
              type="button"
              onClick={() => void navigator.clipboard?.writeText(created.invite_link ?? '')}
              className="flex w-full items-center justify-between gap-3 rounded-md border border-line px-4 py-3 text-left text-sm hover:border-border"
            >
              <span className="truncate font-mono">{created.invite_link}</span>
              <Copy aria-label="Copy link" className="h-4 w-4 shrink-0" />
            </button>
          ) : null}
        </div>
      ) : (
        <div className="space-y-4">
          <Field label="Name" value={name} onChange={(e) => setName(e.target.value)} maxLength={80} data-autofocus />
          <Field label="Email (optional)" type="email" value={email} onChange={(e) => setEmail(e.target.value)} maxLength={120} />
          <label className="block">
            <span className="label-caps mb-1.5 block">Role</span>
            <Select label="Role" value={role} onChange={(e) => setRole(e.target.value as Role)} className="h-11 w-full">
              <option value="member">Member</option>
              <option value="teen">Teen</option>
              <option value="owner">Owner</option>
            </Select>
          </label>
          {error ? <p className="text-sm font-semibold text-danger">{error}</p> : null}
        </div>
      )}
    </Dialog>
  );
}

export function Members() {
  const { members, isOwner } = useHousehold();
  const invites = useInvites(isOwner);
  const [inviting, setInviting] = useState(false);
  const pending = (invites.data ?? []).filter((invite) => invite.status === 'pending');
  const active = members.filter((member) => member.status !== 'removed');

  return (
    <Shell
      title="Family Members"
      actions={
        isOwner ? (
          <Button variant="primary" size="sm" icon={<UserPlus aria-hidden className="h-4 w-4" />} onClick={() => setInviting(true)}>
            Invite Member
          </Button>
        ) : null
      }
    >
      <Card className="mb-6 overflow-hidden">
        <table className="w-full text-left text-sm" data-testid="members-table">
          <thead className="border-b border-line">
            <tr className="label-caps">
              <th scope="col" className="px-6 py-4">Member</th>
              <th scope="col" className="px-6 py-4">Role</th>
              <th scope="col" className="px-6 py-4">Joined</th>
              <th scope="col" className="px-6 py-4">Status</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-line">
            {active.map((member) => (
              <tr key={member.uid}>
                <td className="px-6 py-4">
                  <span className="flex items-center gap-3">
                    <Avatar name={member.name || member.email || '?'} />
                    <span>
                      <span className="block font-extrabold">{member.name || 'Household member'}</span>
                      {member.email ? <span className="text-xs text-muted">{member.email}</span> : null}
                    </span>
                  </span>
                </td>
                <td className="px-6 py-4">
                  <Tag tone={member.role === 'owner' ? 'accent' : 'neutral'}>{ROLE_LABEL[member.role]}</Tag>
                </td>
                <td className="px-6 py-4 font-semibold">{joined(member.created_at)}</td>
                <td className="px-6 py-4 font-semibold text-muted">{member.status === 'active' ? 'Active' : 'Invited'}</td>
              </tr>
            ))}
            {pending.map((invite) => (
              <tr key={invite.id}>
                <td className="px-6 py-4">
                  <span className="flex items-center gap-3">
                    <Avatar name={invite.name} />
                    <span>
                      <span className="block font-extrabold">{invite.name} (Pending)</span>
                      {invite.email ? <span className="text-xs text-muted">{invite.email}</span> : null}
                    </span>
                  </span>
                </td>
                <td className="px-6 py-4">
                  <Tag tone="warning">Invited</Tag>
                </td>
                <td className="px-6 py-4 text-muted">—</td>
                <td className="px-6 py-4 font-semibold text-muted">Waiting…</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>

      <Card className="p-6" aria-labelledby="permissions-title">
        <h2 id="permissions-title" className="mb-4 text-lg font-extrabold">
          Household permissions
        </h2>
        <dl className="grid gap-4 md:grid-cols-3">
          {(Object.keys(ROLE_LABEL) as Role[]).map((role) => (
            <div key={role} className="rounded-md border border-line p-4">
              <dt className="font-extrabold">{ROLE_LABEL[role]}</dt>
              <dd className="mt-1 text-sm text-muted">{ROLE_HELP[role]}</dd>
            </div>
          ))}
        </dl>
      </Card>
      {inviting ? <InviteDialog onClose={() => setInviting(false)} /> : null}
    </Shell>
  );
}
