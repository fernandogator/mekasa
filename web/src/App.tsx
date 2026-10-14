/**
 * Route tree and session gates.
 *
 * Satisfies: UI-007 (Desktop Web App)
 * Acceptance criteria: AC2, AC4
 */

import { Home, Loader2 } from 'lucide-react';
import { useEffect } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';

import { ApiError } from './api/client';
import { useAuth } from './auth/AuthProvider';
import { Button, ErrorNote } from './components/ui';
import { startErrorReports } from './diagnostics/reporting';
import { HouseholdProvider, useHouseholdQuery } from './household/HouseholdProvider';
import { Dashboard } from './pages/Dashboard';
import { Inventory } from './pages/Inventory';
import { Members } from './pages/Members';
import { Settings } from './pages/Settings';
import { ShoppingList } from './pages/ShoppingList';
import { SignIn } from './pages/SignIn';
import { Spending } from './pages/Spending';
import { ReceiptProvider } from './receipt/ReceiptContext';

function Splash() {
  return (
    <div className="flex h-full items-center justify-center" role="status" aria-label="Loading">
      <Loader2 aria-hidden className="h-8 w-8 animate-spin text-accent-text" />
    </div>
  );
}

function NoHousehold() {
  const { signOut } = useAuth();
  return (
    <div className="flex h-full items-center justify-center p-8">
      <div className="max-w-md rounded-xl bg-elevated p-10 text-center shadow-raised">
        <span className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-success-tint text-accent-text">
          <Home aria-hidden className="h-7 w-7" />
        </span>
        <h1 className="text-2xl font-extrabold">No household yet</h1>
        <p className="mt-2 text-sm text-muted">Create your household in the Mekasa mobile app, or open an invite link from your household owner.</p>
        <Button className="mt-6" onClick={() => void signOut()}>
          Sign out
        </Button>
      </div>
    </div>
  );
}

function SignedIn() {
  const household = useHouseholdQuery();

  useEffect(() => startErrorReports(), []);

  if (household.isLoading) return <Splash />;
  if (household.error instanceof ApiError && household.error.status === 404) return <NoHousehold />;
  if (household.isError || !household.data) {
    return (
      <div className="p-10">
        <ErrorNote onRetry={() => void household.refetch()}>Couldn’t load your household.</ErrorNote>
      </div>
    );
  }
  return (
    <HouseholdProvider household={household.data}>
      <ReceiptProvider>
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/inventory" element={<Inventory />} />
          <Route path="/inventory/:itemId" element={<Inventory />} />
          <Route path="/shopping" element={<ShoppingList />} />
          <Route path="/spending" element={<Spending />} />
          <Route path="/members" element={<Members />} />
          <Route path="/settings" element={<Settings />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </ReceiptProvider>
    </HouseholdProvider>
  );
}

export function App() {
  const { status } = useAuth();
  if (status === 'loading') return <Splash />;
  if (status === 'signedOut') return <SignIn />;
  return <SignedIn />;
}
