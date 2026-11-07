# Runner safety corrections - RETURNED

Task `savia-runner-safety-sol-70e7549-20261107-01`.
Base HEAD `70e7549062e6919f36c0f36ba21d7a54999a7d9d` remains unchanged.
Host SUAZO-PC; T3 Code/Codex harness reports gpt-6.1-sol/high.
Requested effort high; provider-internal effort, tokens, USD and exact wall duration unknown.
Only this managed worktree was changed. No staging, commit, push or nested agent.
Primary integrates serially; Astra gpt-6-astra/xhigh is the sole independent judge.
This is returned implementation, not acceptance. Production remains NO-GO.

## Verified offline

`python tools/local-validation/test_run_local_validation.py`: exit 0, 39 tests, 2.338 seconds on final source run.
Nine historical controls execute the OLD frozen implementation and assert its undesirable behavior.
Thirty corrected controls include one complete stateful fake campaign.
All tests install a global subprocess.run denial before any test action.
Explicit in-memory Git fixtures replace Git; real Docker/SQL/network cannot run in the suite.
The guard itself is tested against the real adapter.
The OLD controls are defect reproductions, not nine successful historical campaigns.

`python -m py_compile tools/run_local_validation.py tools/local-validation/safety.py tools/local-validation/evidence_gate.py tools/local-validation/test_run_local_validation.py`: no errors, exit 0.
`& 'C:/Program Files/Git/bin/bash.exe' --noprofile --norc -n tools/local-validation/run-stage.sh`: no errors, exit 0.
Only shell parse was exercised; no stage script was run against tools/providers.
Final `git diff --name-only` was empty because all six implementation files are new, untracked files.
Final scoped inventory and raw/LF bindings are in RESULT.json.
No frozen input, manifest, verifier, application, workflow, status or ledger was changed.
A552 was not rerun.

## Findings and corrected behavior

- F1: one 128-bit random run nonce, nonce/scope labels, captured creation identities, ID/name/label readback before restart/removal. Collision and replacement tests issue no destructive foreign operation. Timeout-after-create records unknown and grants no cleanup authority. Volume create was removed: Docker adopts existing named volumes. `/work` now uses the disposable runner writable layer. Only network and two containers are created. No image/tag is created, built or deleted.
- F2: explicit regular/directory tar types, data filter required, exact allowlist/hashes, duplicate rejection, fresh destination, ancestor link/reparse checks. Ordinary 0644 and 0755 entries pass. Traversal, absolute, drive, UNC, backslash, links, device and FIFO controls reject. Sparse headers/types are rejected in implementation; no real sparse archive was generated in this suite.
- F3: mandatory explicit integrated SHA, strict clean Git preflight including untracked files, explicit reviewed public path/hash allowlist, Git blob verification, self/helper byte binding, exported scripts and immutable runner image ID. No working-tree Docker context or mutable tag executes. Exported `tools/local-validation` is the future build context, but this task performs no build. Missing integrated SHA/binding remains blocked rather than inventing a final SHA.
- F4: plan is an offline preparation report and never says READY. Image receipt requires source/files binding, SDK/SQL pins, approved reviewer, dependencies and separately hash-bound qualification evidence. Evidence must identify image/source and successful integrity/closure/trust/license/compatibility/build checks. Dockerfile deliberately exits PREPARATION_INCOMPLETE before historical mutable apt/npm recipe. It cannot build until a separately reviewed dependency closure replaces that stop. Known Node/Playwright/Chrome metadata remains historical publisher evidence, not downloaded binary qualification.
- F5: monotonic absolute preparation900/C1500/D1200/E900 deadlines. Build is inside preparation. C1+C71 share one deadline. E includes copy, receipt validation, stop/start, readiness and restart test. Each transport uses remaining time without outer padding. Filesystem work checks deadlines at boundaries; Python cannot interrupt an arbitrary blocked filesystem syscall. Finalization has independent bounded transport slices: three retention operations <=20s each; three cleanup attempts <=20s each. ACL checks are bounded and no later campaign stage can start after expiry.
- F6: existing empty protected directory required before evidence write or Docker call. Windows reads owner SID, current SID, protected DACL and ACEs; insecure inheritance, foreign ACEs, links/reparse and inspection errors reject. No ACL mutation. Directory identity is rechecked before writes; destination files use exclusive creation. No host secret file is written: passwords/connections are generated after privacy proof and passed via named child environment entries. Tests use explicit ACL records and simulated links; real Windows ACL qualification remains NOT RUN.
- F7: unconditional finalization covers filesystem/transport exceptions, independent log/copy retention and independent cleanup/readbacks. Raw stdout/stderr/timeout output goes only to the protected destination. Each resource is absent/present/unknown; unknown fails. Original failure stage/type remains recorded even if retention/cleanup fails. Ambiguous creation is unknown and requires primary adjudication; automatic retry/adoption is prohibited. Prequalified image is explicitly retained as shared, with zero owned tag/cache removal.
- F8: exact protected `evidence/e` is created before copying `/work/evidence/e/.`. One release JSON and successful exact release TRX are required. A new wrapper receipt binds source SHA, run nonce and both file hashes. The original release fixture is unchanged. Bad copy/TRX/receipt produces zero stop/start calls. Aggregate E2 verifier remains after the restart test.
- F9: exact frozen C1 expectations and canonical unique identities gate C71. The shared verifier is unchanged; the early gate additionally requires nonempty canonical execution IDs. Six wrong/duplicate passed rows block C71. Aggregate C77 remains unchanged.
- F10: fake parses actual argv/kwargs, environment, immutable image IDs, labels, resource creation/removal/listing, files/copy layout, stage transitions, stderr, timeouts and uncertain absence. Real stage-order helper tests reject reorder, duplicate, corrupt history and missing prerequisites. OLD F1-F9 controls and corrected controls are in the same guarded suite. They do not prove Docker CLI/daemon compatibility or real SQL behavior.

D retains `--supply --stock-exception` and executes the existing journey before publication integrity verification.
The frozen journey still contains 22 browser checkpoints, 12 ALWAYS_ZERO SQL invariants and its other quantity/identity/migration oracles.
`verify_evidence.py` remains publication integrity, not journey success by itself.
No host published port, socket/home/credential mount or host trust mutation is introduced.
Ordinary Docker bridge permits egress. Any future downloads/restore require separate reviewed runtime network scope.

## Preparation blockers and concrete handoff

These are missing qualification/authority, not application defects.
No build, download, install, ACL mutation, certificate change or runtime correction was attempted because this task forbids them.

1. Primary: integrate reviewed six-file candidate serially, freeze resulting full SHA, then produce/review a public file/hash allowlist including all backend/build/browser dependencies. Completion: clean integrated Git source, self/helper hashes and every required public blob match. Do not import the synthetic fixture receipt.
2. Primary/dependency reviewer: resolve apt package closure and checksums/provenance; freeze npm transitive/optional closure and integrity; verify Node/Chrome publisher trust, license decisions and endpoint scope. Known publisher metadata is `../RUNNER-PREREQUISITES.json`: Node v24.22.2 SHA256 `48cc0e21e048790e54c0cf5749c2725005313d652651c40b7a21feb9697aaf75`, Playwright/core1.63.0 with recorded SHA512 integrity, Chrome157.0.8103.38-1 SHA256 `a62b277dc03da2cff50cc04589deb66f6875be339c066d46adb49b49eedb629d`. Package downloads/signatures remain unverified. Completion: reviewed immutable dependency lock replacing Dockerfile's deliberate stop.
3. Jason/primary: separately authorize disposable image build/network/license/trust scope. Then capture immutable image ID and independent qualified dependency/Chrome/Playwright/source-build evidence, hash-bound to source/files and approved reviewer. Completion: real image readback and qualification receipt match; cached SDK/SQL alone cannot unblock.
4. Primary/operator: select an existing empty protected private destination. Read owner/DACL/current identity without changing ACLs. Completion: actual privacy preflight passes before any evidence/secret/Docker operation. This worker did not inspect credentials or grant permissions.
5. Jason/primary: authorize one fresh synthetic C77 -> D -> E2 campaign with explicit network/resource/retention/cleanup scope. Completion: real stages, exact oracles and all owned absence readbacks pass on the reviewed SHA. Docker/SQL/browser/CI/production remain NOT RUN here.
6. Primary: if a future create times out ambiguously, preserve unknown plus nonce/name and inspect under reviewed scope. Never automatically remove/adopt. Completion: independently established ownership/absence; no unknown may become PASS.

Representative future invocation schema (not an authorized command; placeholders deliberately remain unresolved):
`python tools/run_local_validation.py --source-sha <reviewed-integrated-40hex> --scope savia-local-runtime-<first12> --private-dir <existing-protected-empty-dir> --binding <reviewed-public-bindings.json> --image-receipt <approved-image-receipt.json>`.
Default is offline report; `--execute` needs separate runtime authority.
Receipt schema is demonstrated only by synthetic fixtures in the test source.

## Lesson and limits

First input check failed because the checkout converted LF to CRLF. Raw hashes differ; LF hashes match all four frozen imports. No frozen bytes were rewritten.
One optional skill read used a stale path, then read its actual catalog path. No access denial occurred.
Agent-awareness reported this exact managed task; the later Windows process query failed, so liveness was unknown. Explicit sole-worker ownership and managed isolation were retained.
No corrected-suite failure occurred; there were no failed-path correction retries. Later checks followed new safety changes.
Lesson applied: deletion authority comes from creation receipt plus identity readback; plausible names and mocked success are insufficient.

Next action: primary inspects source/tests/bindings, then requests the sole Astra/xhigh judge review. Runtime preparation remains blocked.
