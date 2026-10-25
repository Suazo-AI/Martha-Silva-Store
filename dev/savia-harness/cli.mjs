#!/usr/bin/env node
import { open, readFile, rename, unlink, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { Harness, initialState, loopbackOrigin } from './client.mjs';

const help = `SAVIA synthetic V2 development harness (Node 18+, no dependencies)
Usage: node dev/savia-harness/cli.mjs <command> [argument]
Commands:
  capabilities | catalog | movements   Read actual API JSON (XXX fixtures only)
  reserve [quantity]                   Persist a new one-variant attempt, then POST
  status                              GET mutable reservation view
  cancel                              Persist cancellation attempt, then POST
  lookup [attemptId]                   Resolve original authority after a timeout
  retry [attemptId]                    POST exact saved key/authority/body
  attempts                            Show local transport state, not SQL proof
  mode savia|api-cga                   CGA is closed; pending attempts lock mode
Environment:
  SAVIA_API_ORIGIN=http://127.0.0.1:5080
  SAVIA_HARNESS_STATE=<optional separate synthetic attempt JSON file>
  SAVIA_TIMEOUT_MS=5000
No SQL startup, seed, migration, software install, CORS, storefront build or deploy.
`;

async function main() {
  const [command = 'help', argument, ...extra] = process.argv.slice(2);
  if (command === 'help' || command === '--help') { console.log(help); return; }
  if (extra.length || !['capabilities', 'catalog', 'movements', 'reserve', 'status', 'cancel', 'lookup', 'retry', 'attempts', 'mode'].includes(command)) {
    throw new Error('Invalid command. Run with help.');
  }
  const origin = loopbackOrigin(process.env.SAVIA_API_ORIGIN ?? 'http://127.0.0.1:5080');
  const path = process.env.SAVIA_HARNESS_STATE ?? fileURLToPath(new URL('.state.json', import.meta.url));
  const timeoutMs = Number(process.env.SAVIA_TIMEOUT_MS ?? 5000);
  if (!Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 120000) throw new Error('Timeout must be 1..120000 ms');
  let lock;
  try { lock = await open(path + '.lock', 'wx'); }
  catch (error) { if (error.code === 'EEXIST') throw new Error('State is locked by another run; inspect any interrupted run before removing its .lock'); throw error; }
  try {
    let state;
    try { state = JSON.parse(await readFile(path, 'utf8')); }
    catch (error) { if (error.code !== 'ENOENT') throw error; state = initialState(origin); }
    if (state.baseUrl !== origin) throw new Error('Origin differs from saved attempts; use their original SAVIA_API_ORIGIN');
    const save = async value => {
      const temporary = path + '.tmp';
      await writeFile(temporary, JSON.stringify(value, null, 2) + '\n', { mode: 0o600 });
      await rename(temporary, path);
    };
    const harness = new Harness({ state, save, timeoutMs });
    let result;
    switch (command) {
      case 'reserve': result = await harness.reserve(argument === undefined ? 1 : Number(argument)); break;
      case 'lookup': result = await harness.lookup(argument); break;
      case 'retry': result = await harness.retry(argument); break;
      case 'mode': result = await harness.mode(argument); break;
      case 'attempts': result = harness.state; break;
      default: if (argument !== undefined) throw new Error('Unexpected argument'); result = await harness[command]();
    }
    console.log(JSON.stringify(result, null, 2));
    if (result?.status === 'unknown' || result?.status === 'prepared') process.exitCode = 2;
    else if (result?.status === 'rejected') process.exitCode = 3;
  } finally {
    await lock.close();
    await unlink(path + '.lock');
  }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
