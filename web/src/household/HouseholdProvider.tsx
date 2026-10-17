/**
 * Current household, members and the signed-in user's role.
 *
 * Satisfies: UI-007 (Desktop Web App)
 * Acceptance criteria: AC2
 *
 * The role only hides controls; the API enforces every rule.
 */

import { useQuery } from '@tanstack/react-query';
import { createContext, type ReactNode, useContext, useEffect, useMemo } from 'react';

import { analytics } from '../analytics/analytics';
import { ApiError } from '../api/client';
import { api } from '../api/endpoints';
import type { Household, Member, Role } from '../api/types';
import { useAuth } from '../auth/AuthProvider';
import { PhotoLinkResolver } from '../photos/photoLinks';
import { readPreference } from '../theme/theme';

interface HouseholdState {
  household: Household;
  members: Member[];
  role: Role;
  isOwner: boolean;
  displayName: string;
  photos: PhotoLinkResolver;
}

const HouseholdContext = createContext<HouseholdState | null>(null);

export function roleFor(household: Household, members: Member[], uid: string): Role {
  if (household.owner_uid === uid) return 'owner';
  return members.find((member) => member.uid === uid)?.role ?? 'member';
}

export function useHouseholdQuery() {
  const { user } = useAuth();
  return useQuery({
    queryKey: ['household', user?.uid],
    queryFn: api.currentHousehold,
    enabled: Boolean(user),
    retry: (count, error) => !(error instanceof ApiError && (error.status === 404 || error.status === 401)) && count < 2,
  });
}

export function HouseholdProvider({ household, children }: { household: Household; children: ReactNode }) {
  const { user } = useAuth();
  const members = useQuery({ queryKey: ['members', household.id], queryFn: () => api.members(household.id) });
  const memberList = useMemo(() => members.data ?? [], [members.data]);
  const role = user ? roleFor(household, memberList, user.uid) : 'member';
  const photos = useMemo(() => new PhotoLinkResolver(household.id), [household.id]);
  const displayName =
    memberList.find((member) => member.uid === user?.uid)?.name || user?.displayName || user?.email?.split('@')[0] || 'You';

  useEffect(() => {
    if (user && members.isSuccess) void analytics.identify(user.uid, { role, theme: readPreference() });
  }, [user, role, members.isSuccess]);

  const value = useMemo(
    () => ({ household, members: memberList, role, isOwner: role === 'owner', displayName, photos }),
    [household, memberList, role, displayName, photos],
  );
  return <HouseholdContext.Provider value={value}>{children}</HouseholdContext.Provider>;
}

export function useHousehold(): HouseholdState {
  const value = useContext(HouseholdContext);
  if (!value) throw new Error('useHousehold outside HouseholdProvider');
  return value;
}
