/**
 * In-browser log ring buffer and automatic error reports.
 *
 * Satisfies: UI-007 (Desktop Web App) AC15; NFR-007 AC1–AC3, AC7 for platform `web`
 */

export type LogLevel = 'debug' | 'info' | 'warning' | 'error';

export interface LogEntry {
  time: string;
  level: LogLevel;
  category: string;
  message: string;
  request_id?: string;
  correlation_id?: string;
  fields: Record<string, unknown>;
}

export interface ErrorReport {
  id: string;
  time: string;
  where: string;
  error_type: string;
  message: string;
  status?: number;
  path?: string;
  request_id?: string;
  correlation_id?: string;
  breadcrumbs: LogEntry[];
}

const MAX_ENTRIES = 500;
const MAX_QUEUE = 50;
const BATCH = 20;
const BREADCRUMBS = 20;
const QUEUE_KEY = 'mekasa.errorQueue';
const EMAIL = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi;

export function maskEmails(text: string): string {
  return text.replace(EMAIL, '[email]');
}

export function newId(): string {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID();
  return `${Date.now().toString(16)}-${Math.random().toString(16).slice(2)}`;
}

type Sender = (reports: ErrorReport[]) => Promise<boolean>;

class AppLog {
  private entries: LogEntry[] = [];
  private queue: ErrorReport[] = [];
  private sender: Sender | null = null;
  private flushTimer: ReturnType<typeof setTimeout> | null = null;
  private sending = false;
  reportsEnabled = false;

  constructor() {
    this.queue = this.loadQueue();
  }

  log(level: LogLevel, category: string, message: string, extra: Partial<Omit<LogEntry, 'time' | 'level' | 'category' | 'message'>> = {}): LogEntry {
    const entry: LogEntry = {
      time: new Date().toISOString(),
      level,
      category,
      message: maskEmails(message).slice(0, 2000),
      request_id: extra.request_id,
      correlation_id: extra.correlation_id,
      fields: extra.fields ?? {},
    };
    this.entries.push(entry);
    if (this.entries.length > MAX_ENTRIES) this.entries.splice(0, this.entries.length - MAX_ENTRIES);
    return entry;
  }

  info(category: string, message: string, fields: Record<string, unknown> = {}): void {
    this.log('info', category, message, { fields });
  }

  /** Logs an `error` entry and queues it as a report (NFR-007 AC2). */
  error(
    where: string,
    error: unknown,
    details: { category?: string; status?: number; path?: string; request_id?: string; correlation_id?: string } = {},
  ): void {
    const errorType = error instanceof Error ? error.name : typeof error;
    const message = maskEmails(error instanceof Error ? error.message : String(error));
    const breadcrumbs = this.entries.slice(-BREADCRUMBS);
    this.log('error', details.category ?? 'app', `${where}: ${errorType}: ${message}`, {
      request_id: details.request_id,
      correlation_id: details.correlation_id,
      fields: { where },
    });
    this.enqueue({
      id: newId(),
      time: new Date().toISOString(),
      where,
      error_type: errorType.slice(0, 120),
      message: message.slice(0, 2000),
      status: details.status,
      path: details.path,
      request_id: details.request_id,
      correlation_id: details.correlation_id,
      breadcrumbs,
    });
  }

  recent(): LogEntry[] {
    return [...this.entries];
  }

  pendingReports(): ErrorReport[] {
    return [...this.queue];
  }

  setSender(sender: Sender | null): void {
    this.sender = sender;
    if (sender) this.scheduleFlush(0);
  }

  private enqueue(report: ErrorReport): void {
    if (!this.reportsEnabled) return;
    this.queue.push(report);
    if (this.queue.length > MAX_QUEUE) this.queue.splice(0, this.queue.length - MAX_QUEUE);
    this.saveQueue();
    this.scheduleFlush(3000);
  }

  scheduleFlush(delayMs: number): void {
    if (!this.sender || !this.reportsEnabled) return;
    if (this.flushTimer) clearTimeout(this.flushTimer);
    this.flushTimer = setTimeout(() => void this.flush(), delayMs);
  }

  /** Sends queued reports; a failed upload is kept for later and never reported itself. */
  async flush(): Promise<void> {
    if (!this.sender || this.sending || this.queue.length === 0) return;
    this.sending = true;
    try {
      while (this.queue.length > 0) {
        const batch = this.queue.slice(0, BATCH);
        const ok = await this.sender(batch).catch(() => false);
        if (!ok) break;
        const sent = new Set(batch.map((report) => report.id));
        this.queue = this.queue.filter((report) => !sent.has(report.id));
        this.saveQueue();
      }
    } finally {
      this.sending = false;
    }
  }

  reset(): void {
    this.entries = [];
    this.queue = [];
    this.saveQueue();
  }

  private loadQueue(): ErrorReport[] {
    try {
      const raw = typeof localStorage !== 'undefined' ? localStorage.getItem(QUEUE_KEY) : null;
      const parsed = raw ? (JSON.parse(raw) as ErrorReport[]) : [];
      return Array.isArray(parsed) ? parsed.slice(-MAX_QUEUE) : [];
    } catch {
      return [];
    }
  }

  private saveQueue(): void {
    try {
      localStorage.setItem(QUEUE_KEY, JSON.stringify(this.queue));
    } catch {
      /* storage full or unavailable: the in-memory queue still works */
    }
  }
}

export const appLog = new AppLog();
