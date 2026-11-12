# SAVIA pilot staff web

Local acceptance passed on 2026-11-12. The API is stopped.
The final browser check passed twice in succession: 18 checks per run, zero failures, zero console errors and zero page errors.
This is the uncommitted working tree based on `d1ec8584a150e479dd298e5647ca4925ac9fe6c5`.
No commit, push, deployment, external service call, container creation or dependency installation was performed by Worker B.

## Run locally

Use the existing `savia-sqlserver-dev` container.
Set three different temporary passwords in the current shell, without printing them:
`SAVIA_PILOT_PASSWORD_CAJERA`, `SAVIA_PILOT_PASSWORD_SUPERVISORA` and `SAVIA_PILOT_PASSWORD_DUENA`.
Each password must have at least ten characters.
Run `python savia/tools/pilot.py up` and open <http://127.0.0.1:5080/> on the same PC.
The API hosts the web and `/api/v1` on the same origin. No separate web server is needed.
See [API-PILOT](API-PILOT.md) for provisioning and the final endpoint contract.

Use `supervisora.muestra` for reception approval, posting and till closure.
Use `cajera.muestra` for opening a till, selling and counting cash.
`duena.muestra` is the owner account. All data is synthetic MUESTRA data.

## Screens and behavior

| Screen | Result |
| --- | --- |
| Ingreso and navigation | `/me` supplies branch, operator and roles. Sales links require C/M/O; the day report requires M/O. The API remains the permission authority. |
| Recepción and review | Existing scan, registration, rejection, approval and stock-posting flows remain intact. Keyboard bursts work without input focus. |
| Venta | Editable ticket quantities; cash, card, transfer, customer credit and other tenders; split payment. Card/transfer require a reference. Only cash has received/change fields. |
| Cliente in Venta | Optional customer search also associates a cash/card sale with a customer. A credit payment requires a selected local NIO credit allocation. Selection keeps the customer's name visible and collapses the search. |
| Historial | Receipt id, recorded garment name or SKU search; inclusive Nicaragua date filter; server pagination. Every line has its SKU photo, recorded name, size, quantity, unit price and server line total. |
| Recibo | Full API lines and tenders after a sale and from Historial. Reimprimir calls `window.print()`. The print sheet uses an 80 mm page, with photos and navigation hidden. |
| Devolución | Opens from Historial. Quantities cannot exceed sold minus returned. Reason, credit refund and store/quarantine choice. Cashiers use a second login dialog for a real supervisor session; their own session stays in place. |
| Clientes y anticipos | Search customers, then show each positive credit allocation with its amount, currency and branch. Allocations from another branch are identified. |
| Reporte del día | SQL counts, currency totals, tender totals, reversals and stored till/accounting figures. The browser does not reconstruct financial totals. Printable on A4. |
| Caja and Inventario | Existing API cash summary, denomination count, supervised closure and physical/reserved/available stock views remain intact. |

All HTTP calls remain in `savia/web/api.mjs`. Screens are ES modules and expose `handleScan`.
Money stays in integer minor units. Ticket, change and denomination previews use pending input and API prices.
All persisted sales, returns, stock, balances, cash and report figures come from the API.
New screens use the existing SAVIA 08 tablet tokens, panels, garment photos and rows.
The approved reference folder was read-only. No product image was imported or replaced.

## Contract boundaries

- Returns support **store credit only**. No cash-return SQL procedure or API endpoint exists. This is a documented contract limit, not a defect found in these web checks.
- The sale must already have its verified customer. Anonymous sales cannot use this return procedure.
- Restock selected means `store`; unselected means `quarantine`. The form describes both choices. A credit return does not reduce till cash.
- Approval is the authenticated supervisor. The web never submits a trusted approver id or modifies the cashier's roles/token. Its temporary approval token is logged out after use.
- Card/transfer references record a payment completed outside this application. There is no bank gateway or card-number collection.
- History uses sale snapshots. A catalog product label can differ from the recorded garment name. Size is the current catalog size because SQL has no size snapshot.
- SQL timestamps without offsets are interpreted as UTC. History filters and report dates use Nicaragua business dates.
- This UI pilot sells in NIO. Credit allocation views retain each API currency and branch; report currency groups are shown separately.
- New product variants remain unclassified because the API has no size/color-list endpoint.
- The same browser retains denomination input and count ids for cashier-to-supervisor closure handoff. Clearing its storage requires a new count.

## Verification and evidence

Worker B polled the required `a.done` marker every 60 seconds. It was present by 16:39 local time (UTC-06:00), within the 45-minute limit.
No build, pilot runner or port 5080 request was made before the marker.
Worker B then read the final API documentation and `savia/src/Savia.Api/Endpoints.cs` before binding the web.

| Command/check | Exit | Result |
| --- | --- | --- |
| `node --test savia/web/tests/payments.test.mjs` before the builder fix | 1 | Red: two card/split assertions; the old builder substituted cash and invalid change. |
| `node --test savia/web/tests/date-focus.test.mjs` before the focus fix | 1 | Red: the scanner helper took focus from the date filter. |
| Agent-browser CSS parser probe before/after the print fix | 1 / 0 | Chrome rejected `80mm auto`; accepted the final named 80 mm page. |
| Spanish report-title probe before/after correction | 1 / 0 | A PowerShell pipe had corrupted accented source text; the UTF-8 patch restored it. |
| Return-footer image check before/after the tablet correction | 1 / 0 | Primary-button pixels in the lower viewport: 1,468 → 50,836. The final browser check also asserts the button's viewport bounds. |
| `node --test "savia/web/tests/*.test.mjs"` | 0 | 37 passed, zero failed. Includes token isolation, payment validation, return bounds and business dates. |
| `node --test "savia/web/scanner/*.test.mjs"` | 0 | 16 passed, zero failed. |
| `python savia/tools/pilot.py reset` | 0 | Fresh sample pilot database. Existing container only. |
| `python savia/tools/pilot.py up` | 0 | Migration/seed/build and three separate in-memory passwords; loopback API ready. |
| `python savia/web/tests/e2e_pilot.py` — final run 1 | 0 | 18 passed; console 0; page errors 0. Seeded stock starts at 0 and ends at 2. |
| `python savia/web/tests/e2e_pilot.py` — final run 2, without reset | 0 | 18 passed; console 0; page errors 0. Seeded stock starts at 2 and ends at 4. |
| `python savia/tools/pilot.py down` | 0 | Pilot API stopped. A separate loopback health probe confirmed connection refusal. |
| `git diff --check -- savia/web savia/docs/pilot/WEB.md` | 0 | No whitespace errors. |

Each final browser run checks receiving five units, original-scan registration, rejection, unchanged pending stock, posting, a two-unit cash sale, a one-unit card sale, receipt/SKU/name search, receipt printing invocation, a supervised one-unit credit return, credit balances, credit redemption, cash count, balanced closure and the API day report.
The cash sale total is `119800` minor units, change is `180200`, and closure difference is `0`.
The return restocks exactly one unit. Card, credit return and credit redemption leave expected cash unchanged.
Transfer and split-payment input previews are exercised; their actual submission is covered by request/unit checks, not a persisted browser sale.

The CLI's native Windows executable avoids CMD reparsing of quoted JavaScript.
Forms use fresh accessibility refs. Native disclosure nodes have no refs in this CLI, so their opening uses its semantic text action after a fresh snapshot.
Early driver/fixture failures were corrected before the final pair: disclosure refs, inline select-label extraction, CMD quoting and catalog-label versus receipt-snapshot name.
There were no API defects found in the final web flow. No API source was edited by Worker B.
Credentials enter the temporary encrypted CLI vault through stdin. Login profiles are deleted after use; passwords are not printed or stored in evidence.

The 29 current captures emitted by the browser check are 1024×768, including every new screen and payment variation.
Reviewed captures are in [screens](screens/); hashes, exact paths and source bindings are in [WEB-VERIFICATION.json](screens/WEB-VERIFICATION.json).
`ingreso-2.png` and `inventario-fotos.png` are older captures and are excluded from the current verification manifest.

## Explicit staging scope and next action

Only the following web paths, this document, the verification manifest and its listed current captures are staged by Worker B:

```text
savia/web/API-NEEDS.md
savia/web/api.mjs
savia/web/app.css
savia/web/app.mjs
savia/web/index.html
savia/web/roles.mjs
savia/web/scan.mjs
savia/web/screens/customers.mjs
savia/web/screens/history.mjs
savia/web/screens/payment-logic.mjs
savia/web/screens/payments.mjs
savia/web/screens/receipt.mjs
savia/web/screens/report.mjs
savia/web/screens/return-logic.mjs
savia/web/screens/return.mjs
savia/web/screens/sale-logic.mjs
savia/web/screens/sale-view.mjs
savia/web/screens/sale.mjs
savia/web/tests/all.mjs
savia/web/tests/api-contract.test.mjs
savia/web/tests/date-focus.test.mjs
savia/web/tests/e2e_pilot.py
savia/web/tests/payments.test.mjs
savia/web/tests/receipt.test.mjs
savia/web/tests/returns.test.mjs
savia/web/tests/roles.test.mjs
savia/docs/pilot/WEB.md
savia/docs/pilot/screens/WEB-VERIFICATION.json
```

Unchanged captures explicitly passed to staging create no new Git diff. Other workers' staged paths are preserved.
Next action: integration review of this staged web with Worker A's staged API. The API remains stopped.

## Not verified by Worker B

No repository-wide check, CI run, SQL conservation audit, physical scanner/printer, bank gateway, multi-node sync, mobile, accessibility or performance acceptance was performed by this worker.
The owner account's browser flow, pagination across more than 25 sales, date-filter interaction, quarantine return and persisted transfer/split/other sales were not exercised end to end.
Unit/request checks cover the relevant input and date mappings; these are not substitutes for browser or physical-device acceptance.
Headless printing uses a spy for the `window.print()` action and verifies the browser-accepted stylesheet. Paper output and a physical print dialog were not tested.
