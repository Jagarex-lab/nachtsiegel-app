import { createHash } from 'node:crypto';
import type { Intent, MatchResult, RuleAdapter, RuleEvent } from './rule-adapter.js';

/** Never expose this server-only state or its seed through transport. */
export interface SimulationState {
  players: [string, string];
  turn: number;
  acceptedActions: number;
  hidden: Record<string, { hand: string[]; deck: string[] }>;
  result: MatchResult | null;
  events: RuleEvent[];
}
export class MatchError extends Error {
  constructor(public readonly code: string, public readonly status = 400) { super(code); }
}
export class SimulationAdapter implements RuleAdapter<SimulationState> {
  readonly ruleVersion = 'transport-fixture-v1';
  readonly catalogVersion = 'no-game-catalog';
  create_state(players: [string, string], seed: string): SimulationState {
    const hidden: SimulationState['hidden'] = {};
    for (const player of players) {
      const opaque = (index: number) => createHash('sha256').update(`${seed}:${player}:${index}`).digest('hex').slice(0, 24);
      hidden[player] = { hand: [opaque(0), opaque(1)], deck: [opaque(2), opaque(3), opaque(4)] };
    }
    return { players, turn: 0, acceptedActions: 0, hidden, result: null, events: [] };
  }
  validate_action(state: SimulationState, player: string, action: Intent): void {
    if (!state.players.includes(player)) throw new MatchError('FORBIDDEN', 403);
    if (state.result) throw new MatchError('MATCH_FINISHED', 409);
    if ((action.type !== 'advance' && action.type !== 'concede') || Object.keys(action).length !== 1) throw new MatchError('INVALID_ACTION');
    if (action.type === 'advance' && state.players[state.turn] !== player) throw new MatchError('NOT_YOUR_TURN', 409);
  }
  apply_action(state: SimulationState, player: string, action: Intent, _seed: string): SimulationState {
    this.validate_action(state, player, action);
    const next = structuredClone(state);
    next.acceptedActions += 1;
    next.events = [{ type: action.type === 'concede' ? 'simulation.conceded' : 'simulation.advanced', player_id: player, accepted_actions: next.acceptedActions }];
    if (action.type === 'concede') next.result = { winner_id: next.players.find(id => id !== player)!, reason: 'concede' };
    else if (next.acceptedActions >= 6) next.result = { winner_id: null, reason: 'simulation_complete' };
    else next.turn = 1 - next.turn;
    return next;
  }
  get_player_view(state: SimulationState, player: string | null): object {
    if (player !== null && !state.players.includes(player)) throw new MatchError('FORBIDDEN', 403);
    const counts = state.players.map(id => ({ player_id: id, hand_count: state.hidden[id]!.hand.length, deck_count: state.hidden[id]!.deck.length }));
    return {
      simulation: true, turn_player_id: state.result ? null : state.players[state.turn],
      accepted_actions: state.acceptedActions, players: counts,
      ...(player !== null ? { own_hand: [...state.hidden[player]!.hand] } : {}),
      result: state.result,
    };
  }
  get_public_events(state: SimulationState): RuleEvent[] { return structuredClone(state.events); }
  get_result(state: SimulationState): MatchResult | null { return state.result ? { ...state.result } : null; }
  serialize(state: SimulationState): string { return JSON.stringify(state); }
  deserialize(serialized: string): SimulationState { return JSON.parse(serialized) as SimulationState; }
}
