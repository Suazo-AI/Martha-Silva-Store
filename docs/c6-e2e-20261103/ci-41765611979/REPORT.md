# C6 combined CI evidence review

C6 evidence criteria: **17/17 PASS** for run [41765611979](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41765611979), attempt 1, job `126363153242`. This is an evidence review, not the separate judge verdict or C8 acceptance.

Head: `e4b7910835bf2c9901aa06989e296997875a3636`. Runner checkout readback: `f1a0bb1d0cd0258838f920ec8f811315820c7587`. The supplied compare records `files: []` between them. Both artifact metadata records bind to this run and head.

| Criterion | Observed field or result |
|---|---|
| 1. Candidate and approved bytes | run-binding run/attempt/head/job/artifact IDs; log-provenance checkout; 8/8 source SHA-256 values equal Git e4 bytes; both exact-byte verifier steps succeeded |
| 2. Chrome and isolation | browser.runtime: Chrome/156.0.8078.79, Node v24.22.2, Playwright1.63.0; isolated-profile SPKI TLS; raw_trace_or_har_recorded=false; external_requests/runtime_errors0 in11/11 |
| 3. Owned groups | teardown.browser_ownership_confirmed=true; hash-bound code validates Chrome private profile, Node ancestry, PGID and /proc start identity |
| 4. Process absence | teardown.browser_processes_absent=true, browser_exit=0; hash-bound final readback covers registered detached Chrome and Node groups |
| 5. Complete path | 11/11 named browser checkpoints, in order; all21 run steps PASS; outcome=PASS, error=null |
| 6. Cashier login | browser.cashier_login network: CSRF GET200, login POST200, me GET200; DOM shell/cashier/sale_enabled; SQL active_sessions=1 and cashier_active_sessions=1 |
| 7. Initial inventory | browser.inventory stock_rows=3, stock_total=30; SQL sale counters0 and on_hand_total30 |
| 8. First sale | browser.sale_confirmed quantity2, total_minor2500, receipt DOM, one real POST200; SQL sales/lines/sale movements/sale operations1, stock28 |
| 9. Receipt reload | Same first sale_id; receipt GET200; sale_posts1; business counts unchanged; refreshed DOM/SQL stock28 |
| 10. Lost committed response | Second POST200 has response_lost=true, distinct key and sale_id, quantity1, total_minor1250; DOM pending/pending_key_preserved |
| 11. SQL before recovery | response_loss_committed SQL sales/lines/sale movements/sale operations2, movements5, operations9, stock27; oracle_failures=[]; source sends acknowledgement only after SQL passes |
| 12. Original-key recovery | recover_after_reload key equals original lost key; operations GET200 carries that key; same lost sale_id; sale_posts2; zero new sale POST |
| 13. Repeated recovery | repeated_reload same lost sale_id, sale receipt GET200, sale_posts2; all7 business counters unchanged across6 read-only actions |
| 14. Final stock | stock_after_recovery DOM inventory/stock_current, rows3, total27; SQL on_hand_total27 |
| 15. Per-action invariants | 20/20 SQL checkpoints migrations_applied2 and oracle_failures=[]; all160 observations across8 invariant counters are0 |
| 16. Logout | Network logout POST204, login GET200, me GET401; DOM logged_out; active_sessions/cashier_active_sessions0; sale_posts2 |
| 17. Withdrawal | teardown api_exit0, browser_exit0, ownership/absence true, database_dropped=true, private_dir_removed=true, api_log_fail_or_crit0; real container absence log line below |

The two submitted sale keys were `f403bb85-8e19-411b-aa23-8832142111e4` and `f11ad76b-163d-400e-b885-a9aaa7a3f4f1`. Recovery used the second key. The lost, recovered and repeatedly reloaded receipt had sale_id `caf75dd9-f618-4e4d-bb63-43eadce2c9b6`. Exactly two sale POSTs appear across all browser events. Sales, sale lines, sale movements and sale operations progress0→1→2; stock30→28→27. Recovery and reload add no business writes.

The real sanitized log excerpt is `2026-11-04T03:13:56.7059623Z PASS: disposable SQL container absence verified.` It follows the pinned workflow scoped container-list check. The private full-log SHA-256 is recorded as `8daecf05e610c6195d2ff0c6ad210a895a1c6506dba44d6bdbba66622c237846`; this worker did not read or publish that raw log.

C5 smoke remains verified in the same bundle: 19/19 steps PASS,18 SQL checkpoints, migrations2, all8 invariants0, final sale counters1 and stock28; API exit0, database dropped and private directory removed. The Markdown oracle tables match the JSON exactly: C6 21rows, C5 19rows. C6 elapsed29308ms; C5 elapsed21935ms.

Eight tracked source hashes match candidate Git bytes exactly. Seven corresponding Windows files have CRLF bytes; normalization to LF matches Git. browser_path.mjs matches without normalization. The API DLL runtime hash is recorded, not independently rebuilt. Exact hashes and criterion fields are in [checks.json](checks.json).

The original evidence-approved marker is intentionally excluded by the two-file publication allowlist. Both verifier steps succeeded; their immutable source verifies marker hashes and copies those exact checked bytes. This review does not invent a marker copy or rehash an unavailable ZIP archive. Extracted-file hashes bind the exact supplied bytes reviewed here.

Limits: Linux synthetic CI proves this C6 path. It does not prove Windows/SUAZO-PC runtime, production TLS/proxy, mobile, visual acceptance, full accessibility, payments, concurrency/load or backup/restore. C8 and the judge are separate. No tests or application runtime were rerun; no checkout, index, source, commit, push or external service was changed.
