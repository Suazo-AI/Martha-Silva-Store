# PR #5 bounded review

Status: RETURNED. Source assessment and bounded offline verification complete; not primary acceptance.

**Disposition: DEFER PR #5 from this merge rollup. Retain its historical contract as reference.**
The increment is absent from Tony, but its exact patch does not apply to the current frontend.
If primary keeps seasonal offers in scope, port the guard and independent tests narrowly after Astra pre-review.
Do not replace the newer Tony frontend or copy historical generated output.

Host SUAZO-PC. Runtime Codex / gpt-6.1-sol / high, as reported by this harness.
Token usage, effective provider billing and cost remain unknown.
Managed workspace: `C:/Users/Jason/.t3/worktrees/github/t3-30c57989-ba3b2d9a184ec61d`.
Verified clean starting HEAD: `51bbea4891cef23129be07cb4bab17e1247db5c5` (matches packet).
PR head: `cecdbeb05d03ccf01e8ccf74ad83eef4064c0846`.
Frozen PR base: `3b0049163ece2d9431cee01f1bea624a66d9d8d4`.
Both commit objects exist locally. Public PR live state has not been queried.

## Frozen review checks

1. VERIFIED: all eight changed paths assessed. Three generated copies match PR inputs byte for byte.
2. VERIFIED WITH LIMIT: safe integer USD cents and strict approval/status guards pass independent probes. Synthetic cart uses the same 17500 cents. Stock shape validation is incomplete.
3. VERIFIED WITH LIMIT: calendar rejection, inclusive endpoints, leap-century cases and Managua UTC rollover pass. Historical PR assertions do not cover all these boundaries.
4. VERIFIED: Tony 29/29 DOM tests; PR 16/16 DOM tests; 27/27 independent predicate/timezone assertions; additional four-season and synthetic cart assertions pass. No browser or production proof.
5. VERIFIED: minimal disposition, exact bindings, regressions, implementation outline and owned closure actions below. Integration and judge acceptance belong to primary.

No product edits, staging, commit, push, PR mutation, merge, deployment, dependency install or live discount activation authorized here.
Primary owns serial integration, business decisions and independent Astra/xhigh adjudication.

## Direct source and product contract

Use these references at the frozen revisions above, never an unpinned branch URL.

- [PR guard and renderer](https://github.com/Suazo-AI/Martha-Silva-Store/blob/cecdbeb05d03ccf01e8ccf74ad83eef4064c0846/src/app.js#L30): functions at lines 31, 35 and 53; mount hook at 228; selector hook at 253.
- [PR contract](https://github.com/Suazo-AI/Martha-Silva-Store/blob/cecdbeb05d03ccf01e8ccf74ad83eef4064c0846/docs/SEASONAL-OFFERS.md): historical proposal; not commercial authorization. Its two-product language is obsolete on Tony.
- [PR assertions](https://github.com/Suazo-AI/Martha-Silva-Store/blob/cecdbeb05d03ccf01e8ccf74ad83eef4064c0846/tests/frontend-runtime.cjs#L28): seasonal tests at 28, 40, 59, 81 and 93.
- Current [app](../../../src/app.js): integration API at 279; card at 346; mount at 667/673. Both integration modes and their isolated carts must survive any port.
- Current [demo engine](../../../src/demo-api.js): lines 128-129 derive `unit_price_minor`, line total and subtotal from product `price_minor`. Previous seasonal price must remain display metadata.
- Current [README](../../../README.md) distinguishes public historical store, SAVIA v2 and prior backend. PR #5 changes the public demo, not SAVIA v2 or backend pricing.
- Current [SAVIA v2 plan](../../../savia/docs/PLAN.md) retains pending multi-branch and operational acceptance. Seasonal UI does not close those items.

PR diff: 8 paths, 318 insertions, 8 deletions. Paths are `build-inputs/static/index.html`, `build-inputs/static/styles.css`, `dist/app.js`, `dist/index.html`, `dist/styles.css`, `docs/SEASONAL-OFFERS.md`, `src/app.js`, `tests/frontend-runtime.cjs`.
Neither `seasonalOffers` nor its contract document exists in frozen Tony. PR head is not a Tony ancestor (`git merge-base --is-ancestor cecdbeb05d03ccf01e8ccf74ad83eef4064c0846 HEAD`, exit 1).
This is an unported feature, not evidence that another implementation supersedes it.

## Findings and blind-merge regressions

**Integration blocker:** exact editable-source patch fails at HTML line 7, CSS line 84, app line 27 and test line 3.
This proves a straight patch needs reconciliation; it does not simulate a Git three-way merge.
Never resolve that reconciliation by selecting old whole files.
The old app calls `window.marthaDemoApi` directly; Tony uses its selected integration adapter.
Old whole-file replacement would lose integration isolation, newer gallery/history behavior and other source changes.
Old HTML/CSS/generated files would replace the newer Jason frontend and Denis media presentation.
Old tests assume two products and omit Tony's newer integration coverage.

**P2 validation gap:** PR app lines 51/61 accept `stock > 0` without a finite integer or size check.
Independent probes confirm string `"2"`, fraction `0.5` and `Infinity` qualify.
The renderer can therefore label invalid input as stocked sizes unless upstream validation guarantees shape.
No claim is made that the frozen catalog contains those invalid values.
Smallest correction for a future port: use the same validated stocked-variant list for eligibility and size rendering; require nonempty size and positive safe integer stock, or establish and test an upstream equivalent contract.

**P2 evidence gap:** the test named “consistent checkout price” checks card text and percentage only.
It does not add an item, inspect a quote, or assert checkout totals.
The independent review probe now verifies one synthetic cart line/subtotal at 17500 cents, but no quote, real payment or production stock is proved.

**Useful retained behavior:** strict `approved === true`, `commercial_status === 'active'`, USD currency, positive safe integer current price and larger safe integer previous price.
Calendar validation rejects invalid month/day/year-zero and applies Gregorian leap rules.
Managua dates and inclusive start/end comparisons are appropriate for the stated daily campaign model.
Only historical comparison metadata is added; no second promotional checkout price is introduced.
The renderer computes the date when it renders; an already open page has no midnight refresh. A future requirement for continuous expiry needs an explicit refresh test.

## Which PR assertions mean what

1. Line 28 proves four selector elements exist, default emptiness and the Verano transition. Despite its name, it does not click all four seasons. The review probe clicks all four.
2. Line 40 proves one approved fixture renders, another unapproved fixture does not, displayed values and rounded 13 percent. It assumes historical names/prices and is not a checkout oracle.
3. Line 59 rejects seven invalid calendar windows, including non-leap February and year zero. These are meaningful negative controls.
4. Line 81 accepts an interval starting on a real leap day. It does not freeze the clock to leap day or prove timezone rollover.
5. Line 93 rejects one expired item and one equal-price item. It does not cover future start, reversed dates, currency, malformed stock or unsafe cents.

Review probes add deterministic endpoints, future/expired windows, reversed dates, century rules, strict approval, sample status, non-USD and invalid cents. They execute the extracted PR functions, not a rewritten implementation.

## Commands, exact bindings and limits

Five focused check invocations, zero repeated failed checks:

1. Tony snapshot suite: `node <scratch>/tony/tests/frontend-runtime.cjs`, exit 0, 29/29.
2. PR snapshot suite: `node <scratch>/pr5/tests/frontend-runtime.cjs`, exit 0, 16/16.
   Both are orchestrated by `python docs/merge-readiness-20261116/pr5/review_snapshots.py`, exit 0.
   Source files are exact Git blobs. Only test harness `require('./frontend-deps/node_modules/jsdom')` is replaced by the absolute existing canonical dependency path.
   No dependency was installed. Only root HTML/JS files needed by jsdom are extracted. Images and external resources are not loaded.
3. `node docs/merge-readiness-20261116/pr5/probe.cjs`, exit 0: 27/27 predicate/timezone assertions plus four-selector and synthetic cart equality assertions.
4. Read-only patch applicability: Python calls `git diff 3b0049163ece2d9431cee01f1bea624a66d9d8d4 cecdbeb05d03ccf01e8ccf74ad83eef4064c0846 -- src/app.js build-inputs/static/index.html build-inputs/static/styles.css tests/frontend-runtime.cjs`, then passes its bytes to `git apply --check -`. Diff exits 0; apply-check exits 1, four expected conflicts.
5. Source integrity script: compares the three PR generated files to their editable inputs, asserts feature absence on Tony and records current tracked diff. Exit 0; three equalities true; product diff empty.

Evidence: [snapshot receipt and per-file SHA256](snapshot-receipt.json), [sanitized recorded outcomes](../OUTCOMES.json), [source integrity](source-integrity.json). Primary excluded raw logs from publication under the repository filter; original paths and hashes are preserved in [IMPORT.md](../IMPORT.md). This public report changes evidence links only; all worker findings remain unchanged.
The receipt binds every extracted HTML/JS and harness to exact SHA256 bytes and records the jsdom version/path.
Scratch path is disposable and is retained for review; it is not a Git checkout or delivered product.

Not run: full repository checker, builds/regeneration, browser/mobile/visual/accessibility/performance QA, live GitHub head/base/checks, API/SQL, real checkout or payments.
The full checker was not needed to adjudicate this source-only disposition and can generate files; the worker task excludes product mutation/install.
UI rules and testing guidance were read; no design or visual acceptance is claimed.

## Smallest future implementation and closure

Recommended immediate primary action: keep PR #5 separate, record this disposition in the rollup and send the bounded evidence to Astra/xhigh.
Do not block the other independent PR increments on a seasonal UI feature with no approved live offers.

If primary elects to port later:

1. Primary obtains/adopts the required independent Astra pre-review for price/stock trust and freezes the campaign display contract. No live offer data is authorized by this report.
2. Port the eligibility/date guard with validated stocked variants; keep `price_minor` authoritative through the selected current adapter. Do not add a promotional checkout-price field.
3. Add the existing seasonal section through current home mounting/click handling and the current CSS system. Preserve Jason/Denis content and all adapter/gallery/history code. This is a feature port, not a redesign.
4. Adapt fixture injection to Tony's existing `beforeApp` harness hook. Preserve its `integration-adapters.js` loading and all 29 current assertions. Use catalog-derived identities, not a hardcoded two-product count.
5. Add numbered acceptance cases: default empty sample data; all four seasons; active/approved/USD and integer-price negatives; valid/invalid/reversed/endpoint/Managua dates; valid stocked sizes only; display/cart/quote totals agree in both synthetic modes; mode switch and navigation remount preserve current behavior. Test malformed metadata safely.
6. Regenerate `dist/` through `python prepare.py` only after source edits. Run affected checks and full repository checker. Perform desktop/mobile flow review before UI acceptance. Primary then obtains sole-judge Astra/xhigh acceptance and verifies the integrated SHA.

| Blocker or gap | Evidence/cause and correction attempted | Owner and next action | Completion check |
| --- | --- | --- | --- |
| Exact PR patch cannot apply | Four source contexts have changed; `--check` reproduced failure. No product correction is allowed in this review. | Primary: defer or authorize narrow port after independent pre-review. | Chosen disposition recorded; if ported, current source and regression checks pass. |
| Stock input trust incomplete | Three malformed stock values accepted. Adversarial probes executed; no guard edit permitted. | Primary and future executor: validate variants or prove upstream guarantees. | Malformed stock/size cases fail closed and valid stocked sizes render. |
| Original checkout assertion too weak | Direct test read; supplemental synthetic cart assertion passes. Quote/checkout coverage remains missing. | Future executor: add adapter-level cart/quote equality and error-path checks. | Same integer cents across displayed current price, cart and quote in both modes. |
| Missing local jsdom | Worktree dependency absent. Resolved through existing canonical dependency with an isolated harness path adaptation. | Worker resolved within scope. | Tony 29/29 and PR 16/16 exit 0; receipt records dependency. |
| Current business scope and judge acceptance pending | Review cannot choose rollout commitments or activate discounts. No activation attempted. | Primary: adopt defer decision and Astra review, or obtain scoped feature decision. | Primary records disposition and judge result; approved campaign data remains a separate gate. |

Lesson applied: an old green feature test does not qualify integration into a newer frontend. Preserve the current harness and test the actual cart price separately from promotional card text.
