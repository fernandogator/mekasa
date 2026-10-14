/** Shared UI primitives. Colors come only from theme tokens (UI-007 AC13). */

import { Loader2, Minus, Plus } from 'lucide-react';
import { type ButtonHTMLAttributes, forwardRef, type InputHTMLAttributes, type ReactNode, type SelectHTMLAttributes, useId } from 'react';

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'brand';

const variants: Record<Variant, string> = {
  primary: 'bg-accent text-on-accent hover:bg-accent/90 shadow-card',
  secondary: 'bg-elevated text-text border border-line hover:border-border shadow-card',
  ghost: 'bg-transparent text-text hover:bg-brand-muted/15',
  danger: 'bg-transparent text-danger hover:bg-danger/10',
  brand: 'bg-brand text-on-brand hover:bg-brand/90',
};

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: 'sm' | 'md' | 'lg';
  icon?: ReactNode;
  busy?: boolean;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'secondary', size = 'md', icon, busy, children, className = '', disabled, type = 'button', ...rest },
  ref,
) {
  const sizes = { sm: 'h-9 px-3 text-sm gap-1.5', md: 'h-11 px-4 text-sm gap-2', lg: 'h-12 px-6 text-base gap-2' }[size];
  return (
    <button
      ref={ref}
      type={type}
      disabled={disabled || busy}
      className={`inline-flex items-center justify-center rounded-md font-bold transition-colors disabled:cursor-not-allowed disabled:opacity-50 ${variants[variant]} ${sizes} ${className}`}
      {...rest}
    >
      {busy ? <Loader2 aria-hidden className="h-4 w-4 animate-spin" /> : icon}
      {children}
    </button>
  );
});

export function IconButton({ label, children, className = '', ...rest }: ButtonHTMLAttributes<HTMLButtonElement> & { label: string }) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      className={`inline-flex h-10 w-10 items-center justify-center rounded-full text-text transition-colors hover:bg-brand-muted/20 disabled:opacity-40 ${className}`}
      {...rest}
    >
      {children}
    </button>
  );
}

export function Card({ children, className = '', as: Tag = 'section', ...rest }: { children: ReactNode; className?: string; as?: 'section' | 'div' | 'article' } & Record<string, unknown>) {
  return (
    <Tag className={`rounded-lg bg-elevated shadow-card ${className}`} {...rest}>
      {children}
    </Tag>
  );
}

type Tone = 'neutral' | 'warning' | 'success' | 'accent' | 'danger';
const tones: Record<Tone, string> = {
  neutral: 'bg-surface text-text border border-line',
  warning: 'bg-warning-tint text-warning',
  success: 'bg-success-tint text-text',
  accent: 'bg-accent text-on-accent',
  danger: 'bg-danger/10 text-danger',
};

export function Tag({ tone = 'neutral', children, className = '' }: { tone?: Tone; children: ReactNode; className?: string }) {
  return (
    <span className={`inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-[11px] font-extrabold uppercase tracking-wide ${tones[tone]} ${className}`}>
      {children}
    </span>
  );
}

export function Chip({ selected, children, ...rest }: ButtonHTMLAttributes<HTMLButtonElement> & { selected: boolean }) {
  return (
    <button
      type="button"
      aria-pressed={selected}
      className={`h-9 rounded-full px-4 text-sm font-bold transition-colors ${
        selected ? 'bg-brand text-on-brand' : 'border border-line bg-elevated text-text hover:border-border'
      }`}
      {...rest}
    >
      {children}
    </button>
  );
}

export function Field({ label, hint, error, id, className = '', ...rest }: InputHTMLAttributes<HTMLInputElement> & { label: string; hint?: string; error?: string }) {
  const autoId = useId();
  const inputId = id ?? autoId;
  return (
    <label htmlFor={inputId} className={`block ${className}`}>
      <span className="label-caps mb-1.5 block">{label}</span>
      <input
        id={inputId}
        aria-invalid={Boolean(error) || undefined}
        className="h-11 w-full rounded-md border border-line bg-elevated px-3 text-sm text-text placeholder:text-muted/80 focus:border-accent"
        {...rest}
      />
      {error ? <span className="mt-1 block text-xs font-semibold text-danger">{error}</span> : hint ? <span className="mt-1 block text-xs text-muted">{hint}</span> : null}
    </label>
  );
}

export function Select({ label, children, className = '', ...rest }: SelectHTMLAttributes<HTMLSelectElement> & { label: string; children: ReactNode }) {
  return (
    <select
      aria-label={label}
      className={`h-10 rounded-md border border-line bg-elevated px-3 text-sm font-semibold text-text focus:border-accent ${className}`}
      {...rest}
    >
      {children}
    </select>
  );
}

export function Stepper({ label, value, min = 0, max = 9999, onChange }: { label: string; value: number; min?: number; max?: number; onChange: (value: number) => void }) {
  return (
    <div role="group" aria-label={label} className="inline-flex items-center gap-2">
      <IconButton label={`Decrease ${label}`} disabled={value <= min} onClick={() => onChange(Math.max(min, value - 1))} className="h-9 w-9 border border-line bg-elevated">
        <Minus aria-hidden className="h-4 w-4" />
      </IconButton>
      <span aria-live="polite" className="min-w-8 text-center text-lg font-extrabold tabular-nums">
        {value}
      </span>
      <IconButton label={`Increase ${label}`} disabled={value >= max} onClick={() => onChange(Math.min(max, value + 1))} className="h-9 w-9 border border-line bg-elevated">
        <Plus aria-hidden className="h-4 w-4" />
      </IconButton>
    </div>
  );
}

export function Switch({ checked, onChange, label, disabled }: { checked: boolean; onChange: (checked: boolean) => void; label: string; disabled?: boolean }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={() => onChange(!checked)}
      className={`relative inline-flex h-7 w-12 shrink-0 items-center rounded-full transition-colors disabled:opacity-50 ${checked ? 'bg-accent' : 'bg-border/60'}`}
    >
      <span className={`inline-block h-5 w-5 rounded-full bg-elevated shadow-card transition-transform ${checked ? 'translate-x-6' : 'translate-x-1'}`} />
    </button>
  );
}

export function Avatar({ name, size = 'md' }: { name: string; size?: 'sm' | 'md' }) {
  const initials =
    name
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0]?.toUpperCase())
      .join('') || '?';
  const dims = size === 'sm' ? 'h-7 w-7 text-[11px]' : 'h-9 w-9 text-xs';
  return (
    <span aria-hidden className={`inline-flex shrink-0 items-center justify-center rounded-full bg-success-tint font-extrabold text-text ${dims}`}>
      {initials}
    </span>
  );
}

export function Spinner({ label = 'Loading' }: { label?: string }) {
  return (
    <span role="status" className="inline-flex items-center gap-2 text-sm font-semibold text-muted">
      <Loader2 aria-hidden className="h-5 w-5 animate-spin" />
      {label}
    </span>
  );
}

export function EmptyState({ icon, title, body, action }: { icon: ReactNode; title: string; body?: string; action?: ReactNode }) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 rounded-lg border border-dashed border-border/60 px-6 py-14 text-center">
      <span className="flex h-12 w-12 items-center justify-center rounded-full bg-brand-muted/20 text-accent-text">{icon}</span>
      <h3 className="text-lg font-extrabold">{title}</h3>
      {body ? <p className="max-w-sm text-sm text-muted">{body}</p> : null}
      {action}
    </div>
  );
}

export function ErrorNote({ children, onRetry }: { children: ReactNode; onRetry?: () => void }) {
  return (
    <div role="alert" className="flex items-center justify-between gap-4 rounded-md bg-danger/10 px-4 py-3 text-sm font-semibold text-danger">
      <span>{children}</span>
      {onRetry ? (
        <Button size="sm" variant="ghost" onClick={onRetry}>
          Try again
        </Button>
      ) : null}
    </div>
  );
}

export function money(value: number | null | undefined, currency = 'USD'): string {
  if (value === null || value === undefined) return '—';
  return new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(value);
}
