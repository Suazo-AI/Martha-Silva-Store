# SEC-05 evidence: staff routes validate their body before save

Audit date: 2026-11-27, branch `Tony`, read-only.
Control: "Every staff route validates its body before save".
Result: 21 routes validated, 10 partial, 0 none; `/inventory/tag-extract` checks size and content.
No route lets a body reach the database without any check, but four fields can be saved silently truncated, and malformed or null JSON is not tested on any staff route.

## How to read this file

Paths are relative to `savia/`.
`Api/` is `src/Savia.Api`, `App/` is `src/Savia.Application`, `Contracts/` is `src/Savia.Contracts`, `Infra/` is `src/Savia.Infrastructure`, `Domain/` is `src/Savia.Domain`, and `tests/` is `tests/Savia.Tests`.
`Vnnn:line` means `db/migrations/Vnnn__*.sql` at that line.
For the procedures behind Gaps 1-10, a search of every migration for `CREATE OR ALTER PROCEDURE` confirmed the cited one is the latest definition; other procedures are cited at the newest migration found by name search.
"Engine default" or "framework default" marks behavior of SQL Server or ASP.NET that this audit expects but did not run; no repo test proves it.

Verdict rule:
- validated means every string has a length bound that fails with 422 before or inside the procedure, and every number, enum and id that the procedure needs has a check that fails cleanly.
- partial means at least one field can be saved wrong, can cause a 500, or has an unknown outcome.
- `Guid.Empty` ids are one cross-cutting gap (Gap 6) and do not change a route verdict.

Scope check: `grep -c "MapPost|MapPut|MapPatch"` over `Api/*Endpoints.cs` finds 43 staff write mappings outside `PublicEndpoints.cs` and `SyncEndpoints.cs`.
Removing `/auth/login` leaves 42.
Of these, 31 take a JSON `XxxRequest request` body (`grep -A2` for `Request request` after each mapping finds 32, including `/auth/login`), 1 is the multipart `/inventory/tag-extract`, and 10 have no body.
The 10 include `/auth/logout` (`Api/AuthEndpoints.cs:13`) and a `/catalog/items` stub that returns 404 on other nodes (`Api/CatalogEndpoints.cs:41`).

## Summary

| Route | Request | Verdict | Unchecked fields | Invalid-body test |
|---|---|---|---|---|
| POST /auth/password | ChangePasswordRequest | validated | none | PasswordChangeTests.cs:56-59 |
| POST /cash/tills | OpenTillRequest | partial | CurrencyCode null: unknown outcome; over 3 chars truncated | PilotSalesTests.cs:112-123 |
| POST /cash/tills/{id}/counts | RecordCashCountRequest | validated | none | none |
| POST /cash/tills/{id}/close | CloseTillRequest | validated | none | none |
| POST /catalog/products | RegisterProductRequest | validated | none | none |
| POST /catalog/items | RegisterItemRequest | partial | Barcode, SupplierSku over 128 truncated (bad data); CurrencyCode null 500; UnitCostMinor negative misleading 409 | none |
| POST /suppliers | CreateSupplierRequest | validated | none | DayZeroRoutesTests.cs:27-28 |
| POST /catalog/items/{id}/values | ItemValuesRequest | validated | none | none |
| POST /catalog/import/file | ImportFileRequest | validated | none | unit only, OwnerDecisionsRound4Tests.cs:41-42 |
| POST /catalog/import/preview | ImportCatalogRequest | partial | row Code, Sku, Name, Type, Size, Color over column width: expected 500; null row: expected 500 | HubCatalogTests.cs:41-43 (business row error only) |
| POST /catalog/import | ImportCatalogRequest | partial | same as preview | none |
| POST /sellers/{id}/rate | SellerRateRequest | validated | none | none |
| POST /credit-transfers | RequestCreditTransferRequest | validated | none | none |
| POST /credit-transfers/{id}/cancel | CancelCreditTransferRequest | validated | none | DayZeroRoutesTests.cs:97-98 |
| POST /customers | CreateCustomerRequest | validated | none | DayZeroRoutesTests.cs:51-52 |
| POST /exchange-rates | ExchangeRateRequest | validated | none | UsdAcceptanceTests.cs:68-70 (asserts only non-success) |
| POST /labels/jobs/{id}/attempts | AckPrintRequest | partial | PrinterResponse over 500 truncated (bad data); AttemptNo 0 or less misleading 409 | none |
| POST /stock/exceptions/{id}/review | ResolveExceptionRequest | validated | none | none |
| POST /receiving/sessions | OpenScanSessionRequest | partial | DeviceCode over 80 truncated (bad data) | none |
| POST /receiving/sessions/{id}/scans | RecordScanRequest | partial | DeviceCode over 80 truncated (bad data) | none |
| POST .../scans/{scanId}/resolve | ResolveScanRequest | validated | none | PilotEndpointsTests.cs:111-112 |
| POST .../scans/{scanId}/reject | RejectScanRequest | validated | none | LocalCatalogRejectTests.cs:101-102 |
| POST /receiving/sessions/{id}/quality | QualityRequest | validated | none | none |
| POST /sales/{id}/returns/credit | PostCreditReturnRequest | partial | null element in Lines: expected 500 | none |
| POST /sales/{id}/returns/outcome | PostReturnOutcomeRequest | partial | null element in Lines: expected 500; NewTenders TenderKind and Reference length: unknown | OwnerDecisionsRound4Tests.cs:88-89, UsdAcceptanceTests.cs:20-25 |
| POST /returns/policy | ReturnWindowRequest | validated | none | none |
| POST /sales | PostSaleRequest | partial | DiscountReason over 250 and StockExceptionNote over 500 truncated (bad data); null element in Lines or Tenders: expected 500; CurrencyCode null: unknown | SaleAccountingTests.cs:38-39, :48-49; UsdChangeTests.cs:31-32, :99; OwnerDecisionsRound4Tests.cs:68-72; OwnerPilotTests.cs:46 |
| POST /stock/web-consignments | WebConsignmentRequest | validated | none | none |
| POST /web-orders/{id}/manual-payment | ManualPaymentRequest | validated | none | none |
| POST /web-orders/{id}/mark-refunded | RefundReviewRequest | validated | none | WebOrderVerticalSlicePaymentReviewTests.cs:39-40 |
| POST /web-stock/release | WebReleaseRequest | validated | none | none |
| POST /inventory/tag-extract | multipart form | size and content checked | not applicable | TagExtractTests.cs:168-170 (non-image bytes only) |

## Empty body, `null` JSON and wrong JSON types

No custom JSON handling exists for staff routes.
A search of `src/` for `ConfigureHttpJsonOptions`, `RespectNullable`, `RespectRequired`, `ThrowOnBadRequest`, `UseExceptionHandler`, `AddProblemDetails`, `UseStatusCodePages` and `UnmappedMemberHandling` finds only `Api/Hosting.cs:86` (`UseHsts`) and `Api/PublicEndpoints.cs:24`, which applies to the public routes only.
The target framework is .NET 10 (`Directory.Build.props:3`).
Framework default, expected and not tested: a malformed body or a JSON value of the wrong type fails parameter binding, and minimal API answers 400 with an empty body.
Framework default, expected and not tested: an empty body or the literal `null` for the non-nullable `request` parameter answers 400.
Framework default, expected and not tested: a content type other than JSON answers 415.
These 400 answers do not carry the app's `ProblemResponse` code, because `UseSaviaErrors` catches only `SaviaException` (`Api/Endpoints.cs:62-84`, catch at :68).
Binding runs before endpoint filters, so `ActorFilter` (`Api/Endpoints.cs:13-24`) runs after the body is parsed; a malformed body is expected to get 400 before the 401 sign-in check.
Framework default, expected and not tested: a missing property is not an error; strings become null, `Guid` becomes `Guid.Empty`, numbers become 0 and arrays become null, and the service checks then run on those values.
Unknown properties are ignored on staff routes, because only the public routes set `UnmappedMemberHandling.Disallow` (`Api/PublicEndpoints.cs:24`).
A `null` element inside an array is accepted by the binder, because nullable annotations are not enforced; the services then dereference it (see Gap 7).
Any exception other than `SaviaException` is not caught by `UseSaviaErrors` and is expected to become a 500.
Tested: no.
The only tests that send hand-written or empty JSON are for login (`tests/HostingTests.cs:37`), sync (`tests/SyncTransportTests.cs:58`) and the public store (`tests/WebStorePublicTests.cs:118`, `:126`); all are outside SEC-05 scope.

## Shared mechanics

`Guard.Text` rejects null, whitespace and length over the maximum with 422 `input.text` (`App/Core.cs:57-62`).
`Errors.Invalid` raises a validation error that `UseSaviaErrors` maps to 422 (`Api/Endpoints.cs:72`).
`DbErrors.FromSql` (`Domain/Errors.cs:202-214`) maps SQL errors:
- numbers 50000-59999 that are not in the map become `rule.N`, 422 (:207);
- 2601 and 2627 become 409 `db.duplicate` (:211);
- 547, which includes CHECK constraint failures, becomes 409 `db.reference` with the message "references data that do not exist" (:212);
- 1205 and -2 become 503 (:213);
- every other number, including 515 (NULL into NOT NULL) and string truncation errors, becomes 500 `db.error` (:214).
`SqlGateway.Translate` prefers a business error in 50000-59999 over other errors in the same batch (`Infra/SqlGateway.cs:106-107`).
`SqlGateway.P` sends each value with an inferred type and no declared size (`Infra/SqlGateway.cs:16`).
Engine default, expected and not tested: a string longer than a procedure's declared `nvarchar(N)` or `varchar(N)` parameter is truncated silently to N characters, with no error.

## Per-route detail

### POST /auth/password
Route: `Api/AuthEndpoints.cs:19`, with `PasswordChangeOpen` and the login rate limit at :23.
Request: `Contracts/Auth.cs:8` `ChangePasswordRequest(string CurrentPassword, string NewPassword)`.
Checks before write: `App/Auth.cs:74-76` turns a null `NewPassword` into "" and requires 10-200 characters (422 `auth.weak_password`).
`App/Auth.cs:79` checks the account lock; :80 checks `CurrentPassword` (null becomes ""); :86-87 rejects an unchanged password; :88 writes.
Store: `Infra/AuthStore.cs:87-89` calls `security.usp_ChangeOwnPassword` with a hash, so the raw length never reaches SQL.
Verdict: validated.
Tests: `tests/PasswordChangeTests.cs:52` `A_wrong_current_password_is_refused_and_counts_toward_the_lockout` asserts 422 `auth.weak_password` at :56-57 and 422 `auth.password_unchanged` at :59.

### POST /cash/tills
Route: `Api/CashEndpoints.cs:16`.
Request: `Contracts/Cash.cs:3` `OpenTillRequest(Guid TillId, Guid RegisterId, string CurrencyCode, long OpeningMinor, CashCountLine[]? Lines, CashCountLine[]? UsdLines)`; `CashCountLine(long DenominationMinor, int Quantity)` at `Contracts/Cash.cs:5`.
Checks before write: `App/Cash.cs:27` branch, :28 role, :29-30 the register belongs to the branch (404), :31 writes.
No C# check of `CurrencyCode`, `OpeningMinor` or `Lines`.
Store: `Infra/CashStore.cs:10-14` serializes `Lines` to JSON; a null array becomes the JSON text `null`.
Procedure `usp_OpenTillCounted` V036:534 declares `@CurrencyCode varchar(3)` and `@LinesJson nvarchar(max)`.
V036:542 rejects invalid JSON with 51545, mapped to 422 `cash.opening_breakdown`.
V036:546-550 rejects empty lines, `Quantity` outside 0-1000000, an unknown NIO denomination, duplicate denominations, an `OpeningMinor` that differs from the sum, and `@CurrencyCode<>'NIO'`.
Unchecked: a null `CurrencyCode` makes `@CurrencyCode<>'NIO'` unknown, so it passes that test; the outcome after V036:563 and :567-568 was not read, so it is unknown.
Unchecked: a `CurrencyCode` such as `NIOX` is expected to be truncated to `NIO` by the varchar(3) parameter and accepted.
`UsdLines`: V036:541 replaces null with one zero line, and V036:563 passes it to `usp_RecordDrawerCount`, which checks it at V027:303-310 (422).
Verdict: partial (null currency outcome unknown; overlong currency accepted after truncation).
Tests: `tests/PilotSalesTests.cs:112` `Opening_amount_must_equal_denominations` asserts 422 at :122; `tests/VerticalSliceTests.cs:161` asserts 404 for a register in another branch.

### POST /cash/tills/{tillId}/counts
Route: `Api/CashEndpoints.cs:21`.
Request: `Contracts/Cash.cs:6` `RecordCashCountRequest(Guid CashCountId, CashCountLine[] Lines, Guid? UsdCashCountId, CashCountLine[]? UsdLines)`.
Checks before write: `App/Cash.cs:36` role, :37 the till is on this node, :38 `Lines` not empty (422 `cash.count_empty`), :39 writes.
Store: `Infra/CashStore.cs:16-19` calls `usp_RecordCashCount` with lines as JSON.
`usp_RecordDrawerCount` V027:303 rejects invalid JSON (51540, 422); V027:308-310 rejects null values, denomination 0 or less, `Quantity` below 0 or above 1000000, and an unknown denomination (51541, 422).
`usp_RecordCashCount` V027:344 checks the parent till; V027:349 requires USD completeness (52106, 422).
Verdict: validated.
Tests: none.

### POST /cash/tills/{tillId}/close
Route: `Api/CashEndpoints.cs:27`.
Request: `Contracts/Cash.cs:8` `CloseTillRequest(Guid ClosureId, Guid CashCountId, Guid? UsdCashCountId)`.
Checks before write: `App/Cash.cs:44` role, :45 till here, :46 writes.
Procedure `usp_CloseTill` V027:509 checks the till and the counts at V027:521-522 and :526.
Verdict: validated (ids only; each is checked against existing rows).
Tests: none.

### POST /catalog/products
Route: `Api/CatalogEndpoints.cs:22`, mapped only on Cloud, LocalCatalog or CatalogManagedByHub nodes (:20).
Request: `Contracts/Catalog.cs:12` `RegisterProductRequest(Guid ProductId, string Name)`.
Checks before write: `App/Catalog.cs:99` catalog writer, :100 `Name` 1-200 (422), :101 writes.
Procedure `usp_RegisterProduct` V001:2193 declares `@Name nvarchar(200)` and rejects an empty name at V001:2199.
Verdict: validated.
Tests: none.

### POST /catalog/items
Route: `Api/CatalogEndpoints.cs:27`, same node condition (:20).
Request: `Contracts/Catalog.cs:13` `RegisterItemRequest(Guid ItemId, Guid ProductId, string Sku, string VariantName, string CurrencyCode, long UnitPriceMinor, long? UnitCostMinor, string? Barcode, Guid? SizeId, Guid? ColorId, Guid? SupplierId, string? SupplierSku)`.
Checks before write: `App/Catalog.cs:106` catalog writer, :107 owner only, :108 `Sku` 1-100, :109 `VariantName` 1-200, :110 writes.
No C# check of `CurrencyCode`, `UnitCostMinor`, `Barcode` or `SupplierSku`.
Store: `Infra/CatalogStore.cs:28-34` calls `usp_RegisterItem`.
Procedure V005:153-159 declares `@CurrencyCode varchar(3)`, `@Barcode nvarchar(128)` and `@SupplierSku nvarchar(128)`.
V005:163-164 requires a barcode or a supplier SKU; V005:165-166 requires a supplier with a supplier SKU; V005:167 rejects a negative price (51203, 422).
Table `catalog.Items` V001:341: `CurrencyCode varchar(3) NOT NULL` (V001:348), `FK_Items_Currency` (V001:364), `CK_Items_Price` price 0-9e12 and cost null or 0-9e12 (V001:367).
Unchecked, bad data: `Barcode` or `SupplierSku` over 128 characters is expected to be truncated silently by the parameter and saved.
Unchecked, 500: a null `CurrencyCode` is expected to violate NOT NULL (515), mapped to 500 (`Domain/Errors.cs:214`).
Unchecked, misleading 409: a negative `UnitCostMinor` or a price above 9e12 violates `CK_Items_Price` (547) and returns 409 "references data that do not exist" (`Domain/Errors.cs:212`).
Unchecked: an unknown `CurrencyCode` returns 409 `db.reference` through the foreign key, which is acceptable.
Verdict: partial.
Tests: none for invalid fields; `tests/LocalCatalogRejectTests.cs:70` tests a duplicate code only, and :53 tests an unmapped route (404).

### POST /suppliers
Route: `Api/CatalogEndpoints.cs:32`, same node condition (:20).
Request: `Contracts/Receiving.cs:20` `CreateSupplierRequest(Guid SupplierId, string Name)`.
Checks before write: `App/Catalog.cs:92` catalog writer, :93 `Name` 1-200, :94 writes.
Procedure `sourcing.usp_CreateSupplier` V062:84 declares `@DisplayName nvarchar(200)` and rejects an empty name at V062:90 (51903, 422).
Verdict: validated.
Tests: `tests/DayZeroRoutesTests.cs:18` `Hub_creates_a_supplier_once_and_a_store_with_a_hub_refuses_by_name` asserts 422 `input.text` for a blank name at :27-28.

### POST /catalog/items/{itemId}/values
Route: `Api/CatalogEndpoints.cs:45`.
Request: `Contracts/Catalog.cs:16` `ItemValuesRequest(Guid ChangeId, long PriceMinor, long CostMinor, string Reason)`.
Checks before write: `App/Catalog.cs:119` refuses on a hub store, :120 branch, :121 owner only, :122 `Reason` 1-250, :123 writes.
Procedure `usp_SetItemValues` V019:9 declares `@Reason nvarchar(250)`; V019:15 rejects a null or negative price or cost and an empty reason (51206, 422); V019:19 rejects an inactive item.
V019 updates `catalog.Items` (V019:27), so a value above 9e12 is expected to violate `CK_Items_Price` (V001:367) and return the misleading 409 in Gap 11.
Verdict: validated (the upper bound fails with a wrong status, not with bad data).
Tests: none for invalid values.

### POST /catalog/import/file
Route: `Api/CatalogEndpoints.cs:54`; it parses only and does not write to the database.
Request: `Contracts/Catalog.cs:17` `ImportFileRequest(string FileName, string ContentBase64)`.
Checks: `App/Catalog.cs:130` `FileName` 1-200; :132-133 invalid base64 gives 422 `import.format`; null content becomes "".
`App/CatalogFile.cs:23` requires 1 byte to 5 MB (`MaxBytes` at :17); :85 caps each sheet part; :28, :31 and :32 check format, emptiness and rows; `MaxRows` is 5000 (:18).
Verdict: validated.
Tests: `tests/OwnerDecisionsRound4Tests.cs:26` `Parser_reads_the_csv_with_spanish_headers_and_the_xlsx_with_another_column_order` asserts `import.format` at :41-42 by calling `CatalogFile.Parse` directly, not through HTTP.

### POST /catalog/import/preview and POST /catalog/import
Routes: `Api/CatalogEndpoints.cs:56` and :58.
Request: `Contracts/Catalog.cs:21` `ImportCatalogRequest(Guid BatchId, string FileName, ImportRow[] Rows)`; `ImportRow(int Row, string? Code, string? Sku, string? Name, string? Type, string? Size, string? Color, string? Cost, string? Price, string? Stock)` at `Contracts/Catalog.cs:19`.
Checks before write: `App/Catalog.cs:139` refuses on a hub store, :140 owner only, :141 `FileName` 1-200, :142-143 `Rows` 1-5000 (422 `import.size`).
No C# check of row fields.
Store: `Infra/CatalogStore.cs:55` serializes `Rows` to JSON.
Procedure `usp_ImportCatalog` V061:101 rejects an empty file name or invalid JSON (52030, 422); V061:110 checks 1-5000 rows.
V061:108-109 reads each row field as `nvarchar(400)`, but V061:102-104 stores them in `#r` columns of `Code nvarchar(128)`, `Sku nvarchar(100)`, `Name nvarchar(200)`, `TypeName nvarchar(120)`, `SizeName nvarchar(70)` and `ColorName nvarchar(70)`.
The row checks `LEN(Code)>128` (V061:126), `LEN(Sku)>100` (:129), `LEN(Name)>200` (:130) and type over 120 (:137) can therefore never fire.
Engine default, expected and not tested: a longer value fails the INSERT at V061:105 with a truncation error, which maps to 500 (`Domain/Errors.cs:214`).
The size and color check at V061:137 (over 30) does fire for values of 31-70 characters; a value over 70 is expected to give the same 500.
Expected and not tested: a null element in `Rows` serializes as JSON `null`, gives a null `RowNumber`, and violates `RowNumber int NOT NULL` (V061:102), so 500.
Expected and not tested: two rows with the same `Row` number violate the `#r` primary key (V061:102), so 409 `db.duplicate`.
Price, cost, stock and duplicate checks run per row at V061:131-136 and are reported as row errors.
Verdict: partial for both routes.
Tests: `tests/HubCatalogTests.cs:30` `Hub_imports_catalog_without_stock_and_reads_prices_without_a_branch` asserts one row error for stock at the hub at :41-43; no test sends an invalid row field.

### POST /sellers/{sellerId}/rate
Route: `Api/CommissionsEndpoints.cs:19`.
Request: `Contracts/Commissions.cs:3` `SellerRateRequest(Guid ChangeId, int RateBps, string Reason)`.
Checks before write: `App/Commissions.cs:34` `Reason` 1-250.
Procedure `usp_SetSellerRate` V018:7 declares `@Reason nvarchar(250)`; V018:13 requires `RateBps` 0-10000 (52003, 422); V018:15 checks the seller.
Verdict: validated.
Tests: none.

### POST /credit-transfers
Route: `Api/CreditTransferEndpoints.cs:17`, branch nodes only.
Request: `Contracts/Customers.cs:7` `RequestCreditTransferRequest(Guid TransferId, Guid CreditId, Guid FromBranchId, Guid ToBranchId, long AmountMinor, string Reason)`.
Checks before write: `App/Customers.cs:54` `Reason` 1-400.
Store: `Infra/CustomersStore.cs:27-30`.
Procedure `usp_TransferRequest` V010:8-11 declares `@Reason nvarchar(400)`.
V010:15-17 rejects null ids, the same source and target branch, `AmountMinor` 0 or less and an empty reason (51720, 422).
V010:32-33 requires the node to belong to one of the two branches; V010:37-39 requires an active credit with a balance in the source branch (51722).
Verdict: validated.
Tests: none for an invalid body; `tests/DayZeroRoutesTests.cs:73` sends a valid request.

### POST /credit-transfers/{id}/cancel
Route: `Api/CreditTransferEndpoints.cs:29`.
Request: `Contracts/Customers.cs:9` `CancelCreditTransferRequest(string Reason)`.
Checks before write: `App/Customers.cs:64` `Reason` 1-400.
Procedure `usp_TransferCancel` V009:260 checks the reason at V009:265.
Verdict: validated.
Tests: `tests/DayZeroRoutesTests.cs:61` `A_credit_moves_between_stores_over_http_and_each_step_runs_on_the_node_that_owns_it` asserts 422 `input.text` for a blank reason at :97-98.

### POST /customers
Route: `Api/CustomersEndpoints.cs:12`.
Request: `Contracts/Customers.cs:4` `CreateCustomerRequest(Guid CustomerId, string DisplayName, string? DocumentNumber, string? Phone, string? Email)`.
Checks before write: `App/Customers.cs:32` `DisplayName` 1-200; :33 `DocumentNumber` up to 40, :34 `Phone` up to 40 and :35 `Email` up to 254, each optional through :70-73.
Procedure `usp_CreateCustomer` V053:82 declares matching sizes; V053:91 rejects a document over 32 characters (51902, 422).
Verdict: validated.
Tests: `tests/DayZeroRoutesTests.cs:40` `A_cashier_creates_a_customer_once_and_finds_it` asserts 422 `input.text` for an empty name at :51-52.

### POST /exchange-rates
Route: `Api/ExchangeRateEndpoints.cs:12`, mapped under `/api/v1` and `/api` (`Api/Endpoints.cs:112-113`).
Request: `Contracts/ExchangeRates.cs:4` `ExchangeRateRequest(Guid Id, DateOnly EffectiveFrom, decimal Rate, string Reason)`.
Checks before write: `App/ExchangeRates.cs:23` `Reason` 1-250; :24-25 `Id` not empty and `Rate` 1-1000 with at most 4 decimals (422 `rate.invalid`).
Procedure `usp_SetExchangeRate` V027:45 declares `@Rate decimal(9,4)`; V027:53-55 checks the date, rate and reason (52101, 422).
Verdict: validated.
Tests: `tests/UsdAcceptanceTests.cs:58` `Spec14_rate_permissions_dates_and_future_rate` sends a new id for an effective date already used at :68 and a past date at :69-70, but asserts only `IsSuccessStatusCode == false`.

### POST /labels/jobs/{jobId}/attempts
Route: `Api/InventoryEndpoints.cs:18`.
Request: `Contracts/Inventory.cs:6` `AckPrintRequest(Guid AttemptId, int AttemptNo, bool Successful, string? PrinterResponse)`.
Checks before write: none on the body; `App/Inventory.cs:30-31` calls only `Guard.Branch` and then the store.
Store: `Infra/InventoryStore.cs:46-52` checks that the job is in the branch at :50.
Procedure `usp_AcknowledgePrint` V001:2442-2444 declares `@AttemptNo int` and `@PrinterResponse nvarchar(500)`; V001:2452 and :2455 check the job status; V001:2453-2454 return early for an existing attempt id.
Unchecked, bad data: `PrinterResponse` over 500 characters is expected to be truncated silently by the parameter and saved.
Unchecked, misleading 409: `AttemptNo` of 0 or less violates `CK_PrintAttempts_No` (V001:1434) and returns 409 `db.reference`.
Verdict: partial.
Tests: none.

### POST /stock/exceptions/{exceptionId}/review
Route: `Api/InventoryEndpoints.cs:26`, branch nodes only.
Request: `Contracts/Inventory.cs:7` `ResolveExceptionRequest(string Reason)`.
Checks before write: `App/Inventory.cs:36` approver role and `Reason` 1-500.
Procedure `usp_ReviewStockException` V016:16 declares `@Reason nvarchar(500)` and checks it at V016:25.
Verdict: validated.
Tests: none.

### POST /receiving/sessions
Route: `Api/ReceivingEndpoints.cs:10`.
Request: `Contracts/Receiving.cs:3` `OpenScanSessionRequest(Guid ContainerId, Guid ScanSessionId, string Reference, Guid SupplierId, string? DeviceCode)`.
Checks before write: `App/Receiving.cs:29` branch, :30 role, :31 `Reference` 1-100, :32 writes.
Procedure `usp_OpenScanSession` V002:33-36 declares `@Reference nvarchar(100)` and `@DeviceCode nvarchar(80)`; checks at V002:40, :50, :52 and :58.
Unchecked, bad data: `DeviceCode` over 80 characters is expected to be truncated silently and saved.
Verdict: partial.
Tests: none for an invalid body.

### POST /receiving/sessions/{sessionId}/scans
Route: `Api/ReceivingEndpoints.cs:15`.
Request: `Contracts/Receiving.cs:4` `RecordScanRequest(Guid ScanId, string RawCode, int Quantity = 1, string? DeviceCode)`.
Checks before write: `App/Receiving.cs:38` branch, :39 role, :40 `RawCode` 1-128, :41 session here, :42 writes.
Procedure `usp_RecordScan` V021:3-5 declares `@RawCode nvarchar(128)` and `@DeviceCode nvarchar(80)`; V021:10 requires `Quantity` 1-10000 (51301, 422).
Unchecked, bad data: `DeviceCode` over 80 characters is expected to be truncated silently and saved.
Verdict: partial.
Tests: none for an invalid body.

### POST /receiving/sessions/{sessionId}/scans/{scanId}/resolve
Route: `Api/ReceivingEndpoints.cs:23`.
Request: `Contracts/Receiving.cs:17` `ResolveScanRequest(Guid ItemId, string Reason)`.
Checks before write: `App/Receiving.cs:93` `Reason` 1-250; :95-96 the scan is in the session.
Procedure `usp_ResolveScan` V005:58 checks the reason at V005:63 and the item code at V005:80.
Verdict: validated.
Tests: `tests/PilotEndpointsTests.cs:79` `Sessions_list_lines_and_a_reviewer_resolves_an_unknown_code` asserts 422 `input.text` for a blank reason at :111-112.

### POST /receiving/sessions/{sessionId}/scans/{scanId}/reject
Route: `Api/ReceivingEndpoints.cs:29`.
Request: `Contracts/Receiving.cs:18` `RejectScanRequest(string Reason)`.
Checks before write: `App/Receiving.cs:111` `Reason` 1-250.
Procedure `usp_RejectScan` V012:7 checks it at V012:13.
Verdict: validated.
Tests: `tests/LocalCatalogRejectTests.cs:91` `Reject_endpoint_authorizes_scopes_audits_and_posts_only_matched_units` asserts 422 `input.text` for a blank reason at :101 and a 251-character reason at :102.

### POST /receiving/sessions/{sessionId}/quality
Route: `Api/ReceivingEndpoints.cs:48`.
Request: `Contracts/Receiving.cs:21` `QualityRequest(Guid CheckId, Guid ItemId, int Buena, int Danada, int Manchada, int MalOlor, int Faltante, string Reason)`.
Checks before write: `App/Receiving.cs:121` `Reason` 1-250.
Procedure `usp_RecordQuality` V020:17 rejects null or negative counts and an empty reason (52006, 422); V020:31 requires the sum to equal the expected units.
Verdict: validated.
Tests: none for an invalid body; `tests/OwnerPilotTests.cs:63` sends a valid one.

### POST /sales/{saleId}/returns/credit
Route: `Api/ReturnsEndpoints.cs:10`.
Request: `Contracts/Returns.cs:4` `PostCreditReturnRequest(Guid ReversalId, Guid CreditId, Guid TillId, Guid CustomerId, string Reason, ReturnLine[] Lines)`; `ReturnLine(Guid SaleLineId, int Quantity, string RestockPool)` at `Contracts/Returns.cs:3`.
Checks before write: `App/Returns.cs:21-22` roles, :23 `Reason` 1-500, :24-25 `Lines` not empty and no duplicate line ids, :26 each `RestockPool` 1-12.
Procedure `usp_PostCreditReturn` V029:165; V029:176 rejects empty lines or reason; V029:225 rejects `Quantity` 0 or less and an invalid pool (51531, 422); V029:223 checks the customer.
Unchecked, 500: a `null` element in `Lines` is expected to throw a NullReferenceException at `App/Returns.cs:24` (`l.SaleLineId`), which `UseSaviaErrors` does not catch.
Verdict: partial.
Tests: none for an invalid body.

### POST /sales/{saleId}/returns/outcome
Route: `Api/ReturnsEndpoints.cs:13`.
Request: `Contracts/Returns.cs:6` `PostReturnOutcomeRequest(Guid ReversalId, string Outcome, Guid TillId, string Reason, ReturnLine[] Lines, string? Reference, Guid? ExchangeSaleId, SaleLine[]? NewLines, SaleTender[]? NewTenders, string? DifferenceKind, string? DifferenceReference)`.
Checks before write: `App/Returns.cs:37` `Reason` 1-500; :38-39 `Outcome` in the allowed set; :40-41 `Lines`; :42 `RestockPool` 1-12; :43-44 `Reference` and `DifferenceReference` up to 120; :45 at most 50 new lines and 10 new tenders; :46-47 no dollar fields.
Procedure `usp_PostReturnOutcome` V029:10-15 declares `@Outcome varchar(16)`, `@Reference nvarchar(120)`, `@DifferenceKind varchar(16)` and `@DifferenceReference nvarchar(120)`.
V029:21 checks the outcome, :22 lines and reason, :23 the transfer reference, :24 and :26 exchange lines, :27 the `DifferenceKind` values, :28 the difference reference, :119-120 that new items exist, :123 the tender sum.
V029:136-137 passes `@NewLines` and the tenders to `usp_PostSale`, whose line and tender checks run at V036:272-285.
Unchecked, 500: a `null` element in `Lines` is expected to throw at `App/Returns.cs:40`.
Unknown: `NewTenders` `TenderKind` over 20 or `Reference` over 120 characters go into the `SaleTenderRequest` table type (V001:2551) without a C# check; what SqlClient does with an overlong table-valued value was not tested, so the outcome is unknown.
A `DifferenceKind` over 16 characters is expected to be truncated, but V029:27 then checks the allowed values, so bad data is unlikely.
Verdict: partial.
Tests: `tests/OwnerDecisionsRound4Tests.cs:46` asserts 422 for a transfer without a reference at :88-89; `tests/UsdAcceptanceTests.cs:12` `Spec11_exchange_rejects_fx_and_cash_refund_uses_parent` asserts 422 for dollar tenders at :24-25.

### POST /returns/policy
Route: `Api/ReturnsEndpoints.cs:18`.
Request: `Contracts/Returns.cs:9` `ReturnWindowRequest(Guid ChangeId, int WindowDays, string Reason)`.
Checks before write: `App/Returns.cs:58` owner role, :59 `Reason` 1-250.
Store: `Infra/ReturnsStore.cs:53-55` calls `usp_SetReturnWindow`.
Procedure V024:44 declares `@Reason nvarchar(250)`; V024:51 requires `WindowDays` 1-365 and a reason (52003, 422).
Verdict: validated.
Tests: none for an invalid body; `tests/OwnerDecisionsRound4Tests.cs:107-109` tests the role only.

### POST /sales
Route: `Api/SalesEndpoints.cs:11`; it also reads the `X-Savia-Approval` header at :13-16.
Request: `Contracts/Sales.cs:8` `PostSaleRequest(Guid SaleId, Guid TillId, string CurrencyCode, SaleLine[] Lines, SaleTender[] Tenders, Guid? CustomerId, string? DiscountReason, string? StockExceptionNote)`.
`SaleLine(int LineNumber, Guid ItemId, int Quantity, long UnitPriceMinor, long DiscountMinor = 0, Guid? SellerId)` at `Contracts/Sales.cs:3`.
`SaleTender(int TenderNumber, string TenderKind, long AmountMinor, long? ReceivedMinor, long? ChangeMinor, string? Reference, Guid? CreditId, string? ForeignCurrencyCode, long? ForeignReceivedMinor, Guid? ExchangeRateId, decimal? ExchangeRate, long? RoundingMinor, long? ForeignChangeMinor)` at `Contracts/Sales.cs:4-7`.
Checks before write: `App/Sales.cs:22-23` branch and role; :24-25 `Lines` not empty and `Tenders` not null (422 `sale.empty`); :26-28 no duplicate line or tender numbers; :31 dollar tender checks (`App/ForeignCash.cs:11`); :32 `TenderKind` 1-20; :33-34 tender `Reference` up to 120; :36-37 at most one dollar tender; :38-42 approver role and branch; :43 writes.
No C# check of `CurrencyCode`, `DiscountReason` or `StockExceptionNote`.
Store: `Infra/SalesStore.cs:11-40` sends lines and tenders as table-valued parameters.
Procedure `usp_PostSale` V036:242-248 declares `@CurrencyCode varchar(3)`, `@DiscountReason nvarchar(250)` and `@StockExceptionNote nvarchar(500)`.
V036:272 rejects no lines; V036:273-276 require `Quantity` 1-1000000, price 0 or more, discount 0 or more and not above the line total (51508, 422).
V036:277-285 require a known tender kind, an amount above 0 and the cash and transfer rules (51509, 422).
V036:362-365 check the item currency and price against the request (51513, 409); V036:389 and :391 check the total and the tender sum; V036:354 checks the discount reason.
V036:419-423 store `StockExceptionNote` in `sales.StockExceptions.Note`; `sales.Sales.DiscountReason` is `nvarchar(250)` (V015:10).
Unchecked, bad data: `DiscountReason` over 250 and `StockExceptionNote` over 500 characters are expected to be truncated silently and saved.
Unchecked, 500: a `null` element in `Lines` or `Tenders` is expected to throw at `App/Sales.cs:26-27`.
Unknown: a null `CurrencyCode`; this audit did not confirm whether the currency comparison at V036:362-365 rejects null, because SQL compares null as unknown.
Verdict: partial.
Tests: `tests/SaleAccountingTests.cs:12` `All_tenders_customer_credit_search_redemption_and_day_accounting_are_real_sql` asserts 422 `rule.51509` for a transfer without a reference at :38-39 and 422 `input.text` for a 121-character reference at :48-49.
`tests/UsdChangeTests.cs:15` `Spec1e_historical_http_replay_and_hash_zero_negative_nonzero` asserts 422 for a negative dollar change at :31-32; `tests/UsdChangeTests.cs:89` `Spec1c_reject_change_without_usd_and_wrong_client_change` asserts 422 at :99.
`tests/OwnerDecisionsRound4Tests.cs:68-72` and `tests/OwnerPilotTests.cs:46` assert 422 for seller rules.

### POST /stock/web-consignments
Route: `Api/WebStoreEndpoints.cs:14`, branch nodes only.
Request: `Contracts/WebStore.cs:38` `WebConsignmentRequest(Guid ConsignmentId, Guid ItemId, int Qty, Guid FromLocationId)`.
Checks before write: `App/WebStore.cs:206` `Qty` 1-1000.
Procedure `usp_ConsignToWeb` V048:67 checks at V048:79 (51742, 422).
Verdict: validated.
Tests: none.

### POST /web-orders/{id}/manual-payment
Route: `Api/WebStoreEndpoints.cs:25`.
Request: `Contracts/WebStore.cs:35` `ManualPaymentRequest(long AmountMinor, string Currency, string Reference)`.
Checks before write: `App/WebStore.cs:156` `AmountMinor` above 0; :157 `Currency` exactly 3 characters; :158 `Reference` 1-160.
Procedure `usp_RecordVerifiedPayment` V050:79 declares `@ExternalPaymentId nvarchar(160)` and `@CurrencyCode varchar(3)`.
Verdict: validated.
Tests: none for an invalid body; `tests/WebOrderVerticalSliceTests.cs:154` sends a valid one.

### POST /web-orders/{id}/mark-refunded
Route: `Api/WebStoreEndpoints.cs:41`.
Request: `Contracts/WebStore.cs:52` `RefundReviewRequest(string Reference)`.
Checks before write: `App/WebStore.cs:168` `Reference` 1-160.
Procedure `usp_RefundPaymentReview` V057:140 declares `@RefundReference nvarchar(160)` and checks at V057:146.
Verdict: validated.
Tests: `tests/WebOrderVerticalSlicePaymentReviewTests.cs:17` `Webhook_for_another_amount_goes_to_review_and_a_manager_marks_it_refunded` asserts 422 `web.validation` for a blank reference at :39-40.

### POST /web-stock/release
Route: `Api/WebStoreEndpoints.cs:52`.
Request: `Contracts/WebStore.cs:41` `WebReleaseRequest(Guid ReleaseId, Guid ItemId, Guid ToLocationId, int Qty, string Reason)`.
Checks before write: `App/WebStore.cs:197` `Qty` 1-1000; :198 `Reason` 1-300.
Procedure `usp_ReleaseFromWeb` V048:130 declares `@Reason nvarchar(300)` and checks at V048:140.
Verdict: validated.
Tests: none.

### POST /inventory/tag-extract (size cap and content checks only)
Route: `Api/TagsEndpoints.cs:16`; it reads a multipart form, not a JSON record.
`Api/TagsEndpoints.cs:19-20` rejects a non-form content type with `tag.image_missing`; :22 rejects a missing `image` file; :23-24 rejects a file over `MaxImageBytes`.
`App/Tags.cs:32` sets `MaxImageBytes` to 6 MB; :42 rejects an empty image; :43-44 checks the size again; :45-46 checks the magic bytes for JPEG, PNG or WebP; :49 validates the barcode hint.
`Api/TagsEndpoints.cs:21` calls `ReadFormAsync` before the size check, so the whole form is buffered first; only the framework default request limit applies to that step.
There is no database write.
Tests: `tests/TagExtractTests.cs:161` `Endpoint_rejects_other_roles_missing_sign_in_and_non_images` asserts 422 `tag.image_type` for text bytes at :168-170; no test sends an oversize or missing image.

## Out of scope, recorded

`App/Inventory.cs:30-31` has no role check for print acknowledgements; any signed-in staff member of the branch can post one.
This is authorization, not input validation.

## Gaps

1. Bad data saved: `/sales` saves `DiscountReason` over 250 and `StockExceptionNote` over 500 characters truncated (expected engine default; `App/Sales.cs:20-46` has no check; parameters at V036:248).
   Smallest fix: in `PostSaleAsync`, reject `DiscountReason?.Length > 250` and `StockExceptionNote?.Length > 500` with 422, and add one test per field.
2. Bad data saved: `/catalog/items` saves `Barcode` or `SupplierSku` over 128 characters truncated, so a wrong barcode can be registered (`App/Catalog.cs:104-111`; V005:157-158).
   Smallest fix: add optional length checks for both fields (128) in `RegisterItemAsync`, and a test.
3. Bad data saved: `/labels/jobs/{id}/attempts` saves `PrinterResponse` over 500 characters truncated (`App/Inventory.cs:30-31`; V001:2444).
   Smallest fix: reject `PrinterResponse?.Length > 500` and `AttemptNo < 1` with 422 in `AcknowledgePrintAsync`.
4. Bad data saved: `/receiving/sessions` and `/scans` save `DeviceCode` over 80 characters truncated (`App/Receiving.cs:31`, `:40`; V002:36; V021:5).
   Smallest fix: add an optional 80-character check for `DeviceCode` in both methods.
5. Bad data saved, low impact: `CurrencyCode` over 3 characters is truncated to 3 on `/cash/tills` (V036:534 parameter), `/sales` (V036:244) and `/catalog/items` (V005:155), so `NIOX` is accepted as `NIO`.
   Smallest fix: require exactly 3 characters in C#, as `App/WebStore.cs:157` already does for manual payments.
6. Bad data saved, cross-cutting: no route except `/exchange-rates` rejects `Guid.Empty` as a new entity id (only check found by searching `src/` and `db/` for `Guid.Empty` and the all-zero id: `App/ExchangeRates.cs:24`), so a missing id field is expected, not tested, to save a row with the all-zero id.
   Smallest fix: one `Guard.Id` helper that rejects `Guid.Empty`, called for each client-chosen id.
7. 500: a `null` element in an array throws a NullReferenceException that `UseSaviaErrors` does not catch, on `/sales` (`App/Sales.cs:26-27`), `/returns/credit` (`App/Returns.cs:24`) and `/returns/outcome` (`App/Returns.cs:40`).
   Smallest fix: reject any null element with 422 before the LINQ checks, and add one test that sends `"lines":[null]`.
8. 500: `/catalog/import` and `/catalog/import/preview` are expected to fail with a truncation error for a row `Code`, `Sku`, `Name`, type, size or color longer than its `#r` column, because V061:102-104 is narrower than the `nvarchar(400)` read at V061:108; the row checks at V061:126-130 never fire.
   A null row element is expected to violate `RowNumber NOT NULL` (V061:102), also 500.
   Smallest fix: widen the `#r` text columns to `nvarchar(400)` so the existing row checks report the error, and reject null rows in `ImportCatalogAsync` (`App/Catalog.cs:142`).
9. 500: `/catalog/items` with a null `CurrencyCode` is expected to violate `CurrencyCode NOT NULL` (V001:348), which maps to 500 (`Domain/Errors.cs:214`); the same null on `/cash/tills` and `/sales` has an unknown outcome.
   Smallest fix: the exact-3-character check from Gap 5 also rejects null.
10. Unknown: `/returns/outcome` does not check `NewTenders` `TenderKind` (20) or `Reference` (120) in C#, although `/sales` does (`App/Sales.cs:32-34`).
    Smallest fix: run the same tender loop over `NewTenders` in `ReturnOutcomeAsync`.
11. Misleading 409: a CHECK constraint failure returns 409 "references data that do not exist" (`Domain/Errors.cs:212`), for example a negative item cost (V001:367), an item price or cost above 9e12 on `/catalog/items/{id}/values` (V019:27, V001:367), or `AttemptNo` 0 (V001:1434).
    Smallest fix: map 547 messages that contain `CHECK constraint` to 422, or add the C# checks in Gaps 2 and 3.
12. Missing test: no staff test sends an empty body, `null`, malformed JSON or a wrong JSON type, so the expected 400 behavior is unproven, and that 400 carries no `ProblemResponse` code.
    Smallest fix: one parameterized test over a few staff routes that asserts 400 for each case.
13. Missing test: no invalid-body test exists for `/cash/tills/{id}/counts`, `/close`, `/catalog/products`, `/catalog/items` fields, `/catalog/items/{id}/values`, `/sellers/{id}/rate`, `/credit-transfers`, `/labels/jobs/{id}/attempts`, `/stock/exceptions/{id}/review`, `/receiving/sessions`, `/scans`, `/quality`, `/returns/credit`, `/returns/policy`, `/stock/web-consignments`, `/manual-payment` and `/web-stock/release`.
    `/catalog/import/file` is tested only through `CatalogFile.Parse` (`tests/OwnerDecisionsRound4Tests.cs:41-42`), and `/inventory/tag-extract` has no oversize or missing-file test.
    Smallest fix: one 422 test per route for its main field, starting with the routes in Gaps 1-4.
14. Weak test: `tests/UsdAcceptanceTests.cs:68-70` asserts only that the request failed, not that it returned 422 `rate.invalid` or the proc rule.
    Smallest fix: assert the status and code with `HttpAssert.ProblemAsync`.

## Result after the fixes, 2026-11-27

Each gap was first written as a failing test in `savia/tests/Savia.Tests/StaffInputValidationTests.cs`, then fixed.
Gaps 1-12 reproduced (fully or partly) and now pass; gap 13 is partly covered and gap 14 is open.
Fixes: `Guard.MaxLength`, `Guard.Id` and `Guard.Currency` in `savia/src/Savia.Application/Core.cs`, called from the services; null array elements refused in `Sales.cs`, `Returns.cs` and `Catalog.cs`; migration `V065__staff_input_import_widths.sql`; a CHECK failure maps to 422 `db.check` in `savia/src/Savia.Domain/Errors.cs`; an unreadable staff body returns 400 `input.body` in `savia/src/Savia.Api/Endpoints.cs`.
Local run: the new tests plus `DbErrorsTests`, `PilotSalesTests` and `OwnerDecisionsRound4Tests` passed 27 of 27; the full suite and CI results are in the commit record.

Follow-up, 2026-11-27: `Remaining_client_ids_refuse_the_empty_id` sends an empty id to the 9 routes the first tests did not reach.
With the 9 `Guard.Id` calls removed it failed on every case: 4 routes answered 204 and saved a row with the empty id (supplier, cash count, item values, return window), and 5 answered a later store error (409 or 404).
With the guards in place it passes. The SEC-05 deploy to the hub is recorded in `savia/docs/deploy/AZURE.md` (revision `ca-savia-api--ge3309b1-1`).
