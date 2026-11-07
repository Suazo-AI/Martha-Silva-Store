# N8 successful-write oracle correction

Status: primary accepts the source/offline correction after Astra/xhigh recheck. N8 SQL remains pending.
Base: `6708709b4bda8a2638acb995d9ae1b91fc60d257`. Host: SUAZO-PC.

The primary confirms P2 in [the original REVISE report](../astra-implementation-judge.md).
The successful same-session sale and Directory creation used whole-table exclusions.
Those exclusions could hide changes to existing rows. No product-code defect was demonstrated.

The prepared SQL reader now excludes only the four identified sale inserts or two Directory inserts.
It compares every remaining row and field across all 20 explicitly inventoried tables.
For the sold balance only, it reverses the expected OnHand decrement for comparison and masks UpdatedAt.
Reserved remains in the comparison. Explicit SQL assertions require unchanged Reserved and Available minus one.
Complete rejection fingerprints, exact original key/body, and complete replay fingerprints remain intact.
The original immutable CANDIDATE.json is preserved; [this receipt](RESULT.json) binds all 12 current source/test inputs.

## Fresh verification

SDK 10.0.402; cached dependencies; no database connection.

```powershell
& 'C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/dotnet.exe' test backend/tests/Martha.Store.Api.Tests/Martha.Store.Api.Tests.csproj -c Release --no-restore --filter 'FullyQualifiedName~InternalAcceptanceWriteProjectionTests|FullyQualifiedName~InternalAcceptanceFingerprintTests' --logger 'trx;LogFileName=n8-projection.trx' --results-directory private-exports/session-csrf-n8-primary-20261107
```

33/33 PASS, zero failed or skipped, exit 0. The receipt preserves elapsed time, actual counters and private log/TRX hashes.
24 synthetic projection controls include the exact former hole: unrelated existing-row changes pass the old table exclusions,
but fail the projection now used by the ADO.NET reader. Nine existing schema guards also pass.
Deletion, additional inserts, incorrect stock and changed reservations are detected. These are offline oracle controls.

The earlier full `python tests/check.py` passed on `6708709`: exit 0 in 405.609 seconds.
Its log hash is recorded in the receipt and [client PRIMARY](../client/PRIMARY.json).
It is not attributed to the later N8 correction. Website/product inputs are unchanged by this correction.
The full website check was not repeated for test-only C# and documentation changes.

## Acceptance boundaries and continuation

The primary accepts the client's 13/13 and historical controls within their simulated-HTTP scope.
The original judge report is imported byte-for-byte; RAW and LF SHA256 both equal
`f395d69510599cb123b8d94009503f4755a079a0145a41740119b442faaafcf3`.
No revised independent verdict or SQL execution is claimed. Production stays NO-GO.

P2 owner: primary. Next: fresh Astra/xhigh review on committed correction bytes.
SQL owner: primary/Jason. The real N8 has only been prepared and compiled.
Complete local runner and integrated cash prerequisites, then prepare one exact authorized runtime campaign.
Completion requires real source-bound readbacks, including unchanged unrelated rows, rather than these synthetic controls.

Lesson applied and checked: exclude identified inserts, never entire tables, when proving a successful write's permitted effects.

Documentation checks: `python tests/test_progress.py`, `python tools/export_progress.py --verify`,
`python tests/test_delivery_status.py`, and `python tools/delivery_status.py --check` all exited 0.
Their commands, elapsed times and private log hashes are in RESULT.json. These checks do not execute SQL.

## Primary acceptance after independent recheck, 2026-11-07

Primary verified the [Astra recheck](astra-recheck.md) and its RAW/LF hash,
`9b6953185c74cd7542ad7d9bd7e1df65d0827f9963e6fecccc43ae62962bb550`.
The report covers frozen `79d18c407f0de7650a83016093de15efcad10b39`.
All 12 current LF bindings match canonical files and that commit. P2 is resolved for
the same-account sale and Directory oracle. Primary accepts this bounded correction.
The earlier receipt and REVISE remain historical. No tests were rerun for this report import.
The older cross-user positive oracle remains outside this acceptance.
N8 SQL, cash integration, runtime qualification and production remain separate gates.
See [primary acceptance](PRIMARY-ACCEPTANCE.json) for exact disposition and continuation.

Documentation acceptance checks: `python tests/test_progress.py` **23/23**, `python tools/export_progress.py --verify` **15 preserved hashes**, `python tests/test_delivery_status.py` **24/24**, and `python tools/delivery_status.py --check` **40 valid items**. All exited **0**. Commands, durations and private-log hashes are recorded in `PRIMARY-ACCEPTANCE.json`; no runtime tests were repeated for this report import.
