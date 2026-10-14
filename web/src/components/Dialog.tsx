import { X } from 'lucide-react';
import { type ReactNode, useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';

import { IconButton } from './ui';

const FOCUSABLE = 'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

/** Modal with focus trap, Escape to close and focus return (UI-007 AC14). */
export function Dialog({
  title,
  subtitle,
  onClose,
  children,
  footer,
  width = 'max-w-xl',
  testId,
}: {
  title: string;
  subtitle?: ReactNode;
  onClose: () => void;
  children: ReactNode;
  footer?: ReactNode;
  width?: string;
  testId?: string;
}) {
  const panel = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null;
    const first = panel.current?.querySelector<HTMLElement>('[data-autofocus]') ?? panel.current?.querySelector<HTMLElement>(FOCUSABLE);
    first?.focus();
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.stopPropagation();
        onClose();
      }
      if (event.key === 'Tab' && panel.current) {
        const items = [...panel.current.querySelectorAll<HTMLElement>(FOCUSABLE)];
        if (items.length === 0) return;
        const [head, tail] = [items[0], items[items.length - 1]];
        if (event.shiftKey && document.activeElement === head) {
          event.preventDefault();
          tail.focus();
        } else if (!event.shiftKey && document.activeElement === tail) {
          event.preventDefault();
          head.focus();
        }
      }
    };
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('keydown', onKey);
      previous?.focus();
    };
  }, [onClose]);

  return createPortal(
    <div className="fixed inset-0 z-40 flex items-center justify-center bg-scrim/45 p-6" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div
        ref={panel}
        role="dialog"
        aria-modal="true"
        aria-labelledby="dialog-title"
        data-testid={testId}
        className={`flex max-h-[calc(100vh-3rem)] w-full flex-col overflow-hidden rounded-xl bg-elevated shadow-raised ${width}`}
      >
        <header className="flex items-start justify-between gap-4 px-8 pb-4 pt-7">
          <div>
            <h2 id="dialog-title" className="text-2xl font-extrabold">
              {title}
            </h2>
            {subtitle ? <div className="mt-1">{subtitle}</div> : null}
          </div>
          <IconButton label="Close" onClick={onClose}>
            <X aria-hidden className="h-5 w-5" />
          </IconButton>
        </header>
        <div className="min-h-0 flex-1 overflow-y-auto px-8 pb-6">{children}</div>
        {footer ? <footer className="flex items-center justify-end gap-3 border-t border-line px-8 py-5">{footer}</footer> : null}
      </div>
    </div>,
    document.body,
  );
}
