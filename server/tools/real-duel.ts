import { pathToFileURL } from 'node:url';
import { createApp } from '../src/transport/app.js';
import { registerClient, type SimulatedClient } from './load.js';

export type LegalCommand = { name: string; args: unknown[] };
export function chooseLegalCommand(view: Record<string, any>): LegalCommand {
  const actions = view.state.legal_actions as LegalCommand[];
  if (!Array.isArray(actions) || !actions.length) throw new Error(`NO_LEGAL_COMMAND:${String(view.state.stage)}`);
  // A deterministic QA policy, not another combat implementation. Every choice
  // comes from the production kernel's validated legal intentions.
  const order = ['mulligan', 'origin', 'secondOrigin', 'secondCard', 'openingDone', 'chooseStrikeTarget', 'skipShift', 'finishDraw', 'play', 'endTurn', 'burn'];
  return actions.toSorted((a, b) => {
    const first = order.indexOf(a.name), second = order.indexOf(b.name);
    return (first < 0 ? 100 : first) - (second < 0 ? 100 : second);
  })[0]!;
}

export async function driveRealDuel(
  app: Awaited<ReturnType<typeof createApp>>, clients: [SimulatedClient, SimulatedClient], matchId: string,
  options: { maxActions?: number; onAccepted?: (command: LegalCommand, view: Record<string, any>) => void } = {},
) {
  const counts: Record<string, number> = {};
  for (let i = 0; i < (options.maxActions ?? 1500); i++) {
    // Read the same participant-filtered snapshots broadcast over the sockets.
    // The harness avoids polling messages that would consume a human's rate
    // allowance; every mutation still goes through authenticated WebSocket.
    const views = clients.map(client => app.matches.view(client.userId, matchId)) as Record<string, any>[];
    if (views[0]!.status === 'finished') return { view: views[0]!, counts, actions: i };
    const index = views.findIndex(view => view.state.legal_actions?.length);
    if (index < 0) throw new Error(`NO_ACTOR:${String(views[0]!.state.stage)}`);
    const client = clients[index]!;
    const view = views[index]!;
    const command = chooseLegalCommand(view);
    const accepted = await client.send('match.action', { match_id: matchId, sequence: view.next_action_sequence, action: { type: 'command', ...command } });
    if (accepted.type === 'error') throw new Error(`COMMAND_REJECTED:${String(accepted.code)}:${command.name}`);
    counts[command.name] = (counts[command.name] ?? 0) + 1;
    options.onAccepted?.(command, accepted);
  }
  throw new Error('DUEL_ACTION_BOUND_EXCEEDED');
}

export async function runRealDuel() {
  const app = await createApp({ port: 0 });
  const { url, wsUrl } = await app.start();
  const clients: SimulatedClient[] = [];
  try {
    clients.push(await registerClient(url, wsUrl, 0), await registerClient(url, wsUrl, 1));
    const [alice, bob] = clients as [SimulatedClient, SimulatedClient];
    const catalog = await alice.send('catalog.get');
    const starters = catalog.catalog.starters;
    await alice.send('deck.select', { selection: { starter_id: starters[0].id } });
    await bob.send('deck.select', { selection: { starter_id: starters[1].id } });
    const invite = await alice.send('private.create');
    const found = await bob.send('private.join', { invite_code: invite.invite_code });
    const id = found.match_id;
    await alice.send('match.ready', { match_id: id });
    await bob.send('match.ready', { match_id: id });
    const result = await driveRealDuel(app, [alice, bob], id);
    const replay = await alice.request(`/matches/${id}/replay`, undefined, 'GET');
    return { rules: replay.rule_version, simulation: replay.simulation, card_count: catalog.catalog.card_count, actions: replay.actions.length, command_counts: result.counts, result: replay.result, final_state_hash: replay.final_state_hash };
  } finally {
    await Promise.all(clients.map(client => client.disconnect().catch(() => {})));
    await app.close();
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) console.log(JSON.stringify(await runRealDuel(), null, 2));
