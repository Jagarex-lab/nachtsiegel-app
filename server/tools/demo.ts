import { runLoad } from './load.js';
// All accounts, sessions and matches live in an ephemeral local database.
const result = await runLoad(2);
console.log(JSON.stringify({ demo: 'two local test accounts; authentication, matchmaking, simulated action, reconnect, completion and history', ...result }, null, 2));
if ((result as { unexpected_errors: string[] }).unexpected_errors.length) process.exitCode = 1;
