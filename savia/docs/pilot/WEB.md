# SAVIA pilot staff web

Run `python savia/tools/pilot.py up` from the repository root with Docker and the development SQL container available.
The runner asks for the sample staff password if `SAVIA_PILOT_PASSWORD` is absent.
Open <http://127.0.0.1:5080/> on the same PC.
The API serves the web and `/api/v1` on the same origin.
No separate web server, package installation, CDN or deployment is needed.
Use `supervisora.muestra` for receiving, product registration, rejection, approval, posting and till closure.
Use `cajera.muestra` for till opening, cash sales and cash counts.
The optional owner login is `duena.muestra`.
All three sample users use the password supplied to the pilot runner.
All data is MUESTRA sample data.

## Screens

- Ingreso signs in and then shows the operator and branch returned by `/me`.
- Recepción opens or resumes a reception and accepts the scan field plus Enter or a keyboard scanner burst after focus is lost.
- Registrar producto creates a product and variant with a price and approved cost, then resolves the original scan.
- Rechazar lectura requires a reason and retains the rejected reading in the reception.
- Revisar recepción shows server quantities, approves the session and posts it to inventory in separate actions.
- Venta opens an available register, adds scanned or searched products and records a cash sale with change.
- Caja shows the API cash summary, saves a denomination count and lets a supervisor close the till.
- Inventario displays physical, reserved and available stock returned by the API.

## Verification

Run `node --test "savia/web/tests/*.test.mjs"` for the web unit tests.
Run `node --test "savia/web/scanner/*.test.mjs"` for the unchanged scanner module tests.
Set `SAVIA_PILOT_PASSWORD` in the current shell before running the browser check.
Run `python savia/tools/pilot.py reset` and then `python savia/tools/pilot.py up` to start with fresh sample data.
Run `python savia/web/tests/e2e_pilot.py` twice without resetting between these two runs.
The browser check uses the installed agent-browser CLI with fresh accessibility refs and direct API read-backs.
It requires every step and fails on any browser console error or page error.
It compares one grouped line of five seeded scans, original-scan registration, rejection, unchanged pending stock, posted stock, a sale of two, change and zero till difference.
The no-focus scan is an emulated keyboard burst through the real scanner listener.
Screenshots are overwritten at 1024×768 in [screens](screens/).
Each run uses unique sample codes and closes its browser session.
Credentials enter the CLI vault through stdin and the temporary encrypted credential profile is deleted after each login.

## Limits

This pilot covers one PC, one branch and cash in NIO.
The local catalog flag must be enabled by the pilot runner.
New variants have no size or color classification because this API has no classification list endpoint.
Persistent stock, reception quantities, prices, till summaries and sale or closure results come from the API.
Ticket totals, change previews and denomination totals are calculations over pending staff input and API prices.
Sale read-back contains totals but no tender details, so change is checked as entered cash minus the API sale total.
The same browser keeps submitted denomination input and count identifiers for the cashier-to-supervisor handoff because the API has no count read endpoint.
Clearing browser storage requires a new count before closure.
No physical scanner, printer, card payment, multi-node sync, mobile, accessibility or performance acceptance is claimed.
No external calls, deployments, commits or pushes are part of this work.

## Local evidence

The candidate is the working tree based on `33f033b543ef0c06007f5b027e2847fb320dc1c6`.
The web unit suite passed 24 tests with exit 0.
The unchanged scanner suite passed 16 tests with exit 0.
The first complete real-browser run passed 12 checks with zero console errors and zero page errors.
The initial empty-stock assertion was corrected to compare the API's absent stock row with the screen's empty state.
No API defect was found in that complete run.
On 2026-11-12, `python savia/tools/pilot.py reset` and `python savia/tools/pilot.py up` both exited 0 after the backend completion marker appeared.
Two consecutive final executions of `python savia/web/tests/e2e_pilot.py` each exited 0 with `SUMMARY: 12 passed; 0 failed`.
Each final execution reported `console errors: 0; page errors: 0`.
The first final run checked seeded stock `0 → 5 → 3` and the second checked `3 → 8 → 6`.
Each final run checked a sale total of `119800` minor units, change of `180200`, and till closure difference `0`.
The current captures cover login, receiving, registration, rejection, review, posted stock, sale, cashier count, closure and final inventory.
The API remains running locally at <http://127.0.0.1:5080/> after verification.
The work is staged with explicit source, test, documentation and screenshot paths and has no new commit or push.
Repository-wide checks, CI, SQL conservation audit and physical device testing were not run by this web worker.
The next action is integration review of the staged web against the staged pilot API changes.
