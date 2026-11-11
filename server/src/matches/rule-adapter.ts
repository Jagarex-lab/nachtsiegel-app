/** The server transports intentions. Godot owns all card and combat rules. */
export type Intent = { type: 'advance' | 'concede' } | { type: 'command'; name: string; args: unknown[] };
export type DeckSelection = { starter_id: string } | { cards: string[] };
export type MatchResult = { winner_id: string | null; reason: string };
export type RuleEvent = { type: string; player_id?: string; accepted_actions?: number };
export interface RuleAdapter<State> {
  readonly ruleVersion: string;
  readonly catalogVersion: string;
  create_state(players: [string, string], serverSeed: string, loadouts?: [DeckSelection | null, DeckSelection | null]): State;
  validate_action(state: State, player: string, action: Intent): void;
  apply_action(state: State, player: string, action: Intent, serverSeed: string): State;
  get_player_view(state: State, player: string | null): object;
  get_public_events(state: State): RuleEvent[];
  get_result(state: State): MatchResult | null;
  serialize(state: State): string;
  deserialize(serialized: string): State;
  catalog?(): object;
  validate_deck?(selection: DeckSelection): DeckSelection;
}
