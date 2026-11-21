# Untangle log: SAVIA v2

Audit of commit `aa05e71` (2026-11-12). Scope: `savia/` only.
Method: [shadcn/improve](https://github.com/shadcn/improve) (audit with evidence, then plans) and
[caldoai/untangle-codebase](https://github.com/caldoai/skills) (one question: should these pieces change together?).
Each fix is listed above the problems it removes. Status: `TODO`, `DONE <commit>` or `REJECTED <reason>`.
Line numbers refer to `aa05e71`; reread the file before acting on one.

Goal: a typical change lands in one place, and a wrong change fails a check instead of reaching Jason.

## Fixes

### F1. One screen table for the web — DONE

Done: `web/roles.mjs` holds `SCREENS` (route, label, roles), the role names and texts, `canAccess`, `isApprover`, `isOwner`, `landing`.
The menu is built from it; `app.mjs` refuses to start when its module map and the table disagree.
No role literal is left outside `roles.mjs`. `tests/roles.test.mjs` pins the access table as it was at `df6ed8b`.
Fixed on the way: Ajustes described a seller with the stock worker text.

One table with route, title, roles and module. The menu, the access check, the landing page and the role labels read it.

- `web/roles.mjs:3-6` decides access with one nested conditional per screen.
- `web/app.mjs:24-41` lists the same screens again as `ROUTES`; `web/index.html` lists them a third time as menu links.
- `web/app.mjs:42`, `:72`, `:102` repeat `['MANAGER','OWNER']` three times with two names.
- `web/app.mjs:124` picks the landing page with a second role chain.
- `web/screens/settings.mjs:16` describes roles with the retired words "Supervisión" and "Caja".
- `web/screens/commissions.mjs`, `return.mjs`, `reception.mjs`, `etiqueta/etiqueta.mjs` test role literals on their own (11 literals).

### F2. Name the role sets once on the server — DONE (working tree on `df6ed8b`, not committed)

`Savia.Domain/Roles.cs` holds eight named sets: `OwnerOnly`, `Approvers`, `TillOperators`, `StockWorkers`, `Receivers`, `CommissionReaders`, `SalesStaff`, `CloudReaders`.
Every guard passes one set.
`Guard.Role` lost its `params`, so a single role constant no longer compiles as a role list.
`Guard.BranchRole(actor, node, roles)` in `Core.cs` replaces the private helpers `StockWorker`, `Manager`, `Seller` and `Owner`.
The old `Seller(actor)` and `Sellers` are `Roles.TillOperators`: CASHIER, MANAGER and OWNER, without SELLER.
CASHIER stays in every set that had it; removing it is a product decision, not part of this change.
Evidence: `savia/.out/roles-before.txt` and `savia/.out/roles-after.txt`, written by `savia/.out/roles_table.py` from the source.
Evidence line: `ROLES SAME: 61 of 61 methods keep their role lists; multiset of lists equal; 61 methods after`.
Rule: `guards use named role sets` in `tools/rules.py`.

Problems it removed:

- `Savia.Application/PilotSales.cs:116-121` has `Seller(actor)`, which allows CASHIER, MANAGER and OWNER and refuses SELLER.
- `Savia.Application/Modules.cs:239` has `Sellers = [Cashier, Manager, Owner]`: same trap.
- CASHIER is a role no staff member has (`db/pilot/seed_masaya.sql:51` converts it), yet 5 guards and 3 web files still allow or describe it.
- 40 `Guard.Role(...)` calls spell their role lists by hand; the same list appears with different orders.

### F3. Slice the server by domain, not by delivery round — DONE (working tree on `df6ed8b`, not committed)

Twelve modules: `Auth`, `Site`, `Catalog`, `Receiving`, `Inventory`, `Cash`, `Sales`, `Returns`, `Customers`, `Reports`, `Commissions`, `Tags`.
Each module M has `Savia.Application/M.cs` (port `IMStore` and `MService`), `Savia.Infrastructure/MStore.cs`, `Savia.Api/MEndpoints.cs` and `Savia.Contracts/M.cs`.
`Endpoints.cs` keeps `ActorFilter`, the `Http` helpers and one method that calls each module's `Map` in a fixed order.
The route tag is the module name in lower case.
`Modules.cs`, `Stores.cs`, the three `PilotSales.cs` files, `OwnerPilotEndpoints.cs` and `TagEndpoints.cs` are gone.
Method bodies moved verbatim by script (247 chunks, 1,390 lines); no route, status code, message or role list changed.
`ReadElement`, `ReadJson` and the JSON options are written once in `Savia.Infrastructure/SqlJson.cs`.
The CSV writer is the static `ReportCsv.From` in `Savia.Application`.
`ReturnsService` calls `SalesService.DetailAsync` to read the sale back, the same call the old class made on itself.
The layer projects stay (ADR-001).

Evidence, all on the pilot database `SAVIA_DEV_pilot`:

- `api_snapshot.py compare`: `SNAPSHOT SAME: 170 of 170 calls identical` (every GET route as each of the five roles).
- `pilot_smoke.py`: `PILOT SMOKE PASS`.
- `.NET tests on real SQL`: `Failed: 0, Passed: 76`, with `tests/Savia.Tests` unchanged.
- `dotnet build Savia.slnx`: `0 Warning(s)`, `0 Error(s)`.

Decisions and rejected options:

- The nine small domains first listed here became five larger modules: sales history went to `Sales`, pricing to `Catalog`, approvals to `Reports`, stock exceptions to `Inventory`, receiving quality to `Receiving`.
- `Catalog` has a second port, `ICatalogMaintenanceStore` (item values and import).
  Adding those members to `ICatalogStore` was rejected: `TagExtractTests` replaces that port with a fake, and the tests were frozen for this change.
- The quality report (`receiving.usp_QualityReport`) and the approvals log (`security.usp_ListApprovals`) live in `Reports`, as read-only reports.
- Stock exceptions call `sales.usp_*` procedures but live in `Inventory`, where the route `/stock/exceptions` points.
- `TagOcr.cs` keeps its name: the `Tags` module has an OCR reader, not a store.
- The configuration key `Savia:Pilot:LocalCatalog` keeps its name: `pilot.py` and the tests set it, and it is not a type or a file.
- One SQL text changed by whitespace only: the opening-count subquery of `CashStore.GetTillSummaryAsync` is now three lines (it was 255 characters).
- Not fixed, by the no-behavior-change rule: messages without accents (F9), `{date}` without a format in three CSV file names, the open `POST /catalog/items` that answers 404.

Problems it removed:

- `PilotSalesService`, `IPilotSalesStore`, `PilotSalesStore` hold nine unrelated domains (19 store methods). Every feature edits the same three files, which is where the parallel agents collided.
- `Savia.Api/OwnerPilotEndpoints.cs` is named after who asked, and `.WithTags("pilot")` tags by round.
- `Savia.Application/Modules.cs` holds five services; `Savia.Infrastructure/Stores.cs` holds five stores.
- `PilotSalesService.SummaryCsv` is a CSV writer inside a sales service; the commissions endpoint calls it.
- `Savia.Api/Endpoints.cs` maps 45 routes of 8 domains in one method.

### F4. One pilot client and one verify command — PARTLY DONE

Done since: e2e screenshots go to the evidence folder (`SAVIA_E2E_SHOTS`); `tests/all.mjs` deleted; `tools/api_snapshot.py` pins every GET route as each role.

Done: `tools/verify.py` (rules, tool tests, web tests, check, demo reset, smoke, e2e twice, live tag OCR; evidence in `.out/verify/`)
and `tools/tag_live.py`. `verify.py --quick` passes on `aa05e71`; the full mode has not run yet.
Todo: `tools/pilot_client.py` (URL, logins, `login`, `call`, `check`) shared by smoke, e2e and tag live.

- `web/tests/e2e_pilot.py` writes its screenshots into the tracked `docs/pilot/screens/`, so every run dirties the checkout. They belong in the evidence folder.
- `web/tests/all.mjs` lists the test files by hand and misses `confirm.test.mjs`; the documented command skips the 16 scanner tests. `verify.py` runs both globs (66 tests).

- `tools/pilot_smoke.py` and `web/tests/e2e_pilot.py` each define `call` and `check` and the base URL.
- The five login names are spelled in `pilot.py` (10), `e2e_pilot.py` (13), `seed_masaya.sql` (7) and a C# test (15).
- The live tag OCR check that found the 0-of-6 bug lives outside the repo.
- The acceptance list is retyped in every worker packet; nothing runs it as one command.

### F5. Shared web pieces for repeated screen code — PARTLY DONE

Done: `api.retryIds()` replaces the hand-written retry ids in six screens (sale, till open, reception, quality, prices, commissions).
Done: one `send()` in `api.mjs` for JSON, the tag upload and CSV; an expired session is now reported on all three.
Done: `saleReceipt` alias and history comments removed.
Todo: the period toolbar shared by reports and commissions; `cash.mjs` and product registration keep their own stored ids (they survive a reload).
Todo: `sale.mjs` is 808 lines after formatting and should be split by panel (sellers, ticket, payment).

`submitOnce(parts)` in `api.mjs` for retry-safe ids, and one period toolbar (period, date, consult, CSV).

- `web/screens/commissions.mjs` and `prices.mjs` each rebuild `pending = { key, changeId }`.
- `commissions.mjs` and `report.mjs` each build the period select, the date input and the CSV button.
- `prices.mjs` formats money with `(minor / 100).toFixed(2)` beside `money.mjs`.
- `web/api.mjs:95-108` repeats the fetch and error code of `request` for the tag upload; `:158-165` repeats it for CSV.
- `api.mjs` keeps `saleReceipt = getSale` and comments such as "Existing:" and "final pilot sales contract (V013)" that describe history, not behavior.

### F6. Format and type-check by machine — C# and web DONE; types TODO

Done: `savia/.editorconfig` (UTF-8, LF, 4 spaces, braces on their own line, file-scoped namespaces) and `dotnet format` applied to `savia/src`.
Done: `check.py` has the step `C# format`: `dotnet format Savia.slnx --verify-no-changes --no-restore --exclude tests`.
Done: `savia/src/.gitattributes` keeps `*.cs` as LF on a checkout with `core.autocrlf=true`, or the format check would fail there.
Done: no file in `savia/src` has more than 300 lines and no line more than 160 characters; the rule `source stays readable` checks it.
`TagExtraction.cs` (356 lines) became `Tags.cs` and `TagParser.cs` (299 lines).
Evidence: `dotnet format Savia.slnx --verify-no-changes --exclude tests` exits 0.
Todo: `tests/Savia.Tests` is not formatted, because the tests were frozen during the restructure.
Without `--exclude tests` the verify exits 2, with findings only in `tests/Savia.Tests`.
Next action: run `dotnet format Savia.slnx`, review that the test diff is whitespace only, then drop `--exclude tests` from `check.py`.
Todo: one web formatter and linter; `// @ts-check` on the logic modules.

- `OwnerPilotEndpoints.cs`, `PilotSales.cs` (both layers), `commissions.mjs`, `prices.mjs`, `confirm.mjs` are written without spaces and with lines up to 260 characters; neighbours are not. Agents copy whichever file they read last.
- No `.editorconfig`, no web lint, no type check on 4,800 lines of `.mjs`.

Web: Biome 2.6.4 pinned in `savia/package.json` (dev tool only), `biome.json` (140 columns, single quotes), 0 findings; `verify.py` and CI run it.
Tests project formatted too; `check.py` verifies the whole solution.
Todo: type checking of `.mjs` (`// @ts-check` with TypeScript).

### F7. Rules as checks — PARTLY DONE

Done: `tools/rules.py` with six rules (migrations frozen by `db/migrations/MANIFEST.sha256`, no browser dialogs or HTTP outside
`api.mjs`, pure logic modules, layer direction, web paths exist in the API, no disabled tests). All hold on `aa05e71`.
`tests/test_rules.py` proves each rule fails on a bad tree. Every failure prints `file:line` and what to do instead.
Done after F2, F3 and F6: three more rules, each with failing cases in `tests/test_rules.py`.
They are `guards use named role sets`, `source stays readable` (300 lines, 160 characters) and `no pilot names` (types and files in `savia/src`).
`check.py` runs `rules.py` as the step `architecture rules`.
Todo: the web rules that need F1 (role literals in screens).
Known defect, not fixed here: `rules.py:147` has a backspace character where `\b` was meant, so `pytest.mark.skip` is never matched.

- "Never edit a committed migration" is prose in every packet; only `V001` is checked.
- "No `window.confirm`", "every HTTP call lives in `api.mjs`", "logic modules stay pure" are prose or convention.
- Layer direction (Domain and Contracts import nothing; only Infrastructure talks to SQL) is convention.
- Routes are listed by hand in `Endpoints`, `web/api.mjs` and `docs/pilot/API-PILOT.md`; nothing compares them.

### F8. CI for SAVIA v2 — DONE

Run 43382164855 on `df6ed8b`: success (rules, tool tests, web tests, SQL Server, `check.py`). The first run failed on two Windows-only tool tests.
Added after that run: web format and lint (Biome).

`.github/workflows/savia-v2.yml`: rules, tool tests, web tests and `check.py` on a disposable SQL Server, on every push to `Tony`
that touches `savia/`. `actionlint` passes. It has never run on GitHub; the first push is the test.
Not in CI yet: the browser e2e (needs agent-browser on the runner) and the live tag OCR (needs the OCR install).

- No workflow runs `savia/tools/check.py`, the web tests or the e2e. `savia.yml` tests the older `dev/savia-staff-ui`.
- The merge of tag photo and Azure did not compile, and nothing but a manual run could have said so.

### F10. Model-check a design before building it — DONE for apartado

`tools/formal.py` (pinned Java 21 and TLA+ tools 1.7.4 under `.out/tools/formal`) and `formal/apartado/`.
Six checks give the expected result; three of them are rejected designs that must fail. `verify.py` runs it.
Next target: branch sync (hub and three branches), before that code is written.

### F9. One vocabulary — WEB DONE, SERVER TODO

Done: visible web text says gerente and dueña instead of supervisora and cajera; `Sí, confirmar` has its accent.
Todo: server messages without accents (a text change is a behavior change for the API pin; do it as its own commit).
Todo: the second-person approval flow (`supervisorApproval`) is unreachable while only approvers reach those screens; removing it is a product decision.

Gerente, dueña, vendedor, bodega everywhere; Spanish with accents in every message.

- Server messages without accents: "La busqueda", "pagina invalida", "lineas de devolucion" (`PilotSales.cs:125-140`); "Si, confirmar" in `web/confirm.mjs:8`.
- "Supervisión" and "Caja" remain in UI text and docs after the real-roles decision.

## Special cases found

- `SqlGateway.cs:58-60` retries transient SQL errors with a random delay. Keep: deadlock victims are expected (V004, V021).
- `TagOcr.cs` swallows a warm-up failure. Keep: the next photo reports it.
- `api.mjs:164` revokes the CSV object URL after 1 s. Keep: browsers need the URL until the download starts.
- `CatalogEndpoints.cs` maps an open `POST /catalog/items` that returns 404 when the local catalog is off. Reviewed in F3 and kept: changing it changes behavior.
- `CashStore.DenominationsAsync` reads a table with inline SQL. Reviewed in F3 and kept: its new neighbours in `CashStore` read with inline SQL too.

## Considered and rejected

- Typed contracts for the reports that travel as SQL JSON (`JsonElement`): the shape is owned by the procedure (ADR-001 D2). A generated client (CP5) is the right time.
- Merging the layer projects into feature folders: ADR-001 decided the layers; the compile-time direction is worth more than colocation here.
- `tools/db/simulator.py` (600 lines, paused): needed for branch sync; not dead.
- Refactoring `backend/`, `dev/`, `dist/`, `build-inputs/`: not SAVIA v2. Hiding them from searches waits for Jason's answer.

## Not audited

SQL procedure bodies (7,477 lines of migrations), `db/tests`, `deploy/azure/main.bicep`, CSS, and everything outside `savia/`.
