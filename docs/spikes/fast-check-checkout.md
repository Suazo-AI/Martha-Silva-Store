# Spike: fast-check for checkout and inventory invariants

Date: 2026-11-18. Status: experimental, draft PR only.

## Problem

The riskiest workflow is cart → quote → reserve → settle or expire → deliver → refund. A stale reservation, duplicate payment, or repeated refund can mutate stock incorrectly. Existing example-based tests cover selected cases, but not generated combinations of transitions.

The current JavaScript checkout is explicitly a LOCAL DEMO built from src/demo-api.js and shipped as dist/demo-api.js. The separate C# / SQL Server implementation is synthetic and not connected to this checkout. This proof of concept does not verify real transactions, real cards, multiple browser tabs, payment webhooks, or SQL Server concurrency.

## Technology and boundaries

fast-check version 4.10.2 (MIT), with pure-rand 8.4.2 (MIT), pinned with integrity hashes in the test-only lockfile. The suite uses commands, asyncModelRun, asyncProperty and reproducible seeds. The framework can shrink failing sequences to counterexamples.

Only the existing tests/frontend-deps dependency tree and the portable QA runner change. There is no new production library, shipping bundle, deployment configuration, SQL image, credential, or web service.

## Independently checked invariants

- Available quantity equals physical stock minus pending reserved quantity.
- Available quantity never becomes negative.
- A rejected cart quantity leaves the cart and stock unchanged.
- An accepted order reservation preserves its quote and clears the cart.
- Approved payment decrements stock once, declined/cancelled payments release reservations.
- Expiry releases a reservation without changing physical stock.
- Replaying an idempotency key returns the same order and terminal state.
- A refunded return increases stock only when restock was requested; retrying refund never restocks twice.
- Eight concurrent promises for the same payment outcome in ONE JavaScript adapter instance produce one payment event and at most one stock deduction.

The model deliberately tracks only cart quantity, physical stock and order state. It does not copy the implementation's calculation logic. Full returns and a single synthetic variant are in scope; partial returns and cross-variant stock interactions are not.

## Reproduce

First install locked test dependencies through the existing runner:

    python3 tests/check.py --install

After installation:

    node --test tests/checkout-properties.cjs

To increase runs:

    FC_RUNS=500 node --test tests/checkout-properties.cjs

To replay a failure, use the seed, path and command replayPath emitted by fast-check:

    FC_SEED=20261118 FC_PATH=YOUR_PATH FC_REPLAY_PATH=YOUR_REPLAYPATH node --test tests/checkout-properties.cjs

On PowerShell, set the environment variables using $env:NAME before running Node. Defaults: seed 20261118, 100 model scenarios with up to 60 generated commands, and 100 duplicate-payment scenarios. Not all generated commands are executable in every state.

The existing CI executes the portable QA runner on PRs in Ubuntu and Windows. SQL Server integration jobs remain explicitly main-only, in accordance with repository rules.

## Evaluation gates

1. Review the diff and ensure no files under src/, dist/, originals/ or deployed Worker settings changed.
2. Locked dependency installation succeeds with npm ci on both CI operating systems.
3. Portable suite and existing runner regression tests pass, with no tracked-file drift.
4. Verify draft PR head SHA and both CI statuses, and report any skipped SQL tests.
5. Explicitly withhold production-safety claims pending HTTP + SQL testing.

**Recommendation boundary:** Adopt as an inexpensive testing-only complement if CI is green, not as a substitute for the R07 SQL race tests or a real payment-provider sandbox. A later spike should exercise the genuine .NET API with multi-instance HTTP requests and a disposable SQL database, once approved.
