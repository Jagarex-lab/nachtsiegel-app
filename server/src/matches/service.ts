import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { readFileSync } from 'node:fs';
import type { DatabaseSync } from 'node:sqlite';
import { compatible, type QueueEntry } from '../matchmaking/rules.js';
import { MatchError, SimulationAdapter, type SimulationState } from './simulation-adapter.js';
import type { Intent, MatchResult } from './rule-adapter.js';

export { MatchError } from './simulation-adapter.js';
export interface MatchOptions { now?: () => number; readyTimeoutMs?: number; turnTimeoutMs?: number; reconnectGraceMs?: number; queueTimeoutMs?: number }
export interface Message { protocol_version: number; type: string; request_id: string; [key: string]: unknown }
interface MatchRow {
  id: string; player_a: string; player_b: string; status: string; state: string; server_seed: string;
  rule_version: string; catalog_version: string; created_at: number; updated_at: number; deadline: number; result: string | null;
}
interface Participant { user_id: string; ready: number; action_sequence: number; connected: number; disconnect_deadline: number | null }
const schema = readFileSync(new URL('../../migrations/002_online_matches.sql', import.meta.url), 'utf8');
const canonical = (value: unknown): string => {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value !== null && typeof value === 'object') return `{${Object.keys(value).sort().map(k => `${JSON.stringify(k)}:${canonical((value as Record<string, unknown>)[k])}`).join(',')}}`;
  return JSON.stringify(value);
};
const hash = (value: string) => createHash('sha256').update(value).digest('hex');

/** Single-process local prototype. All state transitions and accepted request IDs
 * commit atomically. Never run multiple writers/processes against this SQLite DB. */
export class MatchService {
  readonly adapter = new SimulationAdapter();
  private readonly now: () => number;
  private readonly readyTimeoutMs: number;
  private readonly turnTimeoutMs: number;
  private readonly reconnectGraceMs: number;
  private readonly queueTimeoutMs: number;
  constructor(private readonly db: DatabaseSync, options: MatchOptions = {}) {
    this.now = options.now ?? Date.now;
    this.readyTimeoutMs = options.readyTimeoutMs ?? 30_000;
    this.turnTimeoutMs = options.turnTimeoutMs ?? 30_000;
    this.reconnectGraceMs = options.reconnectGraceMs ?? 90_000;
    this.queueTimeoutMs = options.queueTimeoutMs ?? 120_000;
    db.exec(schema);
    // A process restart invalidates all old socket presence but preserves state.
    db.prepare(`UPDATE online_match_players SET connected=0, disconnect_deadline=?
      WHERE match_id IN (SELECT id FROM online_matches WHERE status IN ('waiting_ready','active'))`).run(this.now() + this.reconnectGraceMs);
  }
  activeMatchFor(userId: string): string | null {
    const row = this.db.prepare(`SELECT id FROM online_matches WHERE (player_a=? OR player_b=?) AND status IN ('waiting_ready','active') LIMIT 1`).get(userId, userId) as { id: string } | undefined;
    return row?.id ?? null;
  }
  participants(matchId: string): string[] {
    const row = this.db.prepare('SELECT player_a,player_b FROM online_matches WHERE id=?').get(matchId) as MatchRow | undefined;
    return row ? [row.player_a, row.player_b] : [];
  }
  connected(userId: string): void {
    this.db.prepare(`UPDATE online_match_players SET connected=1,disconnect_deadline=NULL
      WHERE user_id=? AND match_id IN (SELECT id FROM online_matches WHERE status IN ('waiting_ready','active'))`).run(userId);
  }
  disconnected(userId: string): void {
    this.db.prepare(`UPDATE online_match_players SET connected=0,disconnect_deadline=COALESCE(disconnect_deadline,?)
      WHERE user_id=? AND match_id IN (SELECT id FROM online_matches WHERE status IN ('waiting_ready','active'))`).run(this.now() + this.reconnectGraceMs, userId);
    // A socket loss must never leave an unattended search active.
    this.db.prepare('DELETE FROM online_matchmaking_entries WHERE user_id=?').run(userId);
  }
  handle(userId: string, message: Message): object {
    this.tick();
    if (message.protocol_version !== 1 || typeof message.request_id !== 'string') throw new MatchError('INVALID_MESSAGE');
    const fingerprint = hash(canonical(message));
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const prior = this.db.prepare('SELECT body_hash,response FROM online_requests WHERE user_id=? AND request_id=?').get(userId, message.request_id) as { body_hash: string; response: string } | undefined;
      if (prior) {
        if (prior.body_hash !== fingerprint) throw new MatchError('REQUEST_ID_CONFLICT', 409);
        this.db.exec('COMMIT');
        return JSON.parse(prior.response) as object;
      }
      const result = this.dispatch(userId, message);
      this.db.prepare('INSERT INTO online_requests VALUES(?,?,?,?,?)').run(userId, message.request_id, fingerprint, JSON.stringify(result), this.now());
      this.db.exec('COMMIT');
      return result;
    } catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }
  private dispatch(userId: string, message: Message): object {
    const reply = (type: string, body: object = {}) => ({ protocol_version: 1, type, request_id: message.request_id, ...body });
    switch (message.type) {
      case 'session.resume': {
        const id = this.activeMatchFor(userId);
        return id ? { ...this.view(userId, id), request_id: message.request_id } : reply('session.resumed', { match_id: null });
      }
      case 'matchmaking.join': {
        if (message.mode !== 'casual') throw new MatchError('MODE_DISABLED');
        if (typeof message.region !== 'string' || !/^[a-z0-9-]{1,24}$/.test(message.region)) throw new MatchError('INVALID_REGION');
        const active = this.activeMatchFor(userId);
        if (active) return reply('match.found', { match_id: active });
        // Fixed test rating is server-owned. Production adapter must read ranked profile.
        this.db.prepare('INSERT OR IGNORE INTO online_matchmaking_entries VALUES(?,?,?,?,?)').run(userId, message.region, 1000, this.now(), this.now() + this.queueTimeoutMs);
        const me = this.db.prepare('SELECT * FROM online_matchmaking_entries WHERE user_id=?').get(userId) as unknown as QueueEntry;
        const candidates = this.db.prepare('SELECT * FROM online_matchmaking_entries WHERE region=? AND user_id<>? ORDER BY joined_at,user_id').all(me.region, userId) as unknown as QueueEntry[];
        const other = candidates.find(row => !this.activeMatchFor(row.user_id) && !this.blocked(userId, row.user_id) && compatible(me, row, this.now()));
        if (other) return reply('match.found', { match_id: this.createMatch(other.user_id, userId) });
        return reply('matchmaking.queued', { mode: 'casual', region: me.region, expires_at: this.now() + this.queueTimeoutMs });
      }
      case 'matchmaking.leave':
        this.db.prepare('DELETE FROM online_matchmaking_entries WHERE user_id=?').run(userId);
        return reply('matchmaking.left');
      case 'private.create': {
        if (this.activeMatchFor(userId)) throw new MatchError('ALREADY_IN_MATCH', 409);
        const code = randomBytes(12).toString('base64url');
        this.db.prepare('DELETE FROM online_matchmaking_entries WHERE user_id=?').run(userId);
        this.db.prepare('DELETE FROM online_private_invites WHERE creator_id=?').run(userId);
        this.db.prepare('INSERT INTO online_private_invites VALUES(?,?,?)').run(hash(code), userId, this.now() + this.queueTimeoutMs);
        return reply('private.created', { invite_code: code, expires_at: this.now() + this.queueTimeoutMs });
      }
      case 'private.join': {
        if (this.activeMatchFor(userId)) throw new MatchError('ALREADY_IN_MATCH', 409);
        if (typeof message.invite_code !== 'string') throw new MatchError('INVALID_INVITE');
        const invite = this.db.prepare('SELECT * FROM online_private_invites WHERE code_hash=? AND expires_at>?').get(hash(message.invite_code), this.now()) as { creator_id: string } | undefined;
        if (!invite || invite.creator_id === userId || this.activeMatchFor(invite.creator_id) || this.blocked(userId, invite.creator_id)) throw new MatchError('INVALID_INVITE');
        return reply('match.found', { match_id: this.createMatch(invite.creator_id, userId) });
      }
      case 'match.ready': {
        const row = this.authorized(userId, message.match_id);
        if (row.status !== 'waiting_ready') throw new MatchError('INVALID_MATCH_PHASE', 409);
        if (this.participant(row.id, userId).ready === 1) return { ...this.view(userId, row.id), request_id: message.request_id };
        this.db.prepare('UPDATE online_match_players SET ready=1,connected=1,disconnect_deadline=NULL WHERE match_id=? AND user_id=?').run(row.id, userId);
        const pending = this.db.prepare('SELECT COUNT(*) AS n FROM online_match_players WHERE match_id=? AND ready=0').get(row.id) as { n: number };
        this.event(row.id, { type: 'match.player_ready', player_id: userId });
        if (pending.n === 0) {
          this.db.prepare("UPDATE online_matches SET status='active',deadline=?,updated_at=? WHERE id=?").run(this.now() + this.turnTimeoutMs, this.now(), row.id);
          this.event(row.id, { type: 'match.started' });
        }
        return { ...this.view(userId, row.id), request_id: message.request_id };
      }
      case 'match.action': {
        const row = this.authorized(userId, message.match_id);
        if (row.status !== 'active') throw new MatchError('INVALID_MATCH_PHASE', 409);
        const p = this.participant(row.id, userId);
        if (!Number.isSafeInteger(message.sequence) || message.sequence !== p.action_sequence + 1) throw new MatchError('INVALID_SEQUENCE', 409);
        if (!message.action || typeof message.action !== 'object' || Array.isArray(message.action) || Object.keys(message.action).length !== 1) throw new MatchError('INVALID_ACTION');
        const action = message.action as Intent;
        const state = this.adapter.deserialize(row.state);
        this.adapter.validate_action(state, userId, action);
        const next = this.adapter.apply_action(state, userId, action, row.server_seed);
        this.db.prepare('UPDATE online_match_players SET action_sequence=? WHERE match_id=? AND user_id=?').run(message.sequence as number, row.id, userId);
        this.db.prepare('UPDATE online_matches SET state=?,updated_at=?,deadline=? WHERE id=?').run(this.adapter.serialize(next), this.now(), this.now() + this.turnTimeoutMs, row.id);
        const cursor = this.event(row.id, { type: 'match.action_accepted', player_id: userId, action, action_sequence: message.sequence, public_events: this.adapter.get_public_events(next) });
        this.db.prepare('INSERT INTO online_match_actions VALUES(?,?,?,?,?)').run(row.id, cursor, userId, JSON.stringify(action), message.request_id);
        const result = this.adapter.get_result(next);
        if (result) this.finish(row.id, result);
        return { ...this.view(userId, row.id), request_id: message.request_id };
      }
      case 'match.reconnect': {
        const row = this.authorized(userId, message.match_id);
        this.connected(userId);
        return { ...this.view(userId, row.id, message.after_sequence as number | undefined), request_id: message.request_id };
      }
      default: throw new MatchError('UNKNOWN_MESSAGE');
    }
  }
  private blocked(a: string, b: string): boolean {
    const exists = this.db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='social_blocks'").get();
    if (!exists) return false;
    return !!this.db.prepare('SELECT 1 FROM social_blocks WHERE (owner_id=? AND target_id=?) OR (owner_id=? AND target_id=?)').get(a, b, b, a);
  }
  private createMatch(a: string, b: string): string {
    if (a === b || this.activeMatchFor(a) || this.activeMatchFor(b)) throw new MatchError('ALREADY_IN_MATCH', 409);
    const id = randomUUID(), seed = randomBytes(32).toString('hex');
    const state = this.adapter.create_state([a, b], seed);
    this.db.prepare('INSERT INTO online_matches VALUES(?,?,?,?,?,?,?,?,?,?,?,?)').run(id, a, b, 'waiting_ready', this.adapter.serialize(state), seed, this.adapter.ruleVersion, this.adapter.catalogVersion, this.now(), this.now(), this.now() + this.readyTimeoutMs, null);
    for (const player of [a, b]) {
      this.db.prepare('INSERT INTO online_match_players(match_id,user_id,connected,disconnect_deadline) VALUES(?,?,1,NULL)').run(id, player);
      this.db.prepare('DELETE FROM online_matchmaking_entries WHERE user_id=?').run(player);
      this.db.prepare('DELETE FROM online_private_invites WHERE creator_id=?').run(player);
    }
    this.event(id, { type: 'match.found' });
    return id;
  }
  private authorized(userId: string, matchId: unknown): MatchRow {
    if (typeof matchId !== 'string') throw new MatchError('MATCH_NOT_FOUND', 404);
    const row = this.db.prepare('SELECT * FROM online_matches WHERE id=? AND (player_a=? OR player_b=?)').get(matchId, userId, userId) as MatchRow | undefined;
    if (!row) throw new MatchError('MATCH_NOT_FOUND', 404);
    return row;
  }
  private participant(matchId: string, userId: string): Participant {
    return this.db.prepare('SELECT * FROM online_match_players WHERE match_id=? AND user_id=?').get(matchId, userId) as unknown as Participant;
  }
  private event(matchId: string, event: object): number {
    const count = this.db.prepare('SELECT COALESCE(MAX(sequence),0)+1 AS next FROM online_match_events WHERE match_id=?').get(matchId) as { next: number };
    this.db.prepare('INSERT INTO online_match_events VALUES(?,?,?,?)').run(matchId, count.next, JSON.stringify(event), this.now());
    return count.next;
  }
  private finish(matchId: string, result: MatchResult, cancelled = false): void {
    const row = this.db.prepare('SELECT * FROM online_matches WHERE id=?').get(matchId) as unknown as MatchRow;
    if (row.status === 'finished' || row.status === 'cancelled') return;
    const state = this.adapter.deserialize(row.state);
    state.result = result;
    this.db.prepare('UPDATE online_matches SET status=?,result=?,state=?,updated_at=? WHERE id=?').run(cancelled ? 'cancelled' : 'finished', JSON.stringify(result), this.adapter.serialize(state), this.now(), matchId);
    this.event(matchId, { type: cancelled ? 'match.cancelled' : 'match.finished', result });
  }
  view(userId: string, matchId: string, afterSequence = 0): Record<string, unknown> {
    const row = this.authorized(userId, matchId);
    if (!Number.isSafeInteger(afterSequence) || afterSequence < 0) throw new MatchError('INVALID_EVENT_CURSOR');
    const cursor = this.db.prepare('SELECT COALESCE(MAX(sequence),0) AS sequence FROM online_match_events WHERE match_id=?').get(row.id) as { sequence: number };
    if (afterSequence > cursor.sequence) throw new MatchError('INVALID_EVENT_CURSOR');
    const events = this.db.prepare('SELECT sequence,event,created_at FROM online_match_events WHERE match_id=? AND sequence>? ORDER BY sequence').all(row.id, afterSequence) as { sequence: number; event: string; created_at: number }[];
    return {
      protocol_version: 1, type: 'match.state', match_id: row.id, status: row.status,
      rule_version: row.rule_version, catalog_version: row.catalog_version,
      sequence: cursor.sequence, next_action_sequence: this.participant(row.id, userId).action_sequence + 1,
      deadline: row.deadline, state: this.adapter.get_player_view(this.adapter.deserialize(row.state), userId),
      events: events.map(e => ({ sequence: e.sequence, timestamp: e.created_at, ...JSON.parse(e.event) as object })),
    };
  }
  history(userId: string): object[] {
    const rows = this.db.prepare('SELECT * FROM online_matches WHERE player_a=? OR player_b=? ORDER BY created_at DESC,id DESC LIMIT 100').all(userId, userId) as unknown as MatchRow[];
    return rows.map(r => ({ match_id: r.id, players: [r.player_a, r.player_b], status: r.status, created_at: r.created_at, updated_at: r.updated_at, rule_version: r.rule_version, catalog_version: r.catalog_version, result: r.result ? JSON.parse(r.result) : null, simulation: true }));
  }
  replay(userId: string, matchId: string): object {
    const row = this.authorized(userId, matchId);
    if (row.status !== 'finished' && row.status !== 'cancelled') throw new MatchError('REPLAY_NOT_AVAILABLE', 409);
    const actions = this.db.prepare('SELECT sequence,user_id,action FROM online_match_actions WHERE match_id=? ORDER BY sequence').all(matchId) as { sequence: number; user_id: string; action: string }[];
    return { simulation: true, match_id: matchId, rule_version: row.rule_version, catalog_version: row.catalog_version, players: [row.player_a, row.player_b], server_seed: row.server_seed, created_at: row.created_at, finished_at: row.updated_at, actions: actions.map(a => ({ sequence: a.sequence, player_id: a.user_id, action: JSON.parse(a.action) })), events: this.replayEvents(matchId), result: row.result ? JSON.parse(row.result) : null };
  }
  private replayEvents(matchId: string): object[] {
    const rows = this.db.prepare('SELECT sequence,event,created_at FROM online_match_events WHERE match_id=? ORDER BY sequence').all(matchId) as { sequence: number; event: string; created_at: number }[];
    return rows.map(row => ({ sequence: row.sequence, timestamp: row.created_at, ...JSON.parse(row.event) as object }));
  }
  /** Called by account lifecycle transport before anonymizing a user. */
  abortAccount(userId: string): void {
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const id = this.activeMatchFor(userId);
      if (id) this.finish(id, { winner_id: null, reason: 'account_deleted' }, true);
      this.db.prepare('DELETE FROM online_matchmaking_entries WHERE user_id=?').run(userId);
      this.db.prepare('DELETE FROM online_private_invites WHERE creator_id=?').run(userId);
      this.db.prepare('DELETE FROM online_requests WHERE user_id=?').run(userId);
      this.db.exec('COMMIT');
    } catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }
  tick(): string[] {
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const changed: string[] = [];
      const now = this.now();
      this.db.prepare('DELETE FROM online_matchmaking_entries WHERE expires_at<=?').run(now);
      this.db.prepare('DELETE FROM online_private_invites WHERE expires_at<=?').run(now);
      this.db.prepare('DELETE FROM online_requests WHERE created_at<?').run(now - 86_400_000);
      const rows = this.db.prepare("SELECT * FROM online_matches WHERE status IN ('waiting_ready','active')").all() as unknown as MatchRow[];
      for (const row of rows) {
        if (row.status === 'waiting_ready' && row.deadline <= now) { this.finish(row.id, { winner_id: null, reason: 'ready_timeout' }, true); changed.push(row.id); continue; }
        const players = this.db.prepare('SELECT * FROM online_match_players WHERE match_id=?').all(row.id) as unknown as Participant[];
        const expired = players.filter(p => p.disconnect_deadline !== null && p.disconnect_deadline <= now);
        if (expired.length > 0) {
          this.finish(row.id, { winner_id: expired.length === 2 ? null : players.find(p => p.user_id !== expired[0]!.user_id)!.user_id, reason: 'reconnect_timeout' }); changed.push(row.id); continue;
        }
        // Suppress turn-timeout enforcement while disconnected; the original
        // deadline stays unchanged. Reconnect grants no extra turn time.
        if (row.status === 'active' && row.deadline <= now && players.every(p => p.connected === 1)) {
          const state = this.adapter.deserialize(row.state);
          this.finish(row.id, { winner_id: state.players[1 - state.turn]!, reason: 'simulation_turn_timeout' }); changed.push(row.id);
        }
      }
      this.db.exec('COMMIT');
      return changed;
    } catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }
}
