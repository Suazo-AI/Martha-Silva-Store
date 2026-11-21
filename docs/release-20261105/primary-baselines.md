# Primary inspection: browser and administrative baselines

2026-11-05. SUAZO-PC. T3 Code / Codex / gpt-6.1-sol / xhigh.
Source HEAD: `6f304a7571a554bb8968e081a14985829aee3dfb`.
This inspection accepts observations for prioritization. It does not accept production.

## Browser baseline

Inspected the actual driver, summarizer, structured result and raw evidence.
Recomputed all 2,171 source hashes: zero mismatches in the worker worktree.
Compared those paths with canonical files: product sources match RAW bytes.
The only existing-path RAW difference was `PLAN.md`; decoded text is identical after CRLF/LF normalization.
Recomputed the two private evidence hashes and driver/summarizer hashes: all match.
Independently matched all 692 served-file hashes against the frozen manifest.

Six normal route/viewport samples returned HTTP 200, without recorded overflow or page errors.
Completed transfers were 29,882,466–53,423,091 bytes in the stated observation windows.
Three degraded samples returned the document but timed out waiting for load at 40 seconds.
Readable no-JS content/native navigation and warm-offline failures remain separate observations.
One JS navigation URL verifier rejected `?lang=es` although the destination was reached.
That is a verifier defect, not evidence of broken product navigation.

Disposition: **ACCEPT WITH LIMITS for this local baseline**.
PNG demand is a demonstrated optimization target; its exact contribution under throttling is not isolated.
No device, production, universal-connectivity, representative INP or visual-owner acceptance is claimed.
Next: preserve the current design and original images; generate responsive derivatives and compare the same samples.

## Administrative simulation

Inspected `simulate_admin.py`, the independent projection in `oracle.py`, README and execution receipt.
Recomputed all 14 receipt hashes and eight before/after source hashes: zero mismatches.
No full simulation was repeated; both worker invocations remain attributed to that worker.

Primary command: `python -X utf8 <worker>/oracle.py --input <worker>/run-02/<file>.json`.
Executed the seven saved inputs independently:

| Input | Exit | Observed invariant |
| --- | --- | --- |
| baseline-normal | 0 | none |
| restored-normal | 0 | none |
| duplicate_cash_collection | 1 | MONEY_CASH |
| unauthorized_close | 1 | CLOSE_JOURNAL_AUTHORITY |
| altered_stock | 1 | STOCK_JOURNAL |
| omitted_event | 1 | AUDIT_JOURNAL |
| silent_balance | 1 | CLOSE_JOURNAL_AUTHORITY |

The fixture arithmetic is `10000+70000+10000+5000-35000-2000=58000`; count `57500` retains shortage `-500`.
The first failed fixture expectation and corrected second run are preserved.
The result contains twelve fixed families, 325 transitions and 256 generated actions.
The projection checks journal declarations independently of Model calculations, but trusts the fixture/journal.
Output corruption controls demonstrate verifier sensitivity; they are not SAVIA product mutations.
Full second-shift lifecycle, real process crash, persistence and actual bank/SQL behavior remain unmodeled.

Disposition: **ACCEPT WITH LIMITS for bounded offline technical evidence; critic process remains incomplete**.
The primary inspected the actual [Astra/high report](admin-judge.md) against the frozen ten checks and existing direct verification.
The judge found no material defect in this bounded packet; it did not rerun the full driver.
The 350 counted assertions comprise 325 oracle bundles and 25 literal/control checks, not 350 independent scenarios.
Generated coverage is receipt/collection; generated crash/replay schedules and a full second shift remain absent.
Invocation 1 retains its failure record and hashes; its complete original driver bytes cannot be reconstructed from this packet.
The fixture/journal remain shared trusted inputs; this is arithmetic independence, not independent business-requirements validation.
The [judge import receipt](admin-judge-import.json) binds an exact RAW copy; the original twenty-file import is unchanged.
Required Opus critic review is still missing. This technical acceptance does not close that review process.
The [critic failure receipt](admin-review-blocker.md) preserves the exact terminal error and next action.
No final critic report exists; partial source reads are not a verdict.
No policy, ledger acceptance criterion, product capability or operational gate changes from this model.

## Import and next action

[Import manifest](BASELINE-IMPORT.json) records all twenty exact files, original paths and RAW/LF policies.
No private browser raw logs, credentials, profiles, snapshots, conversations or backups were copied.
Original worker artifacts remain unchanged. Public imports retain the returned/pending-review labels.
No commit, push, CI or deployment is claimed by this inspection.

Lesson applied: use direct output controls and source hashes before accepting a worker summary.
Subsequent integration: [primary acceptance and corrections](responsive-integration/README.md).
The responsive candidate and Astra review are now imported into the canonical checkout.
Remaining work: missing Opus verdict; publication and exact-SHA CI.
