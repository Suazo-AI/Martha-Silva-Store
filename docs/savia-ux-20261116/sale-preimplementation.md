# Sale pre-implementation gate

Task `savia-ux-sale-prereview-20261116`; VALIDATE; returned to primary, who owns acceptance.
SUAZO-PC / T3 / Codex / `gpt-6-astra/xhigh`; usage unknown.
Source: `2c96904f49d2df913850bc13cf53b3b03ceebacf`.
Worktree: `C:/Users/Jason/.t3/worktrees/github/t3-f29bc236-6f72b0730b16dec4`.
Only this document changed.

**Verdict: revise before implementation.** (1)–(3) are feasible with the checks below. (4) supports conservative receipt recovery, not guaranteed terminal reconciliation.

## Verified source and failures

Paths below are relative to `savia/`.

- **P1 attribution:** `web/screens/sale.mjs:114,730` chooses the first seller on initial load and invalid-draft restoration. Shared additions also choose the first remaining seller (:104). `web/screens/sale-logic.mjs:67-70` silently transfers orphaned lines.
- **P1 uncertain retry:** `sale.mjs:47,121,495-539` recreates state on remount and allocates the key before supervisor adjustments. Its fingerprint omits reason/stock note. Payment/seller/line edits reset IDs (:56,147,325); park/clear/restore also reset them.
- **P1 concurrency hypothesis:** only Cobrar is disabled; `drawBalance` can re-enable it (:289-301). Editing/scanning during POST could create another attempt. `web/app.mjs:101-138,158-174` changes route/account without cancelling this closure. No browser reproduction.
- **P2 errors:** `web/ui.mjs:33-39` appends diagnostic codes inline. `web/api.mjs:128-132` throws an unclassified parse error after malformed success.
- Existing success behavior at `sale.mjs:543-575` preserves confirmation when receipt-detail retrieval fails. Retain it.

**Actual offline reproduction:** six probes confirmed remount-equivalent key loss; supervisor-adjustment key drift; unchanged key with changed reason; malformed-success SyntaxError; inline diagnostic code; swallowed storage-write failure (`ui.mjs:69-75`). These exercise helpers, not duplicate SQL sales or mounted UI.

## Exact recovery contract

`src/Savia.Api/SalesEndpoints.cs:10-20` exposes POST and receipt GET/search. `src/Savia.Application/Sales.cs:20-45,61-63` derives cashier from the authenticated actor and restricts detail by role/branch.

`db/migrations/V028__usd_change.sql:77-89` fingerprints branch/location/cashier, sellers, reason, stock note, currency/customer/till, lines/tenders/FX. Changed content gives `sale.id_reused` (`src/Savia.Domain/Errors.cs:60`). Seller validation precedes replay (:54-60); a later rejection can coexist with an earlier committed sale.

Receipt detail (:282-309; `src/Savia.Contracts/Sales.cs:14-23`) has cashier/till, recorded money and sellers, but no operation-status tombstone. GET 404 cannot prove rejection after an uncertain POST.

Active sellers come from `db/migrations/V018__seller_commissions.sql:31-39`. Payment snapshots/restore (`web/screens/payments.mjs:286-305`) are mutable inputs, not persisted attempts.

## Frozen acceptance checks

1. Only canonical GUID equality between `/me.staffId` and active `/sellers[].sellerId` defaults selection. No name/role/first-row inference. Empty/loading/failed lists block add and charge.
2. Invalid restored sellers require deliberate reassignment. Preserve valid assignments, duplicate-item/different-seller lines and maximum three sellers. Do not grant SELLER access to Venta.
3. Disclosure toggles preserve values, totals and approvals. Keep primary seller visible. Missing reasons reveal/focus the field. Keyboard Enter/Space works without scanner focus theft (`web/scan.mjs:21-28`).
4. Preserve minor-unit arithmetic and commission inputs. Compare request bodies for discounts including 100%, split cash/card/transfer/credit, USD/change, references and stock exceptions. Test supervisor cancellation/expiry; preserve cashier `Authorization` and separate `X-Savia-Approval` (`web/api.mjs:109-121,210`). Never persist credentials.
5. Freeze final payload after approval/payment recomputation. During sending/unknown, prohibit edits, scans, park/clear and second submission.
6. Persist and read back recovery data before POST; storage denial/corruption blocks sending. Do not use silently failing `device.set`.
7. Bind recovery to origin, staff, node, branch, location and original till (`src/Savia.Contracts/Site.cs:4-5`). Logout/account switch retains quarantine; stale callbacks cannot alter another actor's state.
8. Reload lookup works without opening another till or loading catalog/FX. Match receipt ID/cashier/original till; use recorded totals/change.
9. Test response loss before/after commit, malformed/empty success, 5xx, 404, changed permissions and inactive seller. Uncertainty remains pending; only an unequivocal first-attempt rejection is rejected. Confirmation survives ancillary failure.
10. Plain actionable alert remains announced; diagnostic details use valid keyboard-accessible markup. Match actual desktop/mobile BEFORE/AFTER sequences; none recorded here.

## Minimal recommendation and evidence

Implement (1)–(3), plus a durable scoped sale-ID marker and **Consultar recibo**, without automatic retransmission. Unresolved lookup stays pending with an explicit manager handoff. If retries are included, persist the exact final body/key and preserve actor/approval boundaries; rebuilding from current inputs is unacceptable.

`node --input-type=module -`: six synthetic stdin probes, **6/6**, exit **0**.
`node --test savia/web/tests/*.test.mjs`: **64/64**, zero failures/skips, exit **0**.
HEAD/status and source reads verified the frozen baseline. Search path/PowerShell quoting errors were corrected using bounded Python reads.

No SQL execution, network, browser, build, installation, commit or push. Runtime/visual checks remain pending by scope.
**Next:** primary adopts these checks and the lookup-only recovery limit before dispatching implementation.
