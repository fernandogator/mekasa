/**
 * Desktop shell: sidebar navigation and page header.
 *
 * Satisfies: UI-007 (Desktop Web App)
 * Acceptance criteria: AC4, AC18 (page views)
 * Design: design/exports/superdesign/desktop/01-dashboard.html
 */

import { BarChart3, LayoutGrid, LogOut, Package, Settings, ShoppingCart, Users } from 'lucide-react';
import { type ReactNode, useEffect } from 'react';
import { NavLink, useLocation } from 'react-router-dom';

import { analytics, type ScreenName } from '../analytics/analytics';
import { useAuth } from '../auth/AuthProvider';
import { Avatar, IconButton } from '../components/ui';
import { useHousehold } from '../household/HouseholdProvider';

const NAV = [
  { to: '/', label: 'Dashboard', icon: LayoutGrid, end: true },
  { to: '/inventory', label: 'Inventory', icon: Package },
  { to: '/shopping', label: 'Shopping List', icon: ShoppingCart },
  { to: '/spending', label: 'Spending', icon: BarChart3 },
  { to: '/members', label: 'Members', icon: Users },
];

export function screenFor(pathname: string): ScreenName {
  if (pathname.startsWith('/inventory/')) return 'item_detail';
  if (pathname.startsWith('/inventory')) return 'inventory';
  if (pathname.startsWith('/shopping')) return 'shopping_list';
  if (pathname.startsWith('/spending')) return 'spending';
  if (pathname.startsWith('/members')) return 'members';
  if (pathname.startsWith('/settings')) return 'settings';
  return 'dashboard';
}

function NavItem({ to, label, icon: Icon, end }: { to: string; label: string; icon: typeof Package; end?: boolean }) {
  return (
    <NavLink
      to={to}
      end={end}
      title={label}
      className={({ isActive }) =>
        `flex h-11 items-center gap-3 rounded-md px-3 text-sm font-bold transition-colors ${
          isActive ? 'bg-accent text-on-accent shadow-card' : 'text-on-brand hover:bg-on-brand/10'
        }`
      }
    >
      <Icon aria-hidden className="h-5 w-5 shrink-0" />
      <span className="max-lg:sr-only">{label}</span>
    </NavLink>
  );
}

export function Shell({ title, actions, children }: { title: string; actions?: ReactNode; children: ReactNode }) {
  const { household, displayName } = useHousehold();
  const { signOut } = useAuth();
  const location = useLocation();

  useEffect(() => {
    analytics.page(screenFor(location.pathname));
  }, [location.pathname]);

  return (
    <div className="flex h-full">
      <aside aria-label="Main" className="no-print flex w-20 shrink-0 flex-col bg-brand px-3 py-6 lg:w-64 lg:px-4">
        <div className="mb-8 flex items-center gap-3 px-2">
          <img src="/icon.png" alt="" className="h-9 w-9 rounded-sm" />
          <span className="text-xl font-extrabold text-on-brand max-lg:sr-only">Mekasa</span>
        </div>
        <nav className="flex flex-1 flex-col gap-1.5">
          {NAV.map((item) => (
            <NavItem key={item.to} {...item} />
          ))}
        </nav>
        <div className="border-t border-on-brand/15 pt-4">
          <NavItem to="/settings" label="Settings" icon={Settings} />
        </div>
      </aside>
      <div className="flex min-w-0 flex-1 flex-col">
        <header className="no-print flex h-[72px] shrink-0 items-center justify-between gap-6 border-b border-line bg-elevated px-8">
          <div className="flex min-w-0 items-center gap-3">
            <h1 className="truncate text-2xl font-extrabold">{title}</h1>
            {household.name ? (
              <span className="hidden truncate rounded-full border border-line px-3 py-1 text-[11px] font-extrabold uppercase tracking-wider md:inline">
                {household.name}
              </span>
            ) : null}
          </div>
          <div className="flex items-center gap-4">
            {actions}
            <div className="flex items-center gap-2" data-testid="user-badge">
              <Avatar name={displayName} />
              <span className="hidden text-sm font-bold xl:inline">{displayName}</span>
            </div>
            <IconButton label="Sign out" onClick={() => void signOut()}>
              <LogOut aria-hidden className="h-5 w-5" />
            </IconButton>
          </div>
        </header>
        <main id="main" className="min-h-0 flex-1 overflow-y-auto px-8 py-7">
          {children}
        </main>
      </div>
    </div>
  );
}
