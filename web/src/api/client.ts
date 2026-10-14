/**
 * Fetch wrapper for the Mekasa API.
 *
 * Satisfies: UI-007 (Desktop Web App) AC3, AC11, AC15; REQ-022 AC1–AC2; NFR-006 AC7
 *
 * Same-origin `/v1/...` by default (Firebase Hosting rewrite). Calls passed
 * `direct: true` go to the Cloud Run URL instead, for requests that can
 * outlast the 60 s rewrite limit.
 */

import { directApiUrl } from '../config';
import { appLog, newId } from '../diagnostics/appLog';

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly path: string,
    readonly detail: string,
    readonly requestId?: string,
    readonly correlationId?: string,
  ) {
    super(detail || `HTTP ${status}`);
    this.name = status === 0 ? 'NetworkError' : `HTTP${status}`;
  }
}

/** Thrown by `TokenSource.getToken` when Firebase refuses to refresh the session. */
export class SessionEndedError extends Error {
  constructor(readonly code: string) {
    super(`Session ended (${code})`);
    this.name = 'SessionEndedError';
  }
}

export interface TokenSource {
  getToken(forceRefresh?: boolean): Promise<string | null>;
  onSessionExpired(): void;
}

let tokens: TokenSource | null = null;

export function configureApi(source: TokenSource | null): void {
  tokens = source;
}

export interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  body?: unknown;
  signal?: AbortSignal;
  correlationId?: string;
  direct?: boolean;
  where?: string;
  /** Skip the automatic error report (e.g. the report upload itself). */
  quiet?: boolean;
}

function baseUrl(direct: boolean | undefined): string {
  return direct && directApiUrl ? directApiUrl : '';
}

async function send(path: string, options: RequestOptions, token: string | null, requestId: string, correlationId: string) {
  const headers: Record<string, string> = {
    'x-request-id': requestId,
    'x-correlation-id': correlationId,
  };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (options.body !== undefined) headers['Content-Type'] = 'application/json';
  return fetch(`${baseUrl(options.direct)}${path}`, {
    method: options.method ?? 'GET',
    headers,
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
    signal: options.signal,
  });
}

async function detailOf(response: Response): Promise<string> {
  try {
    const data = (await response.json()) as { detail?: unknown };
    return typeof data.detail === 'string' ? data.detail : JSON.stringify(data.detail ?? '');
  } catch {
    return '';
  }
}

export async function apiRequest<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const requestId = newId();
  const correlationId = options.correlationId ?? requestId;
  const method = options.method ?? 'GET';
  const started = performance.now();
  const logPath = path.split('?')[0];
  let response: Response;
  try {
    let token = tokens ? await tokens.getToken() : null;
    response = await send(path, options, token, requestId, correlationId);
    if (response.status === 401 && tokens) {
      token = await tokens.getToken(true);
      if (token) response = await send(path, options, token, requestId, correlationId);
      if (response.status === 401) tokens.onSessionExpired();
    }
  } catch (error) {
    if (error instanceof SessionEndedError) {
      appLog.info('api', `${method} ${logPath} not sent: ${error.message}`, { request_id: requestId, correlation_id: correlationId });
      tokens?.onSessionExpired();
      throw new ApiError(401, logPath, 'Session expired', requestId, correlationId);
    }
    if (error instanceof DOMException && error.name === 'AbortError') {
      appLog.info('api', `${options.where ?? logPath} cancelled`);
      throw error;
    }
    const failure = new ApiError(0, logPath, error instanceof Error ? error.message : 'Network error', requestId, correlationId);
    appLog.log('warning', 'api', `${method} ${logPath} failed`, {
      request_id: requestId,
      correlation_id: correlationId,
      fields: { error: failure.message, duration_ms: Math.round(performance.now() - started) },
    });
    if (!options.quiet) appLog.error(options.where ?? `${method} ${logPath}`, failure, { category: 'api', path: logPath, request_id: requestId, correlation_id: correlationId });
    throw failure;
  }
  appLog.log(response.ok ? 'info' : 'warning', 'api', `${method} ${logPath} ${response.status}`, {
    request_id: requestId,
    correlation_id: correlationId,
    fields: { status: response.status, duration_ms: Math.round(performance.now() - started) },
  });
  if (!response.ok) {
    const failure = new ApiError(response.status, logPath, await detailOf(response), requestId, correlationId);
    if (!options.quiet && response.status !== 401 && response.status !== 404) {
      appLog.error(options.where ?? `${method} ${logPath}`, failure, {
        category: 'api',
        status: response.status,
        path: logPath,
        request_id: requestId,
        correlation_id: correlationId,
      });
    }
    throw failure;
  }
  if (response.status === 204) return undefined as T;
  const text = await response.text();
  return (text ? JSON.parse(text) : undefined) as T;
}

/** Fetches an API image with the bearer token (development builds without signed links). */
export async function fetchImageBlob(path: string): Promise<Blob> {
  let token: string | null;
  try {
    token = tokens ? await tokens.getToken() : null;
  } catch (error) {
    if (!(error instanceof SessionEndedError)) throw error;
    tokens?.onSessionExpired();
    throw new ApiError(401, path, 'Session expired');
  }
  const response = await fetch(path, { headers: token ? { Authorization: `Bearer ${token}` } : {} });
  if (!response.ok) throw new ApiError(response.status, path, 'image');
  return response.blob();
}
