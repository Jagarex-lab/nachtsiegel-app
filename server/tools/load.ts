import { randomUUID } from 'node:crypto';
import { performance } from 'node:perf_hooks';
import { pathToFileURL } from 'node:url';
import WebSocket from 'ws';
import { createApp } from '../src/transport/app.js';
import { SimulationAdapter } from '../src/matches/simulation-adapter.js';

type Message = Record<string, any>;
export class SimulatedClient {
  socket!: WebSocket;
  messages: Message[] = [];
  private pending = new Map<string, { resolve: (value: Message) => void; reject: (reason: Error) => void; timer: NodeJS.Timeout }>();
  constructor(readonly url: string, readonly wsUrl: string, readonly token: string, readonly userId: string) {}
  async request(path: string, body?: object, method = 'POST'): Promise<Message> {
    const response = await fetch(`${this.url}${path}`, { method, headers: { authorization: `Bearer ${this.token}`, 'content-type': 'application/json' }, ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
    const value = await response.json() as Message;
    if (!response.ok) throw new Error(`HTTP ${response.status}: ${String(value.code ?? value.error?.code ?? 'request_failed')}`);
    return value;
  }
  async connect(): Promise<void> {
    const ticket = await this.request('/transport/ticket', {});
    const socket = new WebSocket(`${this.wsUrl}/ws?ticket=${encodeURIComponent(ticket.ticket)}`);
    this.socket = socket;
    socket.on('message', raw => {
      const message = JSON.parse(raw.toString()) as Message;
      this.messages.push(message);
      const waiting = this.pending.get(message.request_id);
      if (waiting) { clearTimeout(waiting.timer); this.pending.delete(message.request_id); waiting.resolve(message); }
    });
    await new Promise<void>((resolve, reject) => { socket.once('open', resolve); socket.once('error', reject); });
  }
  send(type: string, fields: object = {}, requestId: string = randomUUID()): Promise<Message> {
    return this.raw({ protocol_version: 1, type, request_id: requestId, ...fields });
  }
  raw(message: Message): Promise<Message> {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => { this.pending.delete(message.request_id); reject(new Error(`WS response timeout: ${String(message.type)}`)); }, 10_000);
      this.pending.set(message.request_id, { resolve, reject, timer });
      this.socket.send(JSON.stringify(message));
    });
  }
  async disconnect(): Promise<void> {
    if (this.socket.readyState === WebSocket.CLOSED) return;
    await new Promise<void>(resolve => { this.socket.once('close', resolve); this.socket.close(); });
  }
}
export async function registerClient(url: string, wsUrl: string, index: number): Promise<SimulatedClient> {
  const username = `load_${index}_${randomUUID().slice(0, 8)}`;
  const password = `Local-${randomUUID()}-42!`;
  const registered = await fetch(`${url}/auth/register`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ username, password, display_name: `Local Player ${index}` }) });
  if (!registered.ok) throw new Error(`Registration failed: ${registered.status}`);
  const response = await fetch(`${url}/auth/login`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ username, password, client: 'native' }) });
  const login = await response.json() as Message;
  if (!response.ok || !login.token) throw new Error(`Login failed: ${response.status}`);
  const profileResponse = await fetch(`${url}/profile`, { headers: { authorization: `Bearer ${login.token}` } });
  const profile = await profileResponse.json() as Message;
  const userId = profile.playerId ?? profile.player_id ?? profile.user_id ?? profile.id ?? profile.profile?.player_id ?? profile.profile?.user_id ?? profile.profile?.id;
  if (typeof userId !== 'string') throw new Error('Profile missing player ID');
  const client = new SimulatedClient(url, wsUrl, login.token, userId);
  await client.connect();
  return client;
}
function errorCode(value: Message): string | undefined { return value.code ?? value.error?.code; }
function percentile(values: number[], quantile: number): number {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return Math.round(sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * quantile))]! * 100) / 100;
}
export async function runLoad(clientCount: number): Promise<object> {
  if (!Number.isInteger(clientCount) || clientCount < 2 || clientCount > 200 || clientCount % 2) throw new Error('Clients must be an even integer from 2 to 200');
  // This measures transport capacity, never gameplay. Real duel validation is
  // tools/real-duel.ts and the default server does not install this adapter.
  const app = await createApp({ dbPath: ':memory:', port: 0, ruleAdapter: new SimulationAdapter() });
  const { url, wsUrl } = await app.start();
  const clients: SimulatedClient[] = [];
  const latencies: number[] = [];
  const setupLatencies: number[] = [];
  let peakRss = process.memoryUsage().rss;
  const memorySampler = setInterval(() => { peakRss = Math.max(peakRss, process.memoryUsage().rss); }, 25);
  const started = performance.now();
  const cpuStart = process.cpuUsage();
  let successfulRequests = 0;
  let attemptedRequests = 0;
  let expectedRejections = 0;
  let matchesFinished = 0;
  let reconnects = 0;
  const errors: string[] = [];
  const timed = async (client: SimulatedClient, type: string, fields: object = {}, id?: string) => {
    const start = performance.now();
    attemptedRequests++;
    const response = await client.send(type, fields, id);
    latencies.push(performance.now() - start);
    if (errorCode(response) || response.type === 'error') throw new Error(`Unexpected ${type} rejection: ${errorCode(response)}`);
    successfulRequests++;
    return response;
  };
  try {
    // Batches cap Argon2 memory pressure while retaining concurrent authentication.
    for (let offset = 0; offset < clientCount; offset += 2) {
      const setup = async (index: number) => {
        const setupStart = performance.now();
        const client = await registerClient(url, wsUrl, index);
        setupLatencies.push(performance.now() - setupStart);
        return client;
      };
      const created = await Promise.all([setup(offset), setup(offset + 1)]);
      clients.push(...created);
    }
    await Promise.all(clients.map(client => timed(client, 'matchmaking.join', { mode: 'casual', region: 'local' })));
    const resumes = await Promise.all(clients.map(client => timed(client, 'session.resume')));
    const byMatch = new Map<string, SimulatedClient[]>();
    for (let i = 0; i < clients.length; i++) {
      const resume = resumes[i]!;
      const matchId = resume.match_id ?? resume.match?.match_id ?? resume.state?.match_id;
      if (!matchId) throw new Error('session.resume did not identify assigned match');
      byMatch.set(matchId, [...byMatch.get(matchId) ?? [], clients[i]!]);
    }
    await Promise.all([...byMatch].map(async ([matchId, players]) => {
      if (players.length !== 2) throw new Error('Duplicate or missing match assignment');
      await timed(players[0]!, 'match.ready', { match_id: matchId });
      await timed(players[1]!, 'match.ready', { match_id: matchId });
      let view = await timed(players[0]!, 'match.reconnect', { match_id: matchId, after_sequence: 0 });
      const turnId = view.state?.turn_player_id;
      const actor = players.find(client => client.userId === turnId);
      if (!actor) throw new Error('No assigned active player');
      const actorView = await timed(actor, 'match.reconnect', { match_id: matchId, after_sequence: 0 });
      const duplicateId = randomUUID();
      const action = { match_id: matchId, sequence: actorView.next_action_sequence, action: { type: 'advance' } };
      await timed(actor, 'match.action', action, duplicateId);
      await timed(actor, 'match.action', action, duplicateId);
      const invalid = await actor.raw({ protocol_version: 1, type: 'match.action', request_id: randomUUID(), match_id: matchId, sequence: actorView.next_action_sequence + 1, action: { type: 'advance', damage: 9999 } });
      if (!errorCode(invalid) && invalid.type !== 'error') throw new Error('Forged resources were accepted');
      expectedRejections++;
      await players[1]!.disconnect();
      await players[1]!.connect();
      reconnects++;
      view = await timed(players[1]!, 'match.reconnect', { match_id: matchId, after_sequence: actorView.sequence });
      await timed(players[1]!, 'match.action', { match_id: matchId, sequence: view.next_action_sequence, action: { type: 'concede' } });
      const history = await players[0]!.request('/matches/history', undefined, 'GET');
      const rows = Array.isArray(history) ? history : history.matches ?? history.history;
      if (!Array.isArray(rows) || !rows.some((row: Message) => row.match_id === matchId)) throw new Error('Finished match missing from history');
      matchesFinished++;
    }));
  } catch (error) { errors.push(error instanceof Error ? error.message : 'unknown_error'); }
  finally { clearInterval(memorySampler); peakRss = Math.max(peakRss, process.memoryUsage().rss); await Promise.all(clients.map(client => client.disconnect().catch(() => {}))); await app.close(); }
  const durationMs = performance.now() - started;
  const cpu = process.cpuUsage(cpuStart);
  return {
    prototype: 'simulation-only; no ORAFOLD combat or capacity guarantee', clients: clientCount,
    matches_finished: matchesFinished, reconnects, successful_ws_requests: successfulRequests,
    expected_security_rejections: expectedRejections, unexpected_errors: errors,
    attempted_measured_ws_requests: attemptedRequests,
    auth_setup_latency_ms: { p50: percentile(setupLatencies, 0.5), p95: percentile(setupLatencies, 0.95) },
    duration_ms: Math.round(durationMs), ws_requests_per_second_including_auth_setup: Math.round(successfulRequests / (durationMs / 1000) * 100) / 100,
    ws_latency_ms: { p50: percentile(latencies, 0.5), p95: percentile(latencies, 0.95), max: Math.round(Math.max(...latencies, 0) * 100) / 100 },
    process_rss_mib: Math.round(process.memoryUsage().rss / 1024 / 1024 * 100) / 100,
    sampled_peak_rss_mib: Math.round(peakRss / 1024 / 1024 * 100) / 100,
    process_cpu_ms: { user: Math.round(cpu.user / 1000), system: Math.round(cpu.system / 1000) },
    timestamp: new Date().toISOString(),
  };
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const levels = process.argv.slice(2).length ? process.argv.slice(2).map(Number) : [2, 10, 30];
  for (const level of levels) {
    const result = await runLoad(level);
    console.log(JSON.stringify(result));
    if ((result as { unexpected_errors: string[] }).unexpected_errors.length) process.exitCode = 1;
  }
}
