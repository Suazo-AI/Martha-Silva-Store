**RETURNED — correction required before acceptance.** Freeze the contract below for primary approval. This is source preparation, not primary acceptance or production READY.

Host: `SUAZO-PC`. Harness: T3 Code/Codex. Requested and effective identity: `gpt-6-astra`, `reasoningEffort=xhigh` (harness context and awareness agree). Managed worktree: `C:/Users/Jason/.t3/worktrees/github/t3-914bcce1-427ce5c579a42bad`; branch: `t3/review-return-retry-safety`. HEAD: `ba8ff2ba10935e99fc268ebbe5eae130f72c1cca`. Initial working tree clean. No nested delegation.

All required inputs were accessible. Read repository AGENTS, AGENT-START, DATABASE and applicable global orchestration, PROTOCOL, OUTPUT, task-completion, UI and evidence-first instructions. No prior-review files, conversation exports or other worker checkouts were consulted. Exploratory `rg` misses exited 1: mislocated `Guard.cs`/`db/README.md` and Windows wildcard arguments. Direct discovery resolved these to `Application/Core.cs`, `savia/README.md` and `tools/db/saviadb.py`; no access blocker remains.

**Verified defects and limits.**

1. [return.mjs:169](C:/Users/Jason/.t3/worktrees/github/t3-914bcce1-427ce5c579a42bad/savia/web/screens/return.mjs:169) keeps the attempt only inside one mount. Lines 235/262/316/326/377 discard it on edits. Lines 393–419 then generate fresh IDs. A lost response after returning one of three units permits another financial return after editing the reason; the remaining-quantity guard cannot identify repeated intent. Only the submit button is disabled; there is no synchronous handler guard.
2. Lines 420–432 await confirmation/approval without checking mount/session ownership. The POST closure reads mutable `outcome`/`attempt`. [api.mjs:103](C:/Users/Jason/.t3/worktrees/github/t3-914bcce1-427ce5c579a42bad/savia/web/api.mjs:103) selects the current bearer at send time. A retired confirmation can therefore submit under a replacement account. The screen has no unmount guard.
3. [V027:605](C:/Users/Jason/.t3/worktrees/github/t3-914bcce1-427ce5c579a42bad/savia/db/migrations/V027__usd_cash.sql:605) compares only sale, outcome and return-line IDs/quantities. Its credit counterpart, lines 725–736, additionally checks credit linkage, but omits customer and pool. Changed reason, reference, till, branch/location or exchange contents can report success without matching the original. Example: change `ExchangeSaleId`; replay returns the old reversal, while UI lines 444–450 offer the new, uncreated receipt.
4. Both SQL replay branches precede current approval-permission checks. API authentication reloads active roles/branch access, but does not load `CanApproveReturns`; a revoked return-specific permission can escape replay checking. Preserve authentication; move the applicable current permission check before replay. This is source evidence, not a live exploit.
5. [returns.test.mjs](C:/Users/Jason/.t3/worktrees/github/t3-914bcce1-427ce5c579a42bad/savia/web/tests/returns.test.mjs) covers quantity selection only. [170_return_outcomes.sql:32](C:/Users/Jason/.t3/worktrees/github/t3-914bcce1-427ce5c579a42bad/savia/db/tests/sales/170_return_outcomes.sql:32) repeats one cash request; it does not test changed-field replays or concurrency. Test 136 checks changed quantity. These are coverage gaps, separate from defects.

**Available reconciliation.**

Existing `GET /api/v1/sales/{saleId}` returns branch-authorized `reversals[]`. The effective definition is [V028:282](C:/Users/Jason/.t3/worktrees/github/t3-914bcce1-427ce5c579a42bad/savia/db/migrations/V028__usd_change.sql:282), not V027. It exposes reversal ID, status, outcome, reason, till, approver, credit ID and return lines/pools. It omits settlement references and exchange linkage. It can establish a matching committed reversal; it cannot verify every original exchange field.

Neither endpoint supplies an authoritative terminal “never committed” state. GET 404, missing reversal, timeout, cancellation, malformed success or later authorization failure must not release an uncertain intent. [ReturnsService:28](C:/Users/Jason/.t3/worktrees/github/t3-914bcce1-427ce5c579a42bad/savia/src/Savia.Application/Returns.cs:28) writes before a separate detail read; even a failed POST response may follow commit.

**Minimal ordered implementation/acceptance contract.**

1. **Harden both SQL procedures first.** Add `V029__return_retry_safety.sql`; leave V001–V028 immutable. Persist a versioned canonical request digest on the reversal, atomically with its effects. Cover sale/branch/location/node/till, endpoint/outcome, reason/reference, credit/customer IDs, return IDs/quantities/pools, exchange ID, every new-line number/item/quantity/price/discount/seller, every tender number/kind/amount/credit/received/change/reference, and difference kind/reference. Reject forbidden FX fields. Define deterministic ordering and null/default normalization; never reconstruct identity using current prices or policy. Authorization is current; approver credentials are not financial identity.
2. **Serialize by reversal ID.** Validate current authorization before accepting replay. Matching replay returns before open-till/window/stock eligibility checks and changes zero rows, including after till closure. Mismatch throws `51538`/`sale.reversal_id_reused`, with complete rollback. Preserve drawer locking conventions. Legacy rows lack complete original requests: do not fabricate digests or adopt the first retry as the original. Recommended legacy policy is lookup-only when exact equivalence cannot be established. Primary must explicitly settle this compatibility boundary before implementation; universal historical exact-replay success is not currently provable.
3. **Persist before sending.** Capture endpoint, sale ID, complete immutable body/IDs and owner scope: origin/staff/node/branch/location plus original till. Use verified durable storage; storage failure blocks POST. Prevent competing submissions/mounts/tabs from overwriting the reservation. Do not persist tokens/passwords. Model draft, sending, unresolved and confirmed explicitly. No edit, reload, navigation, account change or retry may allocate replacement IDs while unresolved.
4. **Recover before dependencies.** Mount recovery before sale lookup, current-till or policy requirements; adjust the existing [app.mjs:170](C:/Users/Jason/.t3/worktrees/github/t3-914bcce1-427ce5c579a42bad/savia/web/app.mjs:170) prefetch accordingly. Freeze financial fields. Offer lookup and explicit replay of the saved body with fresh authorization. GET absence keeps recovery locked. Confirm matching approved ID, original sale/till/outcome and available line/credit fields; malformed/mismatched responses remain unresolved. Never infer rejection from a retry’s 4xx. A permanently unresolved request needs primary-owned authoritative reconciliation, not a discard button.
5. **Fence ownership and approval.** Check mount generation, current actor/scope and session before/after every await and immediately before POST. Retired callbacks cannot submit, render or clear records. Another account sees only a generic blocked state, never the attempt details. Reacquire temporary supervisor authorization; revoke it on success, failure, cancellation and retirement without changing cashier authentication. Preserve original audit attribution on replay. Use [sale.mjs:40](C:/Users/Jason/.t3/worktrees/github/t3-914bcce1-427ce5c579a42bad/savia/web/screens/sale.mjs:40) and its durable helpers as comparison, not proof or a verbatim template.

**Small independent negative controls.**

- Hold a POST, lose its response, then edit/remount/reload/double-submit. Return GET 404 before releasing the original commit. Assert zero replacement IDs and identical replay body. Include storage denial/corruption and competing mounts.
- Switch account/navigation during confirmation, supervisor login, POST and lookup. Assert no retired POST/render/clear, no foreign details, and temporary-token cleanup. Wrong-ID/malformed 200 must not clear recovery.
- Later SQL: mutate each digest field independently using otherwise valid values; include pool-only and equal-total seller/tender changes. Require the specific conflict and exact before/after row equality, not merely totals. Snapshot reversals, lines/commissions, settlements, sales/tenders, stock balances/movements, credit balances/movements/redemptions, cash, accounting and outbox/deliveries.
- Later SQL: identical/reordered semantic replay, closed-till replay, same-ID concurrent requests and revoked approval; preserve cash/transfer/credit plus equal/cheaper/dearer exchanges. Exercise conservation and unchanged USD drawers. Temporarily omit pool from matching and let GET absence unlock: each corresponding control must fail.

**Evidence and handoff.**

`git rev-parse HEAD`, `git status --short` and three awareness runs exited 0. Awareness command: `python C:/Users/Jason/AI-OS/bin/agent-awareness.py --workspace "C:/Users/Jason/.t3/worktrees/github/t3-914bcce1-427ce5c579a42bad"`.

Two offline behavioral invocations:
- `node --test savia/web/tests/returns.test.mjs`: exit 0; 2/2.
- `node --input-type=module -`: exit 0; unmodified return module, fake DOM from sale-lifecycle lines 7–119, injected HTTP. Lost-response/edit/remount produced 3 POSTs, 3 reversal IDs, 0 durable records. Retired confirmation produced 1 POST using replacement-account bearer. HTTP simulation does not establish SQL behavior.

Working-byte SHA256:
```text
return.mjs 33d03c06aa1087b806962fbf8115fbdd1b6d3186c84bb6f16707c3c763e40981
V027__usd_cash.sql 83f4fd9665b69d7187b768b90ce60a8a895cccee0feed7f816e4c70c97b85aa7
V028__usd_change.sql fd82e158f129261c4d877e557ffa4cdf3074123bb8671f9b7316225f07420666
170_return_outcomes.sql fab0c36e7065f0d952ea8453dc9714e3eca2c51904b1b6a1944d478fb4dc9253
```

SQL/Docker/API/browser/network and GitHub checks: NOT RUN, explicitly excluded. No product correction attempted: review-only authority. Primary owns legacy-policy resolution, implementation integration and separately authorized SQL runtime. Use existing fresh-database fixtures, exact-error assertions and transactional migration-envelope conventions; checksum verification normalizes LF. Runtime lock/rollback/permission proof and later actual UI recordings remain pending.

PR https://github.com/Suazo-AI/Martha-Silva-Store/pull/7, head ba8ff2ba10935e99fc268ebbe5eae130f72c1cca, checks and reviews NOT CHECKED (network prohibited).

