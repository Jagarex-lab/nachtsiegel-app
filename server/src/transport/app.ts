import { createServer, type IncomingMessage, type ServerResponse } from 'node:http';
import { randomBytes, timingSafeEqual } from 'node:crypto';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { WebSocketServer, WebSocket } from 'ws';
import { z } from 'zod';
import { openDatabase } from '../persistence/database.js';
import { AuthService, AuthError } from '../auth/service.js';
import { RateLimiter } from '../security/rate-limit.js';
import { MatchService, MatchError } from '../matches/service.js';
import { SocialService } from '../social/service.js';
import { MAX_MESSAGE_BYTES, parseMessage } from './protocol.js';
import { localOnlyGuard, type AppOptions } from './config.js';

const credentials = z.object({ username: z.string().min(3).max(64), password: z.string().max(1024), client: z.literal('native').optional() }).strict();
const registration = z.object({ username: z.string().min(3).max(32), password: z.string().min(12).max(1024), display_name: z.string().min(2).max(40) }).strict();
const native = z.object({ client: z.literal('native').optional() }).strict();
const equal = (a: string, b: string) => Buffer.byteLength(a) === Buffer.byteLength(b) && timingSafeEqual(Buffer.from(a), Buffer.from(b));
const cookieName = 'orafold_session';

/** Local-only, one process / database prototype; no production listener or secrets. */
export async function createApp(options: AppOptions = {}) {
  localOnlyGuard();
  const host = options.host ?? '127.0.0.1';
  if (!['127.0.0.1', '::1', 'localhost'].includes(host) && !(host === '0.0.0.0' && process.env.LOCAL_CONTAINER === '1')) throw new Error('LOCAL_BIND_ONLY');
  const dbPath = options.dbPath ?? ':memory:';
  if (dbPath !== ':memory:') mkdirSync(dirname(dbPath), { recursive: true, mode: 0o700 });
  const db = openDatabase(dbPath);
  const auth = new AuthService(db, { sessionTtlMs: options.sessionTtlMs });
  const matches = new MatchService(db, { adapter: options.ruleAdapter });
  const social = new SocialService(db);
  const limiter = new RateLimiter();
  const tickets = new Map<string, { token: string; expires: number }>();
  const sockets = new Map<WebSocket, { token: string; userId: string; alive: boolean }>();
  let origin = options.origin ?? '';
  let authority = '';
  let authJobs = 0;
  let timer: ReturnType<typeof setInterval> | undefined;
  let lastHeartbeat = Date.now();
  const metrics = { http_requests: 0, websocket_messages: 0, rejected_requests: 0, server_errors: 0, connections: 0, disconnects: 0, reconnects: 0 };

  function tokenFor(req: IncomingMessage) {
    const bearer = req.headers.authorization;
    if (bearer !== undefined) {
      if (!/^Bearer [A-Za-z0-9_-]{43}$/.test(bearer)) throw new AuthError('UNAUTHENTICATED', 401);
      return { token: bearer.slice(7), cookie: false };
    }
    const token = req.headers.cookie?.split(';').map(s => s.trim()).find(s => s.startsWith(`${cookieName}=`))?.slice(cookieName.length + 1) ?? '';
    return { token, cookie: true };
  }
  function checkHost(req: IncomingMessage) {
    if (req.headers.host !== authority && req.headers.host !== new URL(origin).host) throw new AuthError('HOST_REJECTED', 403);
  }
  function identity(req: IncomingMessage, mutation = false) {
    const found = tokenFor(req);
    const session = auth.authenticate(found.token);
    if (found.cookie && mutation && (req.headers.origin !== origin || !equal(req.headers['x-csrf-token']?.toString() ?? '', session.csrfToken))) throw new AuthError('CSRF_REJECTED', 403);
    return { ...found, ...session };
  }
  function send(res: ServerResponse, status: number, body: unknown) {
    res.writeHead(status, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff', 'referrer-policy': 'no-referrer', 'content-security-policy': "default-src 'none'; frame-ancestors 'none'" });
    res.end(JSON.stringify(body));
  }
  function sessionResponse(res: ServerResponse, session: ReturnType<AuthService['rotate']>, returnToken: boolean) {
    if (!returnToken) res.setHeader('set-cookie', `${cookieName}=${session.token}; HttpOnly; SameSite=Strict; Path=/; Max-Age=${Math.max(0, Math.floor((session.expiresAt - Date.now()) / 1000))}${origin.startsWith('https:') ? '; Secure' : ''}`);
    send(res, 200, { ...(returnToken ? { token: session.token } : {}), csrf_token: session.csrfToken, profile: session.profile, expires_at: session.expiresAt });
  }
  async function body(req: IncomingMessage): Promise<unknown> {
    if (req.headers['content-type']?.split(';')[0] !== 'application/json') throw new AuthError('JSON_REQUIRED', 415);
    let size = 0;
    const chunks: Buffer[] = [];
    for await (const chunk of req) {
      size += chunk.length;
      if (size > MAX_MESSAGE_BYTES) throw new AuthError('MESSAGE_TOO_LARGE', 413);
      chunks.push(Buffer.from(chunk));
    }
    try { return JSON.parse(Buffer.concat(chunks).toString()); } catch { throw new AuthError('INVALID_JSON'); }
  }
  async function expensive<T>(work: () => Promise<T>): Promise<T> {
    if (authJobs >= 2) throw new AuthError('AUTH_BUSY', 429);
    authJobs++;
    try { return await work(); } finally { authJobs--; }
  }
  function broadcast(matchId: string) {
    for (const [socket, session] of sockets) {
      if (socket.readyState === WebSocket.OPEN && matches.participants(matchId).includes(session.userId)) {
        try {
          auth.authenticate(session.token);
          if (socket.bufferedAmount > 64 * 1024) { socket.close(1013, 'SLOW_CLIENT'); continue; }
          socket.send(JSON.stringify(matches.view(session.userId, matchId)));
        } catch { socket.close(1008, 'SESSION_INVALID'); }
      }
    }
  }

  const server = createServer(async (req, res) => {
    metrics.http_requests++;
    try {
      checkHost(req);
      if (req.headers.origin && req.headers.origin !== origin) throw new AuthError('ORIGIN_REJECTED', 403);
      const ip = req.socket.remoteAddress ?? 'local'; // Never trust client-supplied forwarding headers.
      if (!limiter.consume(`http:${ip}`, 600, 60_000)) throw new AuthError('RATE_LIMITED', 429);
      const path = new URL(req.url ?? '/', 'http://local').pathname;
      if (req.method === 'GET' && path === '/health') {
        db.prepare('SELECT 1').get();
        const catalog = matches.adapter.catalog ? matches.catalog() : null;
        return send(res, 200, { status: 'ok', prototype: true, public_server: false, protocol_version: 1, rule_version: matches.adapter.ruleVersion, rules_ready: catalog !== null, catalog });
      }
      if (req.method === 'GET' && path === '/catalog') return send(res, 200, matches.catalog());
      if (req.method === 'GET' && path === '/profile') return send(res, 200, auth.getProfile(identity(req).userId));
      if (req.method === 'GET' && path === '/auth/session') {
        const session = identity(req);
        return send(res, 200, { csrf_token: session.csrfToken, profile: auth.getProfile(session.userId), expires_at: session.expiresAt });
      }
      if (req.method === 'GET' && path === '/matches/history') return send(res, 200, { matches: matches.history(identity(req).userId) });
      if (req.method === 'GET' && /^\/matches\/[A-Za-z0-9_-]{1,80}\/replay$/.test(path)) return send(res, 200, matches.replay(identity(req).userId, path.split('/')[2]!));
      if (req.method === 'GET' && path === '/account/export') {
        const userId = identity(req).userId;
        return send(res, 200, { ...auth.exportAccount(userId), matches: matches.history(userId) });
      }
      if (req.method !== 'POST') throw new AuthError('NOT_FOUND', 404);
      const input = await body(req);
      if (path.startsWith('/auth/') || path === '/account/delete') {
        if (!limiter.consume(`auth:${ip}`, 100, 600_000)) throw new AuthError('RATE_LIMITED', 429);
        const username = (input as { username?: unknown })?.username;
        if (typeof username === 'string' && !limiter.consume(`account:${username.trim().toLowerCase().slice(0, 64)}`, 10, 600_000)) throw new AuthError('RATE_LIMITED', 429);
      }
      if (path === '/auth/register') {
        const data = registration.parse(input);
        try { await expensive(() => auth.register(data.username, data.password, data.display_name)); }
        catch (error) { if (!(error instanceof AuthError && error.code === 'REGISTRATION_UNAVAILABLE')) throw error; }
        return send(res, 202, { accepted: true });
      }
      if (path === '/auth/login') {
        const data = credentials.parse(input);
        return sessionResponse(res, await expensive(() => auth.login(data.username, data.password)), data.client === 'native');
      }
      if (path === '/auth/recovery') {
        const data = z.object({ username: z.string().max(64) }).strict().parse(input);
        return send(res, 202, auth.requestRecovery(data.username));
      }
      if (path === '/auth/reset') {
        const data = z.object({ token: z.string().max(80), password: z.string().min(12).max(1024) }).strict().parse(input);
        await expensive(() => auth.resetPassword(data.token, data.password));
        return send(res, 200, { ok: true });
      }
      const session = identity(req, true);
      if (path === '/auth/rotate') {
        const data = native.parse(input);
        // Cookie authority cannot be escalated into a script-readable bearer token.
        if (session.cookie && data.client) throw new AuthError('INVALID_MESSAGE');
        return sessionResponse(res, auth.rotate(session.token), !session.cookie);
      }
      if (path === '/auth/logout') {
        z.object({}).strict().parse(input);
        auth.logout(session.token);
        res.setHeader('set-cookie', `${cookieName}=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0${origin.startsWith('https:') ? '; Secure' : ''}`);
        return send(res, 200, { ok: true });
      }
      if (path === '/transport/ticket') {
        z.object({}).strict().parse(input);
        if (!limiter.consume(`ticket:${session.userId}`, 30, 60_000) || tickets.size >= 1024) throw new AuthError('RATE_LIMITED', 429);
        const ticket = randomBytes(32).toString('base64url');
        tickets.set(ticket, { token: session.token, expires: Date.now() + 30_000 });
        return send(res, 200, { ticket, expires_in: 30 });
      }
      if (path === '/account/delete') {
        const data = z.object({ password: z.string().max(1024) }).strict().parse(input);
        await expensive(() => auth.deleteAccount(session.userId, data.password));
        matches.abortAccount(session.userId);
        res.setHeader('set-cookie', `${cookieName}=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0${origin.startsWith('https:') ? '; Secure' : ''}`);
        return send(res, 200, { ok: true });
      }
      throw new AuthError('NOT_FOUND', 404);
    } catch (error) {
      metrics.rejected_requests++;
      const known = error instanceof AuthError || error instanceof MatchError;
      if (!known && !(error instanceof z.ZodError)) metrics.server_errors++;
      if (!res.headersSent) send(res, known ? error.status : error instanceof z.ZodError ? 400 : 500, { type: 'error', code: known ? error.code : error instanceof z.ZodError ? 'INVALID_MESSAGE' : 'INTERNAL_ERROR' });
    }
  });
  server.requestTimeout = 10_000;
  server.headersTimeout = 5000;
  server.maxHeadersCount = 40;
  const wss = new WebSocketServer({ noServer: true, maxPayload: MAX_MESSAGE_BYTES, perMessageDeflate: false });
  server.on('upgrade', (req, socket, head) => {
    try {
      checkHost(req);
      if (req.headers.origin && req.headers.origin !== origin) throw new Error();
      const url = new URL(req.url ?? '/', 'http://local');
      if (url.pathname !== '/ws' || !limiter.consume(`upgrade:${req.socket.remoteAddress}`, 100, 60_000)) throw new Error();
      const ticket = url.searchParams.get('ticket') ?? '';
      const entry = tickets.get(ticket);
      tickets.delete(ticket);
      if (!entry || entry.expires <= Date.now()) throw new Error();
      const session = auth.authenticate(entry.token);
      if (sockets.size >= 200 || [...sockets.values()].filter(s => s.userId === session.userId).length >= 2) throw new Error();
      wss.handleUpgrade(req, socket, head, ws => {
        const presence = { token: entry.token, userId: session.userId, alive: true };
        sockets.set(ws, presence);
        ws.on('pong', () => { presence.alive = true; });
        metrics.connections++;
        matches.connected(session.userId);
        ws.on('error', () => {}); // No payload or URL logging.
        ws.on('message', (raw, binary) => {
          metrics.websocket_messages++;
          let requestId: string | undefined;
          try {
            auth.authenticate(entry.token);
            if (binary) throw new AuthError('INVALID_MESSAGE');
            if (!limiter.consume(`ws:${session.userId}`, 120, 60_000)) throw new AuthError('RATE_LIMITED', 429);
            // Retain only a safe correlation ID, including on schema errors.
            const candidate = JSON.parse(raw.toString()) as { request_id?: unknown } | null;
            if (candidate && typeof candidate.request_id === 'string' && /^[A-Za-z0-9_-]{1,80}$/.test(candidate.request_id)) requestId = candidate.request_id;
            const message = parseMessage(raw.toString());
            if (ws.bufferedAmount > 64 * 1024) { ws.close(1013, 'SLOW_CLIENT'); return; }
            const result = message.type.startsWith('social.') ? social.handle(session.userId, message) : matches.handle(session.userId, message);
            ws.send(JSON.stringify(result));
            const matchId = matches.activeMatchFor(session.userId) ?? (typeof (message as { match_id?: unknown }).match_id === 'string' ? (message as { match_id: string }).match_id : null);
            if (matchId) {
              for (const userId of matches.participants(matchId)) if ([...sockets.values()].some(s => s.userId === userId)) matches.connected(userId);
              broadcast(matchId);
            }
            if (message.type === 'match.reconnect') metrics.reconnects++;
          } catch (error) {
            metrics.rejected_requests++;
            if (error instanceof AuthError && error.status === 401) { ws.close(1008, 'SESSION_INVALID'); return; }
            const known = error instanceof AuthError || error instanceof MatchError || (error instanceof Error && 'code' in error && 'status' in error);
            if (!known && !(error instanceof z.ZodError) && !(error instanceof SyntaxError)) metrics.server_errors++;
            ws.send(JSON.stringify({ protocol_version: 1, type: 'error', ...(requestId ? { request_id: requestId } : {}), code: known ? (error as AuthError).code : 'INVALID_MESSAGE' }));
          }
        });
        ws.on('close', () => {
          metrics.disconnects++;
          sockets.delete(ws);
          if (![...sockets.values()].some(s => s.userId === session.userId)) matches.disconnected(session.userId);
        });
      });
    } catch {
      socket.write('HTTP/1.1 401 Unauthorized\r\nConnection: close\r\nContent-Length: 0\r\n\r\n');
      socket.destroy();
    }
  });
  return {
    server, auth, matches, db, metrics,
    telemetry() {
      const n = (sql: string) => db.prepare(sql).get()!.n;
      return { ...metrics, active_sockets: sockets.size,
        active_sessions: n(`SELECT COUNT(*) AS n FROM sessions WHERE revoked_at IS NULL AND expires_at>${Date.now()}`),
        active_matches: n("SELECT COUNT(*) AS n FROM online_matches WHERE status IN ('waiting_ready','active')"),
        queue_entries: n('SELECT COUNT(*) AS n FROM online_matchmaking_entries'),
        oldest_queue_wait_ms: n(`SELECT COALESCE(MAX(${Date.now()}-joined_at),0) AS n FROM online_matchmaking_entries`),
      };
    },
    async start() {
      await new Promise<void>((resolve, reject) => { server.once('error', reject); server.listen(options.port ?? 0, host, resolve); });
      const address = server.address();
      if (!address || typeof address === 'string') throw new Error('LISTEN_FAILED');
      const url = `http://${host === '::1' ? '[::1]' : host}:${address.port}`;
      authority = new URL(url).host;
      origin ||= url;
      timer = setInterval(() => {
        for (const [ticket, data] of tickets) if (data.expires <= Date.now()) tickets.delete(ticket);
        for (const [socket, session] of sockets) { try { auth.authenticate(session.token); } catch { socket.close(1008, 'SESSION_INVALID'); } }
        if (Date.now() - lastHeartbeat >= 15_000) {
          lastHeartbeat = Date.now();
          for (const [socket, session] of sockets) {
            if (!session.alive) socket.terminate();
            else if (socket.readyState === WebSocket.OPEN) { session.alive = false; socket.ping(); }
          }
        }
        for (const matchId of matches.tick()) broadcast(matchId);
      }, 1000);
      timer.unref();
      return { url, wsUrl: url.replace('http:', 'ws:') };
    },
    async close() {
      if (timer) clearInterval(timer);
      for (const socket of sockets.keys()) socket.terminate();
      await new Promise<void>(resolve => wss.close(() => resolve()));
      server.closeAllConnections();
      await new Promise<void>(resolve => server.close(() => resolve()));
      db.close();
    },
  };
}
