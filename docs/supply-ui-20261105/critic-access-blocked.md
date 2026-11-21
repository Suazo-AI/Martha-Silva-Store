# SAVIA Supply UI — Independent Critic Report (`savia-supply-ui-critic-20261106-01`)

**Verdict:** `REJECT` (Blocked on candidate read access: Antigravity pre-tool workspace hook denied read access to `C:/Users/Jason/.t3/worktrees/github/t3-6ec58bbd`).
**Role:** Advisory critic (`VALIDATE` mode only; not primary acceptance; not `READY`).

## 1. Execution & Environment Metadata

- **Task ID:** `savia-supply-ui-critic-20261106-01`
- **Model (actual):** `gemini-4-argon` (Antigravity harness)
- **Effort (requested / effective):** `thinking_level high` requested; effective effort `unknown` (not exposed inside runtime metadata).
- **Host:** Windows (`SUAZO-PC` per [PLAN.md](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/docs/supply-ui-20261105/PLAN.md#L3)).
- **Critic worktree (base):** `C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf` at base SHA `a4bdac69581ac0423a964dea6bc5c74d4e2bad28`.
- **Review target (candidate):** `C:/Users/Jason/.t3/worktrees/github/t3-6ec58bbd` (uncommitted worker overlay; **READ DENIED** by pre-tool hook).

## 2. Exact Access Gap (Stop Condition Reached)

Every `view_file` call outside `C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf` failed at the harness boundary before execution:

1. `C:/Users/Jason/.t3/worktrees/github/t3-6ec58bbd/docs/supply-ui-20261105/worker/source-manifest.json` -> `denied by pre-tool hook: Access to path "C:\\Users\\Jason\\.t3\\worktrees\\github\\t3-6ec58bbd\\docs\\supply-ui-20261105\\worker\\source-manifest.json" is denied. It is outside the allowed workspace directories: [C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf ...]`
2. `C:/Users/Jason/.t3/worktrees/github/t3-6ec58bbd/docs/supply-ui-20261105/worker/README.md` and `RESULT.json` -> same pre-tool hook denial.
3. `C:/Users/Jason/MARTHA-SILVA/github/docs/supply-ui-20261105/primary-review.md` -> same pre-tool hook denial (and absent in `t3-f55e68bf`).
4. `C:/Users/Jason/AI-OS/rules/orchestration.md`, `PROTOCOL.md`, `OUTPUT.md`, `playbooks/suazo-evidence-first/SKILL.md`, `rules/ui.md` -> same pre-tool hook denial.

Per task instructions, the workspace boundary was not bypassed.
In the critic's own base checkout (`t3-f55e68bf`), [dev/savia-staff-ui/index.html](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/dev/savia-staff-ui/index.html#L97-L100) is still at the pre-candidate placeholder (`Abastecimiento aún no disponible`), and `docs/supply-ui-20261105/worker/` does not exist.
Therefore, raw SHA256 `58f0037eea278a78fb5065e9ad56fdff211b096282fe06db41289df8fd9d464d` of `source-manifest.json`, the 14 changed non-evidence files, and the worker's test/browser logs could not be independently verified from disk.

## 3. Numbered Findings

### Finding 1 — [Confirmed Blocker / Access Gap | Severity: High] Candidate overlay in `t3-6ec58bbd` is outside the critic's allowed workspace list
- **Location:** `C:/Users/Jason/.t3/worktrees/github/t3-6ec58bbd/docs/supply-ui-20261105/worker/source-manifest.json` (and all 14 candidate files).
- **Criterion affected:** Criteria 1–10 ([PLAN.md](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/docs/supply-ui-20261105/PLAN.md#L25-L34)) and manifest verification.
- **Concrete break scenario:** Accepting or certifying candidate claims from a critic session restricted to base worktree `t3-f55e68bf` would validate unread source and unverified test artifacts.
- **Smallest fix:** Primary/orchestrator adds `C:/Users/Jason/.t3/worktrees/github/t3-6ec58bbd` (read-only) to the critic workspace allowlist, or copies the frozen candidate overlay + `docs/supply-ui-20261105/worker/` into a dedicated critic worktree before re-running critic validation.

### Finding 2 — [Evidence Gap | Severity: Medium] Browser logout-late test navigates to `/internal/login`, so it does not prove stationary DOM/epoch rejection on `/internal/`
- **Location:** [dev/savia-staff-ui/app.mjs](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/dev/savia-staff-ui/app.mjs#L353-L361) and [tests/browser-mock-validation.mjs](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/tests/browser-mock-validation.mjs#L242-L250).
- **Criterion affected:** Criteria 6 and 8 ([PLAN.md](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/docs/supply-ui-20261105/PLAN.md#L30-L32)).
- **Concrete break scenario:** In [app.mjs](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/dev/savia-staff-ui/app.mjs#L354-L358), `logout()` increments `++epoch`, runs `clearPrivateView()`, awaits `client.logout()`, and calls `redirect('/internal/login')`. In real Chrome, once `/security/logout` fulfills, the browser navigates away from `/internal/`. Consequently, a browser logout-late test proves that (a) an in-flight operation awaiting CSRF/response does not issue a POST before or during logout teardown, and (b) the `/internal/login` page shows no private supply state. It does **not** independently prove that a late supply read/write callback resolving while `/internal/` remains mounted is ignored by the in-memory `generation === epoch` guard. That stationary DOM guard is proven by the separate unit late-after-clear test (or by a browser test that holds `/security/logout` or triggers an in-place `401` before releasing the late response, as in [tests/browser-mock-validation.mjs](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/tests/browser-mock-validation.mjs#L221-L241)).
- **Smallest fix:** State this boundary explicitly in the acceptance record: browser logout-late proves pre-redirect cancellation and login-page isolation, while stationary post-clear late-reply rejection is covered by the unit test (or hold `/security/logout` open in the browser test until the late supply response resolves and assert on `/internal/` before releasing logout).

### Finding 3 — [Evidence Gap | Severity: Medium] Standalone supply browser driver is not wired into `.github/workflows/savia.yml`, and `.NET 10.0.402` embedded resource compilation is pending Linux CI
- **Location:** [.github/workflows/savia.yml](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/.github/workflows/savia.yml#L35-L43), [.github/workflows/backend.yml](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/.github/workflows/backend.yml#L15-L35), [global.json](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/global.json#L1), [Martha.Store.Api.csproj](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/backend/src/Martha.Store.Api/Martha.Store.Api.csproj#L15-L22).
- **Criterion affected:** Criteria 8 and 10 ([PLAN.md](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/docs/supply-ui-20261105/PLAN.md#L32-L34)).
- **Concrete break scenario:**
  1. [savia.yml](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/.github/workflows/savia.yml#L35) runs `node --test dev/savia-staff-ui/*.test.mjs`, and [tests/check.py](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/tests/check.py#L80-L121) runs portable regressions, but [savia.yml](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/.github/workflows/savia.yml#L43) only invokes `node tests/browser-mock-validation.mjs`. A separate supply browser driver will not execute in GitHub Actions unless added to `savia.yml` or chained from `browser-mock-validation.mjs`.
  2. Local `.NET` build failed pre-compilation with exit `-2147450735` because [global.json](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/global.json#L1) pins SDK `10.0.402` (`rollForward: disable`) while the host has `8.0.422`. Local browser tests serve `dev/savia-staff-ui/*` directly from the filesystem ([tests/browser-mock-validation.mjs](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/tests/browser-mock-validation.mjs#L27-L33)), so they cannot catch a mismatch in [Martha.Store.Api.csproj](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/backend/src/Martha.Store.Api/Martha.Store.Api.csproj#L15-L22) `EmbeddedResource` / `LogicalName` or C# route serving.
- **Smallest fix:** Primary verifies `backend.yml` `build-and-guards` (`.NET 10.0.402`, `Category!=SqlServer`) on the exact integrated `Tony` SHA, and either adds the supply browser driver step to `savia.yml` or records it as a local-only gate until wired. Note that `backend.yml` `sql-server-integration` ([backend.yml](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/.github/workflows/backend.yml#L41)) requires `refs/heads/main` and will not run on `Tony`.

### Finding 4 — [Unverified Hypothesis | Severity: Low/Audit] Candidate supply client/UI must match five strict base backend contracts
- **Location:** [InternalSupplyEndpoints.cs](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/backend/src/Martha.Store.Api/Internal/Supply/InternalSupplyEndpoints.cs#L19-L58), [InternalSupplyModels.cs](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/backend/src/Martha.Store.Api/Internal/Supply/InternalSupplyModels.cs#L73-L116), [InternalSupplyService.cs](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/backend/src/Martha.Store.Api/Internal/Supply/InternalSupplyService.cs#L86-L165), [InternalHosting.cs](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/backend/src/Martha.Store.Api/Internal/InternalHosting.cs#L59-L75), [login.mjs](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/dev/savia-staff-ui/login.mjs#L123-L141).
- **Criterion affected:** Criteria 1–7 ([PLAN.md](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/docs/supply-ui-20261105/PLAN.md#L25-L31)).
- **Base-verified contract checklist for Primary/Judge:**
  1. **Pagination shape (`HasMore`, not `total`):** `InternalSupplyPage<T>` ([InternalSupplyModels.cs](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/backend/src/Martha.Store.Api/Internal/Supply/InternalSupplyModels.cs#L89)) serializes `{ items, skip, take, hasMore }` with `skip >= 0` and `1 <= take <= 100` ([InternalSupplyEndpoints.cs](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/backend/src/Martha.Store.Api/Internal/Supply/InternalSupplyEndpoints.cs#L39)), unlike directory endpoints which return `total`.
  2. **Strict POST body:** `InternalPurchaseReceiptRequest` ([InternalSupplyModels.cs](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/backend/src/Martha.Store.Api/Internal/Supply/InternalSupplyModels.cs#L80-L85)) uses `JsonUnmappedMemberHandling.Disallow` and accepts only `{ receiptId, lines: [{ purchaseOrderLineId, quantity }] }`.
  3. **Dual idempotency & physical receipt identity:** [InternalSupplyService.cs](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/backend/src/Martha.Store.Api/Internal/Supply/InternalSupplyService.cs#L92-L105) binds both the command `Idempotency-Key` (`supply.receipt.create`) and the physical `ReceiptId` (`PurchaseReceipts` `UPDLOCK, HOLDLOCK`). A retry after lost response must reuse both the same `Idempotency-Key` and the same `receiptId`.
  4. **Recovery outcomes:** `GET /internal/api/operations/supply.receipt.create` ([InternalHosting.cs](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/backend/src/Martha.Store.Api/Internal/InternalHosting.cs#L59-L75)) returns `200 { status: "completed", result: { success, value, error } }` when recorded (including durable rejections rolled back to savepoint `BeforeInternalAction` in [InternalCommandRunner.cs](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs#L99-L115)) or `404 { code: "operation_unknown" }`. Only a confirmed `result.success === false` rejection or confirmed `result.success === true` receipt may clear the pending reference; `404`, `503`, or malformed payloads must keep the original `(key, receiptId, body)` pending so retry/reconciliation never invents a second physical receipt.
  5. **Narrow URL allowlist:** [login.mjs](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/dev/savia-staff-ui/login.mjs#L123-L141) must permit only exact supply endpoints and `/internal/api/operations/supply.receipt.create` without opening `/internal/api/directory/parties` to `Manager`/`Inventory`/`Cashier`.

## 4. What Passes vs. Remaining Gates & Owners

- **Verified in base (`t3-f55e68bf`):**
  - Existing backend `Internal/Supply` endpoints, DTOs, command runner savepoint semantics, and `savia.yml` / `backend.yml` / `tests/check.py` structures match the frozen specification in [PLAN.md](file:///C:/Users/Jason/.t3/worktrees/github/t3-f55e68bf/docs/supply-ui-20261105/PLAN.md).
- **Unverified in this critic run (blocked by workspace hook):**
  - Worker `source-manifest.json` (`58f0037eea278a78fb5065e9ad56fdff211b096282fe06db41289df8fd9d464d`), 14 changed candidate files, and worker execution artifacts (`focused 21/21`, `staff 124/124`, `runner 7/7`, `supply Chrome 8/8`, `existing Chrome 50/50`, `mutation exits 0/1/0/1/0`).
- **Remaining gates & owners:**
  1. **Candidate byte & manifest verification (Owner: Primary / Critic):** Primary verifies findings against `t3-6ec58bbd` or re-runs critic with `t3-6ec58bbd` in allowed workspaces.
  2. **Compiled `.NET 10.0.402` resource & guard validation (Owner: Primary):** Run `.github/workflows/backend.yml` `build-and-guards` on the exact integrated `Tony` SHA.
  3. **Real SQL persistence & `main` CI (Owner: Jason / Primary):** Mocked browser HTTP does not prove SQL persistence; `backend.yml` `sql-server-integration` requires `main` or explicit SQL runtime authorization.
