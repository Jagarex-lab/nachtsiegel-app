/** Boundary for the existing Godot rules. The only implementation here is an
 * explicit transport fixture; it has no cards, damage, costs, rewards or ORAFOLD rules. */
export type Intent = { type: 'advance' | 'concede' };
export type MatchResult = { winner_id: string | null; reason: string };
export type RuleEvent = { type: string; player_id?: string; accepted_actions?: number };
export interface RuleAdapter<State> {
  readonly ruleVersion: string;
  readonly catalogVersion: string;
  create_state(players: [string, string], serverSeed: string): State;
  validate_action(state: State, player: string, action: Intent): void;
  apply_action(state: State, player: string, action: Intent, serverSeed: string): State;
  get_player_view(state: State, player: string | null): object;
  get_public_events(state: State): RuleEvent[];
  get_result(state: State): MatchResult | null;
  serialize(state: State): string;
  deserialize(serialized: string): State;
}
