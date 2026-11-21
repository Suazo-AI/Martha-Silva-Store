# Independent Adversarial Review — Physical Stock Exception & Different-Person Review (`e48b5ac`)

## 1. Verdict & Executive Summary

**Verdict:** `REVISE`

Commit [`e48b5accd6ba45473e64a949e993db497ed93b1e`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/docs/stock-exception-20261106/PRIMARY-REVIEW.md) implements the physical-stock exception and different-person review increment cleanly across EF migrations, command runner idempotency, ordinary-sale fingerprint preservation, and golden-path opt-in guards. However, static adversarial inspection established **two material defects** (one server-side authorization omission on `ResponsibleActorId` against D027/Check 3, and one Staff UI pending-intent deadlock on `4xx` review rejections against Check 4) plus **one low-severity UI contract validation gap**. None require a new business policy decision; all have bounded, deterministic fixes.

---

## 2. Execution Identity & Hash Verification Totals

- **Task ID:** `savia-stock-critic-e48b5ac-20261106` (`mode: VALIDATE`)
- **Host / Harness:** Windows (`SUAZO-PC`), T3 Code / Antigravity (`antigravity-acp`)
- **Model & Effective Reasoning:** `gemini-4-argon` requested with `thinking_level: high`; runtime-exposed model/reasoning telemetry: `unknown` (unexposed by harness)
- **Usage / Cost Telemetry:** `unknown` (unexposed by harness)
- **Worktree & Git State:** `C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65`, `HEAD = e48b5accd6ba45473e64a949e993db497ed93b1e`, `comparison_base = 9597f19d0e1621c2b3984f8bf8878a0f7d58d906`, `git status --short` empty (clean).
- **Hash & Contract Verification ([`CANDIDATE.json`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/docs/stock-exception-20261106/CANDIDATE.json), [`IMPORT.json`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/docs/stock-exception-20261106/IMPORT.json), [`worker/source-binding.json`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/docs/stock-exception-20261106/worker/source-binding.json)):**
  - `CANDIDATE.json` contracts: **33/33** match `lfSha256` on disk, **33/33** match `HEAD` Git blob SHA-256 (`git cat-file blob HEAD:<path>`), **33/33** match `baseGitBlob` against `9597f19d0e1621c2b3984f8bf8878a0f7d58d906` (`25` existing + `8` new `null`-base files), and **21/33** match `rawSha256` on disk (the remaining 12 are clean LF checkouts matching `lfSha256` per `hash_policy`).
  - `worker/source-binding.json` vs `CANDIDATE.json`: **28/31** worker contracts match `CANDIDATE.json` `rawSha256` identically; the **3** differing worker files (`InternalCommerceModels.cs`, `InternalStockExceptionTests.cs`, `test_golden_path_stock_exception.py`) plus **2** workflow files (`.github/workflows/golden-path.yml`, `.github/workflows/staff-ui-candidate.yml`) account for all 33 candidate contracts.
  - `IMPORT.json`: **26/26** public evidence files exist in the worktree (`18` raw byte matches + `8` CRLF-to-LF text checkouts matching on LF normalization); **15/41** private log entries correctly reside outside the repository.

---

## 3. Reproducible Material Findings

### Finding M1 (Medium / Check 3): `ReviewStockException` does not verify that `ResponsibleActorId` holds an authorized role (`Owner` or `Manager`) or differs from the registering cashier

- **Location:** [`InternalStockExceptions.cs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/backend/src/Martha.Store.Api/Internal/StockExceptions/InternalStockExceptions.cs#L78-L85) and [`InternalBranchAccess.cs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/backend/src/Martha.Store.Api/Internal/InternalBranchAccess.cs#L27-L35)
- **Evidence:**
  - [`docs/DECISIONS.md`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/docs/DECISIONS.md#L1060-L1086) (D027), [`worker/README.md`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/docs/stock-exception-20261106/worker/README.md#L19), and [`worker/RESULT.json`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/docs/stock-exception-20261106/worker/RESULT.json#L254) state that the review stores an *"authorized responsible actor"* (*"responsible authorized actor"*).
  - In [`InternalStockExceptions.cs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/backend/src/Martha.Store.Api/Internal/StockExceptions/InternalStockExceptions.cs#L83-L84), the server only checks:
    ```csharp
    if (!await new InternalBranchAccess(db).CanAccessLocation(request.ResponsibleActorId, sale.LocationId, token))
        return InternalResult<InternalStockExceptionReview>.Fail("responsible_actor_forbidden");
    ```
  - However, [`InternalBranchAccess.CanAccessLocation`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/backend/src/Martha.Store.Api/Internal/InternalBranchAccess.cs#L27-L35) returns `true` for **any** enabled staff member assigned to that branch across all four roles: `"Owner"`, `"Manager"`, `"Cashier"`, or `"Inventory"`.
- **Impact:** A reviewing Manager/Owner can set `ResponsibleActorId` to an `Inventory` clerk or `Cashier`—including `sale.ActorId` (the very cashier who registered the physical stock exception)—and the server accepts and commits the review (`200 OK`).
- **Required Fix:** In [`InternalStockExceptions.ReviewStockException`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/backend/src/Martha.Store.Api/Internal/StockExceptions/InternalStockExceptions.cs#L83-L85), verify inside the serializable transaction that `request.ResponsibleActorId` belongs to an enabled staff row with an authorized role (`Role is "Owner" or "Manager"`, or explicitly enforce the intended role/different-person constraint) in addition to `CanAccessLocation(request.ResponsibleActorId, sale.LocationId, token)`, and add an offline unit test in [`InternalStockExceptionTests.cs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/backend/tests/Martha.Store.Api.Tests/InternalStockExceptionTests.cs).

---

### Finding M2 (Medium / Check 4): `mountStockReview` persists `pending` before validating `responsibleActorId`/`nextReviewAt` and never clears `pending` on deterministic `4xx` rejections, wedging the Review UI

- **Location:** [`dev/savia-staff-ui/app.mjs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/dev/savia-staff-ui/app.mjs#L629-L669)
- **Evidence:**
  1. Compare `mountCommerce` ([`app.mjs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/dev/savia-staff-ui/app.mjs#L555-L603)) and `mountSupply` ([`supply.mjs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/dev/savia-staff-ui/supply.mjs#L98-L115)): both validate request fields (`validateSaleRequest` / `validateDelivery`) **before** writing `pending` to `sessionStorage`, and both expose a `GET /internal/api/operations/...` recovery path that clears `pending` when the server rejected the operation (`sale_rejected` / `receipt_rejected`).
  2. In `mountStockReview` ([`app.mjs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/dev/savia-staff-ui/app.mjs#L663-L666)), `submit()` only checks truthiness (`if (!sale || !body.saleLineId || !body.evidence || !body.outcome || !body.responsibleActorId || !rawNext || Number.isNaN(next.getTime()))`). It does **not** check `UUID_RE.test(body.responsibleActorId)` or `next.getTime() > Date.now()`.
  3. `submit()` immediately writes `pending = op` to `sessionStorage` (`savia.stock.review.pending.<actorId>`) and calls `send(op)`.
  4. If the user entered a non-UUID `responsibleActorId`, a past `nextReviewAt`, or triggers a deterministic `4xx` rejection (`400 invalid_request`, `403 different_reviewer_required`, `403 responsible_actor_forbidden`, `404 sale_not_found`, `409 idempotency_conflict`), `send(op)` catches the `StaffApiError` ([`app.mjs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/dev/savia-staff-ui/app.mjs#L652)) while leaving `pending` in memory and in `sessionStorage`.
  5. `lock()` ([`app.mjs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/dev/savia-staff-ui/app.mjs#L638-L640)) disables **all** form inputs (`el.disabled = busy || blocked || !!pending || !sale || !allowed()`) and load inputs (`el.disabled = busy || blocked || !!pending || !allowed()`) whenever `!!pending` is true, leaving only `#stock-review-retry` (*"Reintentar misma revisión"*) enabled.
- **Impact:** Any typo in `responsibleActorId`, past date in `nextReviewAt`, or `400`/`403`/`404`/`409` server rejection permanently locks the Manager/Owner's stock review form across page reloads for that session; clicking `#stock-review-retry` replays the rejected payload indefinitely.
- **Required Fix:**
  1. Validate `UUID_RE.test(body.responsibleActorId)` and `next.getTime() > Date.now()` in `mountStockReview` (`app.mjs:663`) **before** setting `pending` or writing `sessionStorage`.
  2. When `send(op)` receives a deterministic non-transient `StaffApiError` where the server rejected the review without committing (`status === 400 || status === 403 || status === 404 || status === 409`, or via `GET /internal/api/operations/commerce.stock.review`), clear `pending` and remove `pendingKey()` from `sessionStorage` so the reviewer can correct the input and submit a fresh operation. Add a test in [`stock-exception.test.mjs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/dev/savia-staff-ui/stock-exception.test.mjs).

---

### Finding L1 (Low / Check 4): `client.mjs` does not validate `stockReviews` or `reviewStockException` response shapes

- **Location:** [`dev/savia-staff-ui/client.mjs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/dev/savia-staff-ui/client.mjs#L58-L60) and [`dev/savia-staff-ui/app.mjs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/dev/savia-staff-ui/app.mjs#L649-L658)
- **Evidence:** Unlike `recordSale`/`readReceipt` (`validateReceipt`) and `recordSupplyReceipt`/`readDelivery` (`validateDelivery`), `stockReviews` and `reviewStockException` in `client.mjs` return raw `requestJson(...)` without contract validation. In `app.mjs:654`, `reviews.map(...)` assumes `reviews` is an array and `review.id` is present on `reviewStockException`.
- **Recommended Fix:** Add a small response validator in `client.mjs` verifying that `reviewStockException` returns an object matching the posted `saleId`/`saleLineId`/`causeState === "open"` and `stockReviews` returns an array of valid review objects.

---

## 4. Dispositions on Frozen Acceptance Checks (1–8)

1. **Check 1 (No invented stock/receipt/cost/movement; `available == 0` with reserved units risk):** **PASS WITH DOCUMENTED RISK.**
   - Ordinary lines still enforce `balance.OnHand - balance.Reserved < line.Quantity` and decrement `OnHand` via `StockMovements` (`Reason = "sale"`). Exceptional lines require `ExceptionReason` and `Size`, create `StockExceptionAllocation` (`CauseState = "open"`), and write zero `StockMovements`, `StockBalances`, or `PurchaseReceipts`.
   - **Explicit Policy Risk Inspected:** [`InternalStockExceptions.cs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/backend/src/Martha.Store.Api/Internal/StockExceptions/InternalStockExceptions.cs#L65) checks `balance is null || balance.OnHand - balance.Reserved == 0`. If `OnHand > 0` and `OnHand == Reserved` (e.g., `OnHand = 2, Reserved = 2`), `Available == 0` passes while physical `OnHand` is non-zero, selling a physical unit without decrementing `OnHand` or `Reserved`. Today no internal endpoint creates non-zero `Reserved` balances, so this is dormant in the current slice, but must be gated before reservations are enabled.
2. **Check 2 (Exception creation, return/cancel, locks, idempotency, ordinary fingerprint):** **PASS.**
   - `[property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]` on `InternalSaleLineRequest.ExceptionReason` and `Size` ([`InternalCommerceModels.cs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceModels.cs#L7-L9)) preserves the exact legacy JSON and SHA-256 fingerprint for ordinary sales while binding non-null exception fields.
   - Lock ordering in `RecordSale` sorts `(ItemId, LocationId)` across both ordinary and exceptional lines before locking `StockBalances`. Return/cancel reverses `ReturnedQuantity` and `SaleAdjustments` while skipping stock replenishment when `ExceptionReason is not null` ([`InternalCommerceService.cs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceService.cs#L103-L106)).
3. **Check 3 (Server-side different-person review, Owner self-review denial, authorization, responsible actor, append-only):** **REVISE (see Finding M1).**
   - Endpoint (`InternalCommerceEndpoints.cs:54`) and service (`InternalStockExceptions.cs:76-81`) restrict reviewers to `Owner`/`Manager` and deny `reviewerId == sale.ActorId` even for `Owner`. Reviews are append-only (`CauseState = "open"`, `nextReviewAt > now`). Fails only on `ResponsibleActorId` role/cashier validation (Finding M1).
4. **Check 4 (Durable pending key/body, duplicate submit, receipt binding, storage failure, session invalidation):** **REVISE (see Finding M2 & L1).**
   - Exceptional sale receipt binding (`client.mjs:103-107`), storage quota blocker (`app.mjs:626`), and `sessionVersion` invalidation (`app.mjs:635,650`) are sound. Fails on `mountStockReview` pre-storage validation and `4xx` pending lockup (Finding M2).
5. **Check 5 (Generated migration, current release script and model; no hand-edits):** **PASS.**
   - `20261106071201_PhysicalStockException`, `InternalDbContextModelSnapshot.cs`, and `InitialInternalSavia.idempotent.sql` match `InternalDbContext` and preserve existing business rows (`SaleLines.ExceptionReason`/`Size` nullable).
6. **Check 6 (Golden-path harness 17+5 checkpoints, 4+1 SQL identity oracles, 3 new SQL tests NOT RUN):** **PASS.**
   - `golden_path.py`, `browser_path.mjs`, `GoldenPath.Sql/Program.cs`, and `oracles.md` preserve the 17 existing checkpoints and 4 SQL identity oracles, add 5 stock checkpoints (`browser.stock_exception_*`) and `stock-identity`, and keep `exception_movements == 0`.
7. **Check 7 (Manual default-false `stock_exception` requires `supply_receipt`, no auto-enable, sanitization intact):** **PASS.**
   - `.github/workflows/golden-path.yml` keeps `stock_exception` default `false`, fails pre-runtime if `stock_exception && !supply_receipt`, and `.github/workflows/staff-ui-candidate.yml` passes `--stock-exception` only to offline DOM/guard tests.
8. **Check 8 (Source-bound truthful evidence & whitespace note):** **PASS.**
   - Evidence counts and layer labels in `PRIMARY-REVIEW.md`, `primary/CHECKS.json`, `primary/browser-stock-results.json`, and `worker/RESULT.json` are truthful and internally consistent. The cached `git diff --check` warning is limited to trailing blank lines in historical raw SQL snapshots (`current-release*.sql`), not product source errors.

---

## 5. Explicitly NOT RUN & Next Action

- **NOT RUN (Verified Skipped / Unexecuted):**
  - 3 new SQL-backed xUnit tests in [`InternalStockExceptionSqlTests.cs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/backend/tests/Martha.Store.Api.Tests/InternalStockExceptionSqlTests.cs) (`ExceptionalSale_PersistsZeroStockAllocation_AndDifferentPersonReview_WithoutStockMovement`, `ExceptionalSale_ConcurrentCalls_CommitSingleIdempotentSale_AndKeepZeroStock`, `ExceptionalReturn_ReversesReceivable_WithoutCreatingStockOrMovement`) and all 58 SQL-gated tests in `Martha.Store.Api.Tests`.
  - Real SQL/API/Chrome combined golden-path runtime (`python tests/golden-path/golden_path.py --mode browser --supply --stock-exception`).
  - Full `python tests/check.py --install` completion on Linux (blocked on Windows by `WinError 1314` symlink privilege in `tests/asset-audit.py`).
- **Concrete Next Action for Primary:**
  1. Fix **Finding M1** in [`InternalStockExceptions.cs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/backend/src/Martha.Store.Api/Internal/StockExceptions/InternalStockExceptions.cs) and [`InternalStockExceptionTests.cs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/backend/tests/Martha.Store.Api.Tests/InternalStockExceptionTests.cs).
  2. Fix **Finding M2** (and **L1**) in [`dev/savia-staff-ui/app.mjs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/dev/savia-staff-ui/app.mjs), [`dev/savia-staff-ui/client.mjs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/dev/savia-staff-ui/client.mjs), and [`dev/savia-staff-ui/stock-exception.test.mjs`](file:///C:/Users/Jason/.t3/worktrees/github/t3-2ec9ff65/dev/savia-staff-ui/stock-exception.test.mjs).
  3. Rerun the focused offline .NET, Node DOM, and mocked-Chrome checks, update `CANDIDATE.json` hashes, and proceed to the separately authorized SQL/golden-path verification.
