# CI quick-path worker return

RETURNED; primary acceptance pending. Base `63a8b1e9bfe50e9426295cb22097514fc15155e7`.

Local cause established: `verify.py` ran Node tests from `savia/`. `sale-lifecycle.test.mjs` resolves `savia/web/api.mjs` from the current directory, producing `savia/savia/web/api.mjs` and `ERR_MODULE_NOT_FOUND`.

The same lifecycle test passed 7/7 from the repository root. The new regression executes the actual runner web step: red before the fix, green after. The correction runs only that step from the repository root with matching paths, as CI already does. Other step working directories remain unchanged.

| Evidence | Result |
| --- | --- |
| Original quick before | Exit 1; rules/tool tests PASS, web FAIL, Biome/formal SKIP |
| Focused regression before | Exit 1; 3 PASS, 1 FAIL; 0.702s |
| Focused regression after | Exit 0; 4/4; 0.681s |
| Original unmodified .NET Spec17 | Exit 0; 1/1; invokes the sole final complete quick run |
| Final quick | 4 PASS, 0 FAIL, 1 SKIP; rules, 30 tool tests, Biome 65 files, 98 web tests PASS |
| Formal | SKIP / NOT RUN; TLA+ jar absent |
| Protected product/workflow/check/C# paths | Git diff exit 0; LF/Git bytes unchanged |
| Whitespace | `git diff --check` exit 0 |

Safety guards simulate subprocesses to assert quick mode never invokes SQL/full-check/pilot operations, including a failed quick step. Full-mode guards preserve reset, up, final down and failure blocking. No SQL, Docker, API, browser or pilot runtime was executed.

Historical CI: [run 43943782960, attempt 1](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/43943782960). Retrieved job `133567900269` confirms the exact source SHA, Node 24.22.2, T-SQL PASS=134, build/format PASS and .NET 144 PASS / 1 FAIL (Spec17). Container, volume and network removal are logged. The wrapper truncates inner diagnostics; the exact historical quick failure cause remains unconfirmed. The local reproduction and correction are verified separately.

Changed code: `savia/tools/verify.py`, new `savia/tests/test_verify.py`. No assertions removed, timeouts enlarged, checks skipped or C# changes. No stage, commit, push, CI retry or deploy.

Requested: codex / gpt-6.1-sol / explicit high. Runtime exposed: T3 Code / Codex / gpt-6.1-sol / high, SUAZO-PC. Internal token and provider USD telemetry: unknown. Managed worktree and branch verified. Installed SDK 10.0.402 was reused. Locked restore and local locked npm dependencies succeeded; no new dependency or global install.

Full command/exit records, LF source/returned hashes, timings, cleanup and NOT RUN are in [RESULT.json](RESULT.json). Private raw evidence stays ignored under `savia/.out/private-exports/ci-worker/` and `savia/.out/verify/20261116T200552Z/`, `savia/.out/verify/20261116T200838Z/`. Public receipts contain no credentials.

Lesson: match each subprocess working directory to CI. Root-level success does not prove a nested wrapper resolves the same module paths.

Next owner: primary inspects the exact diff and hashes, then imports the four approved paths serially. Formal and full runtime remain outside this worker's evidence.
