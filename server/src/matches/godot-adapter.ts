import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { DeckSelection, Intent, MatchResult, RuleAdapter, RuleEvent } from './rule-adapter.js';
import { MatchError } from './simulation-adapter.js';

export interface GodotState {
  players: [string, string];
  views: Record<string, Record<string, unknown>>;
  turn_player_id: string | null;
  result: MatchResult | null;
  loadouts: [DeckSelection, DeckSelection];
  commands: unknown[];
  [key: string]: unknown;
}

/** A deliberately local, synchronous bridge. The isolated headless Godot worker
 * reconstructs the durable command journal for every accepted intention. There
 * is no JavaScript implementation of the game and no match state to lose on a
 * server restart. One process/SQLite writer is required. */
export class GodotRuleAdapter implements RuleAdapter<GodotState> {
  readonly ruleVersion = 'orafold550-godot-4.6.3-alpha03';
  readonly catalogVersion = 'orafold550-production';
  private readonly project = fileURLToPath(new URL('../../../', import.meta.url));
  private readonly binary = process.env.ORAFOLD_GODOT_BIN ?? 'godot';
  private cachedCatalog: object | undefined;

  private request(body: object): Record<string, any> {
    if (!existsSync(`${this.project}/scripts/online/server_worker.gd`)) throw new MatchError('RULE_ENGINE_UNAVAILABLE', 503);
    const runtime = join(tmpdir(), 'orafold-online-worker');
    mkdirSync(runtime, { recursive: true, mode: 0o700 });
    const result = spawnSync('python3', [`${this.project}/scripts/online/godot_bridge.py`, '--project', this.project, '--godot', this.binary], {
      input: `${JSON.stringify(body)}\n`, encoding: 'utf8', timeout: 60_000,
      maxBuffer: 8 * 1024 * 1024,
      env: { ...process.env, GODOT_SILENCE_ROOT_WARNING: '1', XDG_DATA_HOME: runtime, XDG_CACHE_HOME: runtime },
    });
    if (result.error || result.signal || result.status !== 0) throw new MatchError('RULE_ENGINE_UNAVAILABLE', 503);
    // Godot prints its version banner before the single NDJSON response.
    let response: Record<string, any> | undefined;
    for (const line of result.stdout.split('\n')) {
      try { const candidate = JSON.parse(line.startsWith('ORAFOLD_RESULT ') ? line.slice(15) : line); if (candidate && typeof candidate.ok === 'boolean') response = candidate; } catch { /* engine banner */ }
    }
    if (!response) throw new MatchError('RULE_ENGINE_INVALID_RESPONSE', 503);
    if (!response.ok) {
      const code = typeof response.error === 'string' && /^[A-Z0-9_]{1,80}$/.test(response.error) ? response.error : 'ILLEGAL_COMMAND';
      const unavailable = ['RULE_ENGINE_UNAVAILABLE', 'ENGINE_VERSION_MISMATCH', 'CATALOG_VERSION_MISMATCH', 'INVALID_SERVER_STATE', 'INVALID_JOURNAL', 'REPLAY_DIVERGED', 'REPLAY_COMMAND_REJECTED', 'START_FAILED'].includes(code);
      throw new MatchError(code, unavailable ? 503 : code === 'FORBIDDEN' ? 403 : 409);
    }
    return response;
  }
  create_state(players: [string, string], seed: string, loadouts?: [DeckSelection | null, DeckSelection | null]): GodotState {
    return this.request({ op: 'create', players, seed, loadouts: loadouts ?? [null, null] }).state as GodotState;
  }
  validate_action(state: GodotState, player: string, action: Intent): void {
    if (!state.players.includes(player)) throw new MatchError('FORBIDDEN', 403);
    if (state.result) throw new MatchError('MATCH_FINISHED', 409);
    if (action.type === 'concede' && Object.keys(action).length === 1) return;
    if (action.type !== 'command' || Object.keys(action).sort().join(',') !== 'args,name,type' || typeof action.name !== 'string' || !Array.isArray(action.args)) throw new MatchError('INVALID_ACTION');
  }
  apply_action(state: GodotState, player: string, action: Intent, _seed: string): GodotState {
    this.validate_action(state, player, action);
    return this.request({ op: 'apply', state, player, action }).state as GodotState;
  }
  get_player_view(state: GodotState, player: string | null): object {
    if (player === null || !state.players.includes(player)) throw new MatchError('FORBIDDEN', 403);
    const view = state.views[player];
    if (!view || typeof view !== 'object') throw new MatchError('RULE_ENGINE_INVALID_RESPONSE', 503);
    return { ...structuredClone(view), ...(state.result ? { finished: true, winner_player_id: state.result.winner_id } : {}), result: state.result ?? null };
  }
  get_public_events(_state: GodotState): RuleEvent[] { return []; }
  get_result(state: GodotState): MatchResult | null { return state.result ? { ...state.result } : null; }
  serialize(state: GodotState): string { return JSON.stringify(state); }
  deserialize(serialized: string): GodotState { return JSON.parse(serialized) as GodotState; }
  catalog(): object { return this.cachedCatalog ??= this.request({ op: 'catalog' }).catalog as object; }
  validate_deck(selection: DeckSelection): DeckSelection { return this.request({ op: 'validate_deck', selection }).selection as DeckSelection; }
  verify_state(state: GodotState): GodotState {
    const verified = this.request({ op: 'verify', state }).state as GodotState;
    // Ready/reconnect deadlines and account deletion belong to the server's
    // lifecycle, outside the card kernel. Preserve their recorded terminal
    // result after independently rebuilding the exact kernel journal/RNG.
    if (!verified.result && state.result && ['ready_timeout', 'turn_timeout', 'reconnect_timeout', 'account_deleted'].includes(state.result.reason)) verified.result = structuredClone(state.result);
    return verified;
  }
}
