/** Integration contract only: the separately developed economy remains authoritative. */
export interface EconomyAuthority {
  ownedCards(userId: string): Promise<ReadonlyMap<string, number>>;
  validateDeck(userId: string, deckId: string, catalogVersion: string): Promise<{ valid: boolean; canonicalDeckId?: string }>;
  transact(command: EconomyCommand): Promise<{ receiptId: string }>;
}

export type EconomyCommand = {
  userId: string;
  idempotencyKey: string;
  kind: 'match_reward' | 'booster' | 'currency' | 'duplicate' | 'craft' | 'trade';
  /** Must be an authorization reference from the economy server, never local-save proof. */
  authorizationRef: string;
};

export class EconomyUnavailableError extends Error {
  readonly code = 'ECONOMY_NOT_INTEGRATED';
  constructor() { super('ECONOMY_NOT_INTEGRATED'); }
}

/** Default fail-closed adapter. It never treats local saves as proof of ownership. */
export class UnavailableEconomy implements EconomyAuthority {
  async ownedCards(_userId: string): Promise<ReadonlyMap<string, number>> { throw new EconomyUnavailableError(); }
  async validateDeck(_userId: string, _deckId: string, _catalogVersion: string): Promise<{ valid: boolean; canonicalDeckId?: string }> { throw new EconomyUnavailableError(); }
  async transact(_command: EconomyCommand): Promise<{ receiptId: string }> { throw new EconomyUnavailableError(); }
}
