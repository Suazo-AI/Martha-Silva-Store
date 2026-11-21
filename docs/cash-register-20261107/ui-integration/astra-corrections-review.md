# ACCEPT WITH LIMITS — cash UI corrections

Task: `savia-cash-corrections-39161ef-astra-20261108-01`. Mode REVIEW.
F1–F3 are resolved for this frozen overlay. No open material finding. This is bounded source/test acceptance, not CASH-REGISTER runtime or production acceptance. Primary retains integration and acceptance ownership.

## Identity and immutable inputs

Exposed identity: SUAZO-PC, T3 Code/Codex, `gpt-6-astra`, `xhigh`; harness and agent-awareness agree. No substitution or nested delegates. Hidden settings, token usage and cost are unexposed.

Tool-managed worktree: `C:/Users/Jason/.t3/worktrees/github/t3-02842609`.
HEAD: `39161ef8c5afcac1f7c9502cc5f38439608a8d70`; initially clean.

Verified packet before import: `C:/Users/Jason/MARTHA-SILVA/test-runs/cash-ui-primary-20261108/review-corrections-inputs/CANDIDATE.json`, RAW SHA256 `fbf10c4d8c9ef7c9333be8668e3ea4e90f1fc334e3aa3514762916c53fff2903`.
All 23 bound paths matched RAW/LF hashes and lengths before and after byte-exact import. Seven specified supplemental documents were copied for reading. These are review inputs, not deliverables. Canonical checkout and archives remained read-only.

Prior review RAW/LF verified: `246f874c5dca828c4d9aab74fa0048022effb91bef3ea13a483145ea5d4513ef`.
Read all requested global/project rules; no access denial.

Paths below are repository-relative; U=`dev/savia-staff-ui`, T=`tests/browser-mock-validation.mjs`.

## Numbered dispositions

1. **F1, previous P1 — RESOLVED; acceptance check 1 passes within synthetic scope.**
   T:49–53,92–108 supplies the cash till, `receivedMinor:30000`, paid receipt and exact cash route. T:140–201 preserves double-submit, malformed receipt, uncertain first reload and original-key recovery assertions. T:107 and 287–312 bind pending RAW bytes, scope/key/path/body/hash and prohibit native/synthetic submit while recovery is held. T:315–349 verifies fresh multiarticle quantities, one POST and stock changes `10→8` / `10→7`. T:204–269 retains actor/version, 401 and logout protections. Seeded historical unpaid recovery remains at T:279–280,351–395.

   `currentActor` is confined to setup at T:67,80,83. N5 now uses the single shared context at T:92 and `tillFor(state)` at T:49; its override returns `true` after handling routes at T:320–325. The unreachable duplicate context is absent.

   Direct comparison found all 36 original case declarations unchanged. The current archived run has the same 50 expanded names and 50 PASS results. Fresh reviewer cash tests also reject receipt identity, tender and arithmetic mutations. This closes fixture incompatibility without restoring fresh unpaid sales.

2. **Reload adaptation — ACCEPTABLE SCOPED COVERAGE; acceptance check 2 passes with a capability limit.**
   T:109–114 explicitly fetches the mocked commerce receipt and invokes the real `readReceipt` parser after reload. Callers at T:142,175,200–201,345–348 assert no additional sale POST; N2 also forbids another operation lookup. This is weaker than the old automatic-redisplay assertion for that specific behavior. It is not equivalent evidence, and does not prove persisted SQL or an application-initiated receipt lookup.

   Nevertheless, the hash-verified canonical `docs/cash-register-20261107/ui-preparation/PLAN.md:33–40` requires original-key recovery through **uncertain** reloads, confirmed monetary display and preservation of legacy pending flows. Its accepted `astra-contract-review.md:66–78` requires uncertainty retention and permits cleanup after resolution. Neither requires automatically redisplaying an already confirmed cash receipt on another reload. U/cash.mjs:138–146 removes the resolved pending envelope; :213–224 renders the confirmed receipt; :232–242 clears/restarts the view. Uncertain first-reload receipt display remains at T:170–174,197–199. Seeded legacy restoration remains separately exercised.

   Disposition: accept the disclosed adaptation for this increment; do not claim confirmed-cash automatic redisplay. Adding that capability would require explicit product scope, not an invented repair requirement. PLAN RAW hash matches the prior review's `5b7d20c47d8afb04719eb77777a35516d46945e15c2de1766134038c34cbe258`; contract-review RAW matches `a86064047bf9ef699aa90b3ea6d20fff9ef7ad22837edda89f80b3107217bd48`.

3. **F2, previous P2 — RESOLVED; acceptance check 3 passes statically.**
   `.github/workflows/staff-ui-candidate.yml:52–78` and `.github/workflows/savia.yml:36–59` invoke the cash driver before legacy with existing Playwright/Chrome/ffmpeg setup. Cash steps have no conditional skip or continue-on-error. Always-upload covers their isolated evidence paths. PyYAML parsing and parent comparison verified these properties, no test selector, and unchanged other jobs, including SQL. No workflow was dispatched; exact-SHA CI remains pending.

4. **F3, previous P2 — RESOLVED; acceptance check 4 passes.**
   U/cash.mjs:232–235 synchronously removes location/till options, context/balance, cashier/till identifiers, refund rows/summary, page, currency and received label. Store clear at :122 preserves storage bytes. Start at :236–242 clears before reads; failed context sets `blocked`, preventing recovery and cash actions. Epoch/identity guards at :162,204–209 reject late results.

   Real callers clear commerce/cash/supply/stock together at U/app.mjs:155–164; authorization failure :175–180, session replacement :301–308 and logout :360–367 use that path. Fresh `cash.test.mjs` passes both new privacy cases (:71–98). Independent reviewer probe additionally exercised actor and version replacement with failed context, checked every cash control disabled, attempted synthetic submits and direct sell, and observed zero dispatch/recovery calls with identical pending bytes. Fresh evidence is component/jsdom proof, not cross-account browser navigation.

5. **Evidence boundaries — acceptance check 5 passes; no waiver.**
   Verified original primary log/result hashes from CORRECTIONS.json: privacy red 0/2 and green 2/2; repository staff 223/223; current cash 2/2, legacy 50/50 and supply 8/8. All recorded RAW source bindings match this overlay: respectively 6,9,6. Primary records exit 0 and refused connections at owned loopback origins; I made no network cleanup probe.

   Worker 50/50 and wrong-tender negative 0/2 remain historical, separate from current primary runs. Earlier ASP.NET hosting 93/93 remains historical; its three hosting/resource/test source files still match the preceding candidate. Cash module bytes subsequently changed, so that old run is not a fresh compiled-module test. No SQL, real Windows Owner recovery, visual acceptance or production claim follows.

## Checks, limits and handoff

Reviewer used exactly **2/2** permitted Node invocations with cached `NODE_PATH=C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules`:

- `node --test dev/savia-staff-ui/cash.test.mjs`: exit 0, **58/58**, zero failed/skipped.
- `node --input-type=module -`: inline independent fail-closed lifecycle probe, exit 0, **2/2** actor/version scenarios.

Read-only Python/Git checks verified packet, evidence, declarations, YAML and final source integrity. Final 23 bindings and seven supplements remain byte-exact. Other tracked paths retain the baseline digest, including 79 pre-existing absent paths. Initial absent-file and text-encoding probe failures were resolved using absence markers and explicit decoding; no inputs were repaired or changed.

NOT RUN: browser rerun, whole repository suite, build/.NET, SQL5, Docker, installs/downloads/network, service/security/account mutations, stage/commit/push/deploy, live CI or production acceptance. SQL5 remains **D: REVIEW FIRST, DO NOT EXECUTE**.

Only new deliverable: this report. Permitted stop: completed bounded adjudication. Primary owns acceptance/publication and exact-SHA applicable CI under existing authority. Completion check: preserve these input hashes and pass the applicable no-SQL gates; SQL authorization remains separate.

Lesson applied: retained case names alone do not preserve coverage. Judge the changed assertion against the frozen requirement and name the behavior it no longer proves.
