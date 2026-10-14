import { createContext, type ReactNode, useCallback, useContext, useMemo, useRef, useState } from 'react';

interface ToastItem {
  id: number;
  message: string;
  action?: { label: string; run: () => void };
}

interface ToastApi {
  show(message: string, options?: { action?: ToastItem['action']; durationMs?: number; onExpire?: () => void }): void;
}

const ToastContext = createContext<ToastApi | null>(null);

export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<ToastItem[]>([]);
  const counter = useRef(0);

  const show = useCallback<ToastApi['show']>((message, options = {}) => {
    const id = ++counter.current;
    let acted = false;
    const action = options.action
      ? {
          label: options.action.label,
          run: () => {
            acted = true;
            options.action?.run();
            setItems((current) => current.filter((item) => item.id !== id));
          },
        }
      : undefined;
    setItems((current) => [...current, { id, message, action }]);
    setTimeout(() => {
      setItems((current) => current.filter((item) => item.id !== id));
      if (!acted) options.onExpire?.();
    }, options.durationMs ?? 4000);
  }, []);

  const value = useMemo(() => ({ show }), [show]);
  return (
    <ToastContext.Provider value={value}>
      {children}
      <div aria-live="polite" className="pointer-events-none fixed bottom-6 left-1/2 z-50 flex -translate-x-1/2 flex-col items-center gap-2">
        {items.map((item) => (
          <div key={item.id} role="status" className="pointer-events-auto flex items-center gap-5 rounded-full bg-brand px-5 py-3 text-sm font-bold text-on-brand shadow-raised">
            <span>{item.message}</span>
            {item.action ? (
              <button type="button" onClick={item.action.run} className="rounded-full px-2 py-1 text-xs font-extrabold uppercase tracking-wider text-on-brand-muted hover:text-on-brand">
                {item.action.label}
              </button>
            ) : null}
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast(): ToastApi {
  const value = useContext(ToastContext);
  if (!value) throw new Error('useToast outside ToastProvider');
  return value;
}
