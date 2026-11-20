# Local pilot checkout and cash reconciliation

SUAZO-PC ran the working tree based on `16ab6f2d683854622d5caa84574ccbc0b6807ffb` against an isolated SQL Server database with fictitious staff and stock. The second product had three units before the journey. All 183 source hashes recorded for the final run matched on readback.

The browser initially left a successful HTTP 200 sale pending. The real API returned the SQL status `recorded`. The client now accepts this status and the existing demo status. The focused receipt regression failed before the correction. All 159 web and scanner tests passed afterward.

The pilot driver opens the shared-sale controls, checks the seller shown on each receipt line and checks the transfer return confirmation. The final run of `savia/web/tests/e2e_pilot.py` exited 0 with five roles, 12 screenshots and zero browser console or page errors. A separate SQL query found three sales, two returns, four imported items totaling ten units, and zero conservation discrepancies. NIO and USD expected and counted amounts were 283780 and 1800 minor units respectively, with zero difference in either drawer. The transfer refund used the browser. The credit refund and drawer close used the API.

Local raw evidence lives under `savia/.out/journey-e83aa4f9/`. See `run-04.log`, `run-04-source-manifest.json`, `run-04-source-readback.log` and `final-cleanup.log`. Cleanup verified absence of the test database, owned container, browser sessions and API listener.

GitHub job `133829831783` failed at SQL login on the published base. Its readiness step wrote the password for future steps but did not export it to its own probe. The corrected step exports the password and requires a SQL response marker. Four local shell controls distinguished missing output and authenticated success. The corrected workflow still needs remote execution on the published candidate before merge.

## Publication on Tony at 0147124

GitHub completed all 12 workflows on attempt 1. Ten passed, including SAVIA Azure hub and SAVIA golden path. Both SAVIA v2 checks failed. [Push and PR run](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/44221668207) and [companion run](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/44221657918).

Biome reported five formatting and import-order diagnostics across four test files. After formatting those files locally, the workflow command `node node_modules/@biomejs/biome/bin/biome check web` passed on all 71 candidate files. The focused Node suite passed 26/26 with zero skips. Remaining merge check: publish this correction to Tony after approval for one new CI cycle and verify downstream jobs on its commit.
