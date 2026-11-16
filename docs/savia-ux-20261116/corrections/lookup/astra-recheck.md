**ACCEPT WITH LIMITS.** F3b closes for the reviewed lifecycle boundaries. No material residual finding was established. Previous F1/F2/F4, stale401 and F3-initialization closures remain bounded. Primary owns integration and final acceptance.

Task: `savia-ux-lookup-recheck-72b192d-20261116-01`; VALIDATE.
Host: SUAZO-PC / Windows / T3 Code / Codex. Runtime metadata, `t3_thread_configure` and agent-awareness report `gpt-6-astra`, `reasoningEffort=xhigh`. Provider-side effort telemetry, tokens and cost remain unknown. No delegates or additional model requests.

Base/HEAD: `2c96904f49d2df913850bc13cf53b3b03ceebacf`.
Reviewed immutable **tree**: `72b192de1661688962b21d6ff3e7925a955a7508`.
Previous tree: `4f700e5489f3da5acad5b79be40eb21397f5228d`.
These tree identities are not commits, publication or production acceptance.

**F3b adjudication**

The entire existing product delta is two guards: [sale.mjs:631](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/screens/sale.mjs:631) rechecks `locked()` after lookup/body parsing; [sale.mjs:531](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/screens/sale.mjs:531) guards `choose()` before shared-dialog writes. There is no intervening await before modal construction. `locked()` includes busy state and [sale.mjs:46](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/screens/sale.mjs:46) checks liveness, route context, mount identity, actor identity, token and scope. [app.mjs:150](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/app.mjs:150) binds the context to route generation and hash. [ui.mjs:97](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/ui.mjs:97) confirms the shared-body replacement and focus side effects being prevented.

Fresh adversarial proof holds **response-body parsing**, independently invalidates lifecycle predicates, and preserves an **already-open successor dialog**. Eleven boundaries cover route-only retirement, unmount-only, logout-token-only, account-object-only, token renewal, four in-place scope changes, same-root remount, and navigation away/back. Both delayed lookup and retained old product-card handlers preserve dialog node/open state, focus, screen, token and actor. Queued scans never issue a second lookup after retirement. Two active controls select/add exactly one line. All 24 scenarios require zero POST.

The probe imports actual sale/API/UI/scanner/payment modules. It reuses only the new test's minimal DOM harness; its schedules and assertions are independently authored. It is offline behavior proof, not a browser or exhaustive scheduler model.

**Original ten checks**

The [frozen checks](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/docs/savia-ux-20261116/sale-preimplementation.md) and [previous review](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/docs/savia-ux-20261116/corrections/astra-recheck.md) are preserved.

| Check | Adjudication |
| --- | --- |
| 1. Canonical active seller | Prior bounded closure retained; attribution unchanged; fresh suite passes. |
| 2. Deliberate reassignment/permissions | Prior closure retained; no seller or permission change. |
| 3. Disclosure values/keyboard | Prior closure retained; scanner and keyboard-related source unchanged. |
| 4. Money/approval separation | Prior offline closure retained; request arithmetic and credential boundaries unchanged. |
| 5. Final payload/locks | F4 closure retained; redraw reapplies busy lock at sale.mjs:450. New guards also respect busy. |
| 6. Durable recovery before POST | Prior closure retained; actual persistence/readback tests pass; marker precedes POST at sale.mjs:726. |
| 7. Scope/session/stale callbacks | F3b CLOSED within tested boundaries; previous initialization/stale401 closures retained. |
| 8. Dependency-free receipt lookup | F1 closure retained; recovery still precedes startSale; original cashier/till matching unchanged. |
| 9. Uncertainty/no retransmission | Prior closure retained; recovery module unchanged; no retransmission added. |
| 10. Actionable accessible feedback | Prior limited source/keyboard closure retained; no new visual or full-accessibility acceptance. |

**Executed versus supplied evidence**

Exactly **two** validation processes; no validation retry; third allowance unused:

1. `node --test savia/web/tests/*.test.mjs savia/web/scanner/scanner.test.mjs`: **98 passed, 0 failed, 0 skipped, exit 0**. [Log](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/private-exports/astra-lookup-review/web.log) SHA256 `3c1a7a73c0543e955abc8a2e521de5582cade1a9888bffab9dc879ba3a294c49`.
2. `node private-exports/astra-lookup-review/adversarial-probe.mjs`: **24 passed, 0 failed, exit 0**. [Probe](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/private-exports/astra-lookup-review/adversarial-probe.mjs) SHA256 `baafac4e9fc14444e702abdef34fe4cad8bf98af57d85b60a86ca71f9cec9f23`; [log](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/private-exports/astra-lookup-review/adversarial.log) SHA256 `82cc900a23cbd2fcaafafb8cc8785a868e3c6a94e8af72546bdfb5fd0f0e8498`.

Inspected [CHECKS.json](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/docs/savia-ux-20261116/corrections/lookup/CHECKS.json), browser fixture/driver/helper and bound result: supplied Chrome **8/8**, exit 0, at 1440x900 and 390x844. The driver awaits actual lookup completion after release, checks replacement operator/token/dialog/focus, and asserts active selection adds once. Closure flags record owned browser/server cleanup. No browser rerun.

Primary red **1 pass/6 fail, exit 1**, green **7/7, exit 0**, Biome **65 files, exit 0**, and build **exit 0** remain supplied receipts; primary private logs were not accessed. Initial browser SETUP **exit 1, zero completed scenarios** remains failure evidence. The interrupted offline fixture also supplies no product pass.

Earlier shell30, mounted41/keyboard20, entry3/browser71 and architecture9 are historical reuse, not reruns after these guards. A read-only summary script hit `AttributeError: 'list' object has no attribute 'items'`; correcting list iteration recovered the metadata. No validation process was retried.

**Bindings and preservation**

Materialized exactly **115** changed paths from Git blobs: **20 source/test + 95 docs/evidence**. Paths were constrained to this assigned worktree. All115 initially matched exact tree bytes; all115 remain unchanged. All **5,508** frozen tracked/overlay files remain unchanged. Eighteen existing source/test blobs equal the previous tree; sale.mjs alone changed, plus one new test. Historical manifests/check receipts remain unchanged.

[CANDIDATE.json](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/docs/savia-ux-20261116/corrections/lookup/CANDIDATE.json) SHA256: `1dc225257372e0afbee7e62e9c60d07225ec9337adcf207c7b94d268e3913bec`.
All **20 source LF** and **6 artifact LF** bindings match. RAW matches **17/20** and **4/6** respectively. Differences are CRLF normalization in banner.css, verify.py, app.css, browser.json and CHECKS.json; BOMs were retained.

| Bound source | LF SHA256 |
| --- | --- |
| [savia/demo/site/banner.css](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/demo/site/banner.css) | `59661fa4112a1970002ab88f86234654c5c95b8c43bf4a45cfd378681e930968` |
| [savia/demo/site/boot.mjs](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/demo/site/boot.mjs) | `06511f5f4a4df6aea86f5d0aaaad02cb38252ea5a86f7711ecc918b43078d553` |
| [savia/demo/site/verify.py](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/demo/site/verify.py) | `9efb46efd2cca15e02a68e103eab1320374ecf807ae074709cab5e6eb4f1785d` |
| [savia/demo/site/entry.test.mjs](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/demo/site/entry.test.mjs) | `0999043dc4d75826667e3d2c958d61099fa7ecbd67dd50207146636f364d412d` |
| [savia/web/app.css](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/app.css) | `991defaa314c45bb6dfe8f26f5b278a4b7b62b76d63652b91e45832227f0e760` |
| [savia/web/app.mjs](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/app.mjs) | `707bec9b596cd77c1701dfdc3cdd8dbe67ea1330b13ad3553ee8177a0d1bfd23` |
| [savia/web/roles.mjs](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/roles.mjs) | `b7d270531e7c9a5df1b1888d816e280e9526ed0f1f4d8d60fe1f197998dd5651` |
| [savia/web/scan.mjs](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/scan.mjs) | `3e88319593566bcf6a728e59b35e4a9ff09781fab8c243fbe0680afae8020e33` |
| [savia/web/screens/history.mjs](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/screens/history.mjs) | `fd2ccf877492e24475c42e74957988ae9356fd0320083434b9b78897e19ca0f8` |
| [savia/web/screens/sale.mjs](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/screens/sale.mjs) | `4f73ba40afc917ce0b20e24dbb86e41b8c8b33c4e04f1663fa6908e4a5621a15` |
| [savia/web/ui.mjs](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/ui.mjs) | `906fe9b654625298196b6aa66217d0c4ff8358ade1100dd405d777a1f743ba4c` |
| [savia/web/sale-recovery.mjs](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/sale-recovery.mjs) | `0db3c8f84cb5486690ae9e0e9891f1364f07205d6f860a953a6704eadc8c82f5` |
| [savia/web/tests/scan.test.mjs](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/tests/scan.test.mjs) | `8eafce1935cacc567f790553d94a917bcfaa3bc8e37ed4fd3adce2828c2234c2` |
| [savia/web/tests/navigation-ux.test.mjs](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/tests/navigation-ux.test.mjs) | `831550529940d56a9c15a283b65e08d77a4a480b260f17229d11ca20e55b6c02` |
| [savia/web/tests/sale-recovery.test.mjs](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/tests/sale-recovery.test.mjs) | `4bf621e27a52a47d0fa0e30befa1fed4cd87f4373e4d75851c6b59d91c3fa1ab` |
| [savia/web/tests/sale-ux.browser.mjs](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/tests/sale-ux.browser.mjs) | `75a0ddb5d98648ebcc202c3d3ab191b678f1edc28a1a5b7521fdc5c1749a1248` |
| [savia/web/api.mjs](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/api.mjs) | `7b3cda6186f318bc77851d08d7637457a83486a91a6880ff34d9394c4de893c0` |
| [savia/web/screens/till-open.mjs](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/screens/till-open.mjs) | `a12dd759bcc6f63f0628f1db4cafb0fa03db5fedad6ffc9dbe6b882f7b655265` |
| [savia/web/tests/api-contract.test.mjs](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/tests/api-contract.test.mjs) | `98b9c43e72aa047de6a0f3c215a0fd4da3d150f21b60aa0a5de7124cbfb00270` |
| [savia/web/tests/sale-lifecycle.test.mjs](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/savia/web/tests/sale-lifecycle.test.mjs) | `2cd224c4f305ca582a971966fcb4a588e8a0d1b6c9412576910c68bd7f6e0146` |

| Bound artifact | LF SHA256 |
| --- | --- |
| [docs/savia-ux-20261116/corrections/astra-recheck.md](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/docs/savia-ux-20261116/corrections/astra-recheck.md) | `5894f29c12eca9c7a3b1584bfc274284f1b13d308292d40fa4690d4cb1803ec8` |
| [docs/savia-ux-20261116/corrections/shell-fixture.mjs](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/docs/savia-ux-20261116/corrections/shell-fixture.mjs) | `f910dbfad93d696fef201b32d6392d7a234fd98044db225e2c0bd31cc8ae6160` |
| [docs/savia-ux-20261116/corrections/lookup/browser.py](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/docs/savia-ux-20261116/corrections/lookup/browser.py) | `8fa3e8c5257c1fb579e9fa1f50d9736753818bb914fd437ed1ccf5cbc9486c46` |
| [docs/savia-ux-20261116/corrections/lookup/browser.json](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/docs/savia-ux-20261116/corrections/lookup/browser.json) | `85599c7b05a47d8a3d1e222604b43856a72f6f499e86925ad255e651a31521ce` |
| [docs/savia-ux-20261116/corrections/lookup/CHECKS.json](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/docs/savia-ux-20261116/corrections/lookup/CHECKS.json) | `5a4396d30688bead9dc950f98e5d7ad9efbd0c60758890851cb215efd47de58b` |
| [docs/savia-ux-20261116/corrections/lookup/README.md](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/docs/savia-ux-20261116/corrections/lookup/README.md) | `fe030ad11c68c892879a298b87d9ec399009ca346c6c5071ef36f43bba3079b8` |

HEAD is unchanged; staged diff is empty. Assigned index SHA256 remains `ccb9429c3e35a05ad191c49e02c8458980a16d0a913ac35611186b616a4fe269`. Only this report is added beyond the authorized overlay; scratch is ignored. After overlay freezing, no implementation, index, branch, manifest, ledger or canonical-checkout writes. No commit/publication.

**Limits and handoff**

Stop: verified bounded review, within 20 minutes. No remaining in-scope defect requires a correction. Lesson applied: check both post-await continuation and direct retained handlers against successor shared UI.

The inherited Windows root gate still records `WinError 1314`; it was not rerun or repaired because this review excludes that runtime/security scope. Primary owns exact-SHA Linux verification when authorized. [savia-v2.yml:8](C:/Users/Jason/.t3/worktrees/github/t3-8907a171-a476f6e499f07957/.github/workflows/savia-v2.yml:8) and :63 confirm a qualifying Tony push starts SQL. Primary/Jason must resolve runtime authority before publishing; do not weaken CI.

No network/GitHub, SQL, Docker, service, .NET, build, installation, account mutation, browser, deployment or physical-device run occurred here. Real persistence, all schedules, multi-tab behavior and production remain unproven. **Next: primary accepts/rejects this report and integrates only its owned documentation; publishing remains held.**
