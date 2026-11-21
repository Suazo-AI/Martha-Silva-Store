# Partition verifier extension

Candidate evidence for `savia-local-partition-verifier-857bea1-20261106`.
Base source: `857bea105fe1dfa045114a5569ba5cb4c31b3391`, uncommitted candidate changes included.
This is not primary acceptance and not proof of runtime SQL coverage.

## What changed

`backend/tests/verify_full_suite.py` now has an optional partition mode:

```powershell
python backend/tests/verify_full_suite.py --manifest docs/local-validation-20261106/PARTITIONS.json --partition A <results_dir>
python backend/tests/verify_full_suite.py --manifest docs/local-validation-20261106/PARTITIONS.json --partition C <results_dir>
python backend/tests/verify_full_suite.py --manifest docs/local-validation-20261106/PARTITIONS.json --partition E <results_dir>
```

The existing full-suite contract remains `--min-tests N <results_dir>`.
Partition mode requires the exact manifest method set and exact per-method TRX multiplicity.
It also requires every outcome to be `Passed`, unique test IDs, and unique nonempty execution IDs.
`C` aggregates `C.*` and `C1`; D and browser evidence stay separate.
The report names only methods and counters from the public manifest.
It never exports test arguments, stdout, messages, stack traces, or secrets.

Validation against the frozen `PARTITIONS.json`:

| group | methods | cases |
|---|---:|---:|
| A | 195 | 552 |
| C | 77 | 77 |
| E | 2 | 2 |

Malformed JSON, missing fields, unknown method partitions, duplicate methods, and partition count mismatches fail closed.
Unknown `--partition` values are rejected by argparse.
A duplicate `testId` fails as `duplicate test case`.
In partition mode, a repeated nonempty `executionId` fails as `duplicate execution identity`.

## Commands and results

Focused stdlib tests:

```powershell
python -m unittest discover -s backend/tests -p test_verify_full_suite.py
```

Result: `Ran 16 tests`, `OK`, exit 0.
Existing tests still cover the `--min-tests` path and sanitization.

Actual CLI negative control, using a synthetic TRX generated from the frozen A inventory:

```powershell
python backend/tests/verify_full_suite.py --manifest docs/local-validation-20261106/PARTITIONS.json --partition A C:\Users\Jason\AppData\Local\Temp\opencode\partition-verifier-check\intact
```

Result: `Partition A: passed; 552/552`, exit 0.

```powershell
python backend/tests/verify_full_suite.py --manifest docs/local-validation-20261106/PARTITIONS.json --partition A C:\Users\Jason\AppData\Local\Temp\opencode\partition-verifier-check\corrupt
```

Result: `Partition A: failed; 551/551`, one `multiplicityMismatch`, exit 1.
The corrupt fixture removed one occurrence only. The intact fixture exited zero.

Other checks:

```powershell
git diff --check
```

Result: exit 0.

## LF bindings

Algorithm: SHA256 over bytes after `CRLF` to `LF`.

| path | SHA256 LF |
|---|---|
| `backend/tests/verify_full_suite.py` | `86a5f08e4411bd25df18f82853145492f48b19069d1d8f4699d1de3c0b1c1ec6` |
| `backend/tests/test_verify_full_suite.py` | `648c43eda0b62664fadc947b064198d6f2be1155b370052461fbebdc282838fb` |
| `docs/local-validation-20261106/PARTITIONS.json` | `d2feccd4c8af3b8358865b1bc23e15e287a28f852e4e70b3357a7d4f39caaad8` |

## NOT RUN

- Real A/C/E TRX execution. No SQL, Docker, browser, registry, TLS, account, or service action ran.
- The six historical SQL failures remain unsolved and unverified.
- No `.NET` build or `dotnet test` invocation.
- No primary or independent review acceptance.
- Token and cost telemetry are unknown.

Limit: synthetic fixtures prove verifier logic only.
They do not prove that a real run produced the required method multiplicities.
