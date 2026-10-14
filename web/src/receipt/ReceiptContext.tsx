import { createContext, type ReactNode, useContext, useMemo, useState } from 'react';

import { ReceiptDialog } from './ReceiptDialog';

const ReceiptContext = createContext<{ open(): void } | null>(null);

export function ReceiptProvider({ children }: { children: ReactNode }) {
  const [open, setOpen] = useState(false);
  const value = useMemo(() => ({ open: () => setOpen(true) }), []);
  return (
    <ReceiptContext.Provider value={value}>
      {children}
      {open ? <ReceiptDialog onClose={() => setOpen(false)} /> : null}
    </ReceiptContext.Provider>
  );
}

export function useReceipt() {
  const value = useContext(ReceiptContext);
  if (!value) throw new Error('useReceipt outside ReceiptProvider');
  return value;
}
