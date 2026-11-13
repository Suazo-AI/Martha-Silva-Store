# Untangle log: SAVIA v2

Audit of commit `aa05e71` (2026-11-12). Scope: `savia/` only.
Method: [shadcn/improve](https://github.com/shadcn/improve) (audit with evidence, then plans) and
[caldoai/untangle-codebase](https://github.com/caldoai/skills) (one question: should these pieces change together?).
Each fix is listed above the problems it removes. Status: `TODO`, `DONE <commit>` or `REJECTED <reason>`.
Line numbers refer to `aa05e71`; reread the file before acting on one.

Goal: a typical change lands in one place, and a wrong change fails a check instead of reaching Jason.

## Fixes

### F1. One screen table for the web — TODO

One table with route, title, roles and module. The menu, the access check, the landing page and the role labels read it.

- `web/roles.mjs:3-6` decides access with one nested conditional per screen.
- `web/app.mjs:24-41` lists the same screens again as `ROUTES`; `web/index.html` lists them a third time as menu links.
- `web/app.mjs:42`, `:72`, `:102` repeat `['MANAGER','OWNER']` three times with two names.
- `web/app.mjs:124` picks the landing page with a second role chain.
- `web/screens/settings.mjs:16` describes roles with the retired words "Supervisión" and "Caja".
- `web/screens/commissions.mjs`, `return.mjs`, `reception.mjs`, `etiqueta/etiqueta.mjs` test role literals on their own (11 literals).

### F2. Name the role sets once on the server — TODO

`Roles.TillOperators`, `Roles.Approvers`, `Roles.Receivers` in `Savia.Domain`; services use the names.

- `Savia.Application/PilotSales.cs:116-121` has `Seller(actor)`, which allows CASHIER, MANAGER and OWNER and refuses SELLER.
- `Savia.Application/Modules.cs:239` has `Sellers = [Cashier, Manager, Owner]`: same trap.
- CASHIER is a role no staff member has (`db/pilot/seed_masaya.sql:51` converts it), yet 5 guards and 3 web files still allow or describe it.
- 40 `Guard.Role(...)` calls spell their role lists by hand; the same list appears with different orders.

### F3. Slice the server by domain, not by delivery round — TODO

One name per domain across the three layers: `SalesHistory`, `Returns`, `Customers`, `Reports`, `Commissions`, `Pricing`,
`Approvals`, `StockExceptions`, `ReceivingQuality`, plus the existing `Catalog`, `Receiving`, `Inventory`, `Cash`, `Sales`, `Tags`.
The layer projects stay (ADR-001); only files and types are renamed and split.

- `PilotSalesService`, `IPilotSalesStore`, `PilotSalesStore` hold nine unrelated domains (19 store methods). Every feature edits the same three files, which is where the parallel agents collided.
- `Savia.Api/OwnerPilotEndpoints.cs` is named after who asked, and `.WithTags("pilot")` tags by round.
- `Savia.Application/Modules.cs` holds five services; `Savia.Infrastructure/Stores.cs` holds five stores.
- `PilotSalesService.SummaryCsv` is a CSV writer inside a sales service; the commissions endpoint calls it.
- `Savia.Api/Endpoints.cs` maps 45 routes of 8 domains in one method.

### F4. One pilot client and one verify command — PARTLY DONE

Done: `tools/verify.py` (rules, tool tests, web tests, check, demo reset, smoke, e2e twice, live tag OCR; evidence in `.out/verify/`)
and `tools/tag_live.py`. `verify.py --quick` passes on `aa05e71`; the full mode has not run yet.
Todo: `tools/pilot_client.py` (URL, logins, `login`, `call`, `check`) shared by smoke, e2e and tag live.

- `web/tests/e2e_pilot.py` writes its screenshots into the tracked `docs/pilot/screens/`, so every run dirties the checkout. They belong in the evidence folder.
- `web/tests/all.mjs` lists the test files by hand and misses `confirm.test.mjs`; the documented command skips the 16 scanner tests. `verify.py` runs both globs (66 tests).

- `tools/pilot_smoke.py` and `web/tests/e2e_pilot.py` each define `call` and `check` and the base URL.
- The five login names are spelled in `pilot.py` (10), `e2e_pilot.py` (13), `seed_masaya.sql` (7) and a C# test (15).
- The live tag OCR check that found the 0-of-6 bug lives outside the repo.
- The acceptance list is retyped in every worker packet; nothing runs it as one command.

### F5. Shared web pieces for repeated screen code — TODO

`submitOnce(parts)` in `api.mjs` for retry-safe ids, and one period toolbar (period, date, consult, CSV).

- `web/screens/commissions.mjs` and `prices.mjs` each rebuild `pending = { key, changeId }`.
- `commissions.mjs` and `report.mjs` each build the period select, the date input and the CSV button.
- `prices.mjs` formats money with `(minor / 100).toFixed(2)` beside `money.mjs`.
- `web/api.mjs:95-108` repeats the fetch and error code of `request` for the tag upload; `:158-165` repeats it for CSV.
- `api.mjs` keeps `saleReceipt = getSale` and comments such as "Existing:" and "final pilot sales contract (V013)" that describe history, not behavior.

### F6. Format and type-check by machine — TODO

`.editorconfig` with `dotnet format --verify-no-changes` in `check.py`; one web formatter and linter; `// @ts-check` on the logic modules.

- `OwnerPilotEndpoints.cs`, `PilotSales.cs` (both layers), `commissions.mjs`, `prices.mjs`, `confirm.mjs` are written without spaces and with lines up to 260 characters; neighbours are not. Agents copy whichever file they read last.
- No `.editorconfig`, no web lint, no type check on 4,800 lines of `.mjs`.

### F7. Rules as checks — PARTLY DONE

Done: `tools/rules.py` with six rules (migrations frozen by `db/migrations/MANIFEST.sha256`, no browser dialogs or HTTP outside
`api.mjs`, pure logic modules, layer direction, web paths exist in the API, no disabled tests). All hold on `aa05e71`.
`tests/test_rules.py` proves each rule fails on a bad tree. Every failure prints `file:line` and what to do instead.
Todo: call it from `check.py`; add the rules that need F1, F2 and F6 first (role literals, file and line size).

- "Never edit a committed migration" is prose in every packet; only `V001` is checked.
- "No `window.confirm`", "every HTTP call lives in `api.mjs`", "logic modules stay pure" are prose or convention.
- Layer direction (Domain and Contracts import nothing; only Infrastructure talks to SQL) is convention.
- Routes are listed by hand in `Endpoints`, `web/api.mjs` and `docs/pilot/API-PILOT.md`; nothing compares them.

### F8. CI for SAVIA v2 — WRITTEN, NOT RUN

`.github/workflows/savia-v2.yml`: rules, tool tests, web tests and `check.py` on a disposable SQL Server, on every push to `Tony`
that touches `savia/`. `actionlint` passes. It has never run on GitHub; the first push is the test.
Not in CI yet: the browser e2e (needs agent-browser on the runner) and the live tag OCR (needs the OCR install).

- No workflow runs `savia/tools/check.py`, the web tests or the e2e. `savia.yml` tests the older `dev/savia-staff-ui`.
- The merge of tag photo and Azure did not compile, and nothing but a manual run could have said so.

### F10. Model-check a design before building it — DONE for apartado

`tools/formal.py` (pinned Java 21 and TLA+ tools 1.7.4 under `.out/tools/formal`) and `formal/apartado/`.
Six checks give the expected result; three of them are rejected designs that must fail. `verify.py` runs it.
Next target: branch sync (hub and three branches), before that code is written.

### F9. One vocabulary — TODO

Gerente, dueña, vendedor, bodega everywhere; Spanish with accents in every message.

- Server messages without accents: "La busqueda", "pagina invalida", "lineas de devolucion" (`PilotSales.cs:125-140`); "Si, confirmar" in `web/confirm.mjs:8`.
- "Supervisión" and "Caja" remain in UI text and docs after the real-roles decision.

## Special cases found

- `SqlGateway.cs:58-60` retries transient SQL errors with a random delay. Keep: deadlock victims are expected (V004, V021).
- `TagOcr.cs` swallows a warm-up failure. Keep: the next photo reports it.
- `api.mjs:164` revokes the CSV object URL after 1 s. Keep: browsers need the URL until the download starts.
- `Endpoints.cs:97` maps an open `POST /catalog/items` that returns 404 when the local catalog is off. Review in F3.
- `PilotSalesStore.DenominationsAsync` reads a table with inline SQL while its neighbours call procedures. Review in F3.

## Considered and rejected

- Typed contracts for the reports that travel as SQL JSON (`JsonElement`): the shape is owned by the procedure (ADR-001 D2). A generated client (CP5) is the right time.
- Merging the layer projects into feature folders: ADR-001 decided the layers; the compile-time direction is worth more than colocation here.
- `tools/db/simulator.py` (600 lines, paused): needed for branch sync; not dead.
- Refactoring `backend/`, `dev/`, `dist/`, `build-inputs/`: not SAVIA v2. Hiding them from searches waits for Jason's answer.

## Not audited

SQL procedure bodies (7,477 lines of migrations), `db/tests`, `deploy/azure/main.bicep`, CSS, and everything outside `savia/`.
