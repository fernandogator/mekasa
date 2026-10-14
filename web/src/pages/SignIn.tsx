/**
 * Sign in.
 *
 * Satisfies: UI-007 (Desktop Web App) AC2, AC3; REQ-022 AC3, AC5
 * Design: design/exports/superdesign/desktop/05-sign-in.html
 */

import { AlertCircle, Lock, Mail } from 'lucide-react';
import { type FormEvent, useEffect, useState } from 'react';

import { analytics } from '../analytics/analytics';
import { authErrorMessage, useAuth } from '../auth/AuthProvider';
import { Button, Field } from '../components/ui';

function GoogleMark() {
  return (
    <svg aria-hidden viewBox="0 0 48 48" className="h-5 w-5">
      <path fill="currentColor" d="M44.5 20H24v8.5h11.8C34.7 33.9 30.1 37 24 37c-7.2 0-13-5.8-13-13s5.8-13 13-13c3.1 0 5.9 1.1 8.1 2.9l6.4-6.4C34.6 4.1 29.6 2 24 2 11.8 2 2 11.8 2 24s9.8 22 22 22c11 0 21-8 21-22 0-1.3-.2-2.7-.5-4z" />
    </svg>
  );
}

export function SignIn() {
  const { sessionExpired, lastEmail, signInWithGoogle, signInWithPassword, sendPasswordReset } = useAuth();
  const [email, setEmail] = useState(lastEmail);
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState<'google' | 'password' | 'reset' | null>(null);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  useEffect(() => analytics.page('sign_in'), []);

  async function run(kind: 'google' | 'password' | 'reset', action: () => Promise<void>) {
    setBusy(kind);
    setError('');
    setNotice('');
    try {
      await action();
    } catch (err) {
      setError(authErrorMessage(err));
    } finally {
      setBusy(null);
    }
  }

  function submit(event: FormEvent) {
    event.preventDefault();
    void run('password', () => signInWithPassword(email, password));
  }

  return (
    <div className="grid h-full grid-cols-1 lg:grid-cols-2">
      <section className="relative hidden flex-col justify-between overflow-hidden bg-brand p-12 text-on-brand lg:flex">
        <div className="flex items-center gap-3">
          <img src="/icon.png" alt="" className="h-11 w-11 rounded-sm" />
          <span className="text-2xl font-extrabold">Mekasa</span>
        </div>
        <div className="max-w-md">
          <h1 className="text-5xl font-extrabold leading-tight">Know what’s in your home</h1>
          <p className="mt-5 text-lg text-on-brand-muted">The simple, shared way to manage your household inventory together.</p>
        </div>
        <div aria-hidden className="pointer-events-none absolute -bottom-48 -left-32 h-[600px] w-[600px] rounded-full bg-brand-muted/25 blur-[100px]" />
        <span aria-hidden />
      </section>

      <section className="flex items-center justify-center p-8">
        <div className="w-full max-w-md">
          <div className="rounded-xl bg-elevated p-10 shadow-raised">
            {sessionExpired ? (
              <p role="alert" className="mb-6 flex items-center gap-2 rounded-md bg-warning-tint px-4 py-3 text-sm font-semibold text-warning">
                <AlertCircle aria-hidden className="h-4 w-4 shrink-0" />
                Your session expired. Sign in again.
              </p>
            ) : null}
            <h2 className="text-center text-3xl font-extrabold">Welcome back</h2>
            <p className="mt-2 text-center text-sm text-muted">Securely access your household dashboard</p>

            <Button
              className="mt-8 w-full"
              size="lg"
              variant="secondary"
              icon={<GoogleMark />}
              busy={busy === 'google'}
              onClick={() => void run('google', signInWithGoogle)}
            >
              Continue with Google
            </Button>

            <div className="my-6 flex items-center gap-3 text-[11px] font-extrabold uppercase tracking-widest text-muted">
              <span className="h-px flex-1 bg-line" />
              or
              <span className="h-px flex-1 bg-line" />
            </div>

            <form onSubmit={submit} className="space-y-4" noValidate>
              <div className="relative">
                <Field label="Email address" type="email" autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
                <Mail aria-hidden className="pointer-events-none absolute right-3 top-[38px] h-4 w-4 text-muted" />
              </div>
              <div className="relative">
                <Field label="Password" type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} required />
                <Lock aria-hidden className="pointer-events-none absolute right-3 top-[38px] h-4 w-4 text-muted" />
              </div>
              <div className="flex justify-end">
                <button
                  type="button"
                  className="text-xs font-extrabold uppercase tracking-wider text-accent-text hover:underline disabled:opacity-50"
                  disabled={!email || busy !== null}
                  onClick={() =>
                    void run('reset', async () => {
                      await sendPasswordReset(email);
                      setNotice('Check your email for a reset link.');
                    })
                  }
                >
                  Forgot password?
                </button>
              </div>
              {error ? (
                <p role="alert" className="text-sm font-semibold text-danger">
                  {error}
                </p>
              ) : null}
              {notice ? (
                <p role="status" className="text-sm font-semibold text-accent-text">
                  {notice}
                </p>
              ) : null}
              <Button type="submit" variant="primary" size="lg" className="w-full" busy={busy === 'password'} disabled={!email || !password}>
                Sign in
              </Button>
            </form>
          </div>
          <p className="mt-6 text-center text-sm font-semibold text-muted">New to Mekasa? Create your household in the mobile app.</p>
        </div>
      </section>
    </div>
  );
}
