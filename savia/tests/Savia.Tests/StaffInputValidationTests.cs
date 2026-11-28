using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Tests;

/// <summary>
/// SEC-05: every staff route validates its body before save. Each case is otherwise valid, so only the field under test can
/// refuse it, and each refusal is checked in the database as well: no row, or no truncated row. Cases are collected and
/// reported together, so one run shows every route that answers wrong.
/// Audit: docs/public-software/evidence/sec05-staff-input-audit.md, Gaps 1-12.
/// </summary>
public sealed class StaffInputValidationTests : IAsyncLifetime
{
    private const HttpStatusCode Invalid = HttpStatusCode.UnprocessableEntity;
    private string _db = "";
    private SaviaNode _branch = null!;
    private HttpClient _cashier = null!, _supervisor = null!;
    private readonly List<string> _wrong = [];

    public async Task InitializeAsync()
    {
        _db = await TestSql.CloneAsync("sec05");
        _branch = SaviaNode.BranchA(_db);
        _cashier = await _branch.SignInAsync(Ids.CashierA, "t_cashier_a");
        _supervisor = await _branch.SignInAsync(Ids.SupervisorA, "t_super_a");
    }

    public async Task DisposeAsync()
    {
        await _branch.DisposeAsync();
        await TestSql.DropAsync(_db);
    }

    private static string Long(int length) => new('x', length);

    private static StringContent Json(string body) => new(body, Encoding.UTF8, "application/json");

    private Task<int> CountAsync(string sql) => TestSql.ScalarAsync<int>(_db, sql);

    private async Task ExecAsync(string text)
    {
        await using var sql = new SqlConnection(TestSql.ConnectionFor(_db));
        await sql.OpenAsync();
        await using var command = new SqlCommand(text, sql);
        await command.ExecuteNonQueryAsync();
    }

    /// <summary>Records a mismatch instead of throwing; an exception from the host is recorded as the observed result.</summary>
    private async Task Expect(string label, Func<Task<HttpResponseMessage>> call, HttpStatusCode status, string? code)
    {
        HttpResponseMessage response;
        try { response = await call(); }
        catch (Exception ex) { _wrong.Add($"{label}: expected {(int)status} {code}, threw {ex.GetType().Name}: {First(ex.Message)}"); return; }
        var body = await response.Content.ReadAsStringAsync();
        string? actual = null;
        try { actual = JsonDocument.Parse(body).RootElement.GetProperty("code").GetString(); } catch (Exception) { }
        if (response.StatusCode != status || (code is not null && actual != code))
            _wrong.Add($"{label}: expected {(int)status} {code}, got {(int)response.StatusCode} {actual} {First(body)}");
    }

    private void Saved(string label, int rows, int expected = 0)
    {
        if (rows != expected) _wrong.Add($"{label}: {rows} rows saved, expected {expected}");
    }

    private void AssertNothingWrong() => Assert.True(_wrong.Count == 0, string.Join("\n", _wrong));

    private static string First(string text) => text.Length > 160 ? text[..160] : text;

    private async Task<Guid> OpenTillAsync()
    {
        var till = Guid.NewGuid();
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync("/api/v1/cash/tills", new OpenTillRequest(till, Ids.RegisterA, "NIO", 0, [new(100000, 0)])));
        return till;
    }

    [Fact]
    public async Task Till_and_sale_refuse_overlong_null_and_empty_fields_before_save()
    {
        // Gaps 5, 6 and 9 on /cash/tills, on a second register so a till saved by mistake does not block the sale below.
        var register = Guid.NewGuid();
        await ExecAsync($"INSERT sales.CashRegisters(Id,BranchId,LocationId,Code,Name) VALUES('{register}','{Ids.BranchA}','{Ids.LocA}','SEC05','Caja SEC05')");
        OpenTillRequest Till(string? currency, Guid? id = null) => new(id ?? Guid.NewGuid(), register, currency!, 0, [new(100000, 0)]);
        foreach (var (label, request) in new[] { ("till NIOX", Till("NIOX")), ("till null currency", Till(null)), ("till empty id", Till("NIO", Guid.Empty)) })
        {
            await Expect(label, () => _cashier.PostAsJsonAsync("/api/v1/cash/tills", request), Invalid, null);
            Saved(label, await CountAsync($"SELECT COUNT(*) FROM sales.CashTills WHERE Id='{request.TillId}'"));
        }
        await Expect("till NIOX code", () => _cashier.PostAsJsonAsync("/api/v1/cash/tills", Till("NIOX")), Invalid, "input.currency");
        await Expect("till empty id code", () => _cashier.PostAsJsonAsync("/api/v1/cash/tills", Till("NIO", Guid.Empty)), Invalid, "input.id");

        var till = await OpenTillAsync();
        _cashier.DefaultRequestHeaders.Add("X-Savia-Approval", _supervisor.DefaultRequestHeaders.Authorization!.Parameter);
        // A valid sale: the supervisor approves the discount, no stock in the store so the note is required (V036:419).
        PostSaleRequest Sale() => new(Guid.NewGuid(), till, "NIO", [new(1, Ids.Item, 1, 120000, 10000)], [new(1, "cash", 110000, 110000, 0)],
            DiscountReason: "Atencion autorizada", StockExceptionNote: "La prenda esta en la tienda");
        var cases = new (string Label, PostSaleRequest Request, string Code)[]
        {
            ("sale DiscountReason 251", Sale() with { DiscountReason = Long(251) }, "input.text"),       // Gap 1
            ("sale StockExceptionNote 501", Sale() with { StockExceptionNote = Long(501) }, "input.text"), // Gap 1
            ("sale NIOX", Sale() with { CurrencyCode = "NIOX" }, "input.currency"),                    // Gap 5
            ("sale null currency", Sale() with { CurrencyCode = null! }, "input.currency"),            // Gap 9
            ("sale empty id", Sale() with { SaleId = Guid.Empty }, "input.id"),                        // Gap 6
        };
        foreach (var (label, request, code) in cases)
        {
            await Expect(label, () => _cashier.PostAsJsonAsync("/api/v1/sales", request), Invalid, code);
            Saved(label, await CountAsync($"SELECT COUNT(*) FROM sales.Sales WHERE Id='{request.SaleId}'"));
        }
        // Gap 7: a null element in an array is a validation error, not an unhandled exception.
        var nullSale = Sale();
        var raw = JsonSerializer.Serialize(nullSale, new JsonSerializerOptions(JsonSerializerDefaults.Web));
        var lines = JsonDocument.Parse(raw).RootElement;
        string With(string property, string value) => raw.Replace($"\"{property}\":{lines.GetProperty(property).GetRawText()}", $"\"{property}\":{value}");
        await Expect("sale lines [null]", () => _cashier.PostAsync("/api/v1/sales", Json(With("lines", "[null]"))), Invalid, "sale.empty");
        await Expect("sale tenders [null]", () => _cashier.PostAsync("/api/v1/sales", Json(With("tenders", "[null]"))), Invalid, "sale.empty");
        Saved("sale with null element", await CountAsync($"SELECT COUNT(*) FROM sales.Sales WHERE Id='{nullSale.SaleId}'"));

        // The valid sale still posts, so each refusal above came from the field under test.
        await Expect("valid sale", () => _cashier.PostAsJsonAsync("/api/v1/sales", Sale()), HttpStatusCode.OK, null);
        AssertNothingWrong();
    }

    [Fact]
    public async Task Returns_refuse_null_lines_and_overlong_exchange_tenders()
    {
        await ExecAsync($"EXEC test.SeedStock @ItemId='{Ids.Item}',@LocationId='{Ids.LocA}',@Quantity=10;");
        var till = await OpenTillAsync();
        var sale = new PostSaleRequest(Guid.NewGuid(), till, "NIO", [new(1, Ids.Item, 2, 120000)], [new(1, "cash", 240000, 240000, 0)]);
        await HttpAssert.OkAsync<SaleResponse>(await _cashier.PostAsJsonAsync("/api/v1/sales", sale));
        var line = (await HttpAssert.OkAsync<SaleDetailResponse>(await _supervisor.GetAsync($"/api/v1/sales/{sale.SaleId}"))).Lines[0].SaleLineId;
        var path = $"/api/v1/sales/{sale.SaleId}/returns";

        // Gap 7: null element in Lines on both return routes.
        var credit = $$"""{"reversalId":"{{Guid.NewGuid()}}","creditId":"{{Guid.NewGuid()}}","tillId":"{{till}}","customerId":"{{Guid.NewGuid()}}","reason":"Talla","lines":[null]}""";
        await Expect("credit lines [null]", () => _supervisor.PostAsync($"{path}/credit", Json(credit)), Invalid, "return.lines");
        var outcome = $$"""{"reversalId":"{{Guid.NewGuid()}}","outcome":"cash","tillId":"{{till}}","reason":"Talla","lines":[null]}""";
        await Expect("outcome lines [null]", () => _supervisor.PostAsync($"{path}/outcome", Json(outcome)), Invalid, "return.lines");

        // Gap 10: the exchange tenders get the same checks as a sale's tenders. The exchange is otherwise valid: one unit back,
        // two new units, and the difference of one unit paid in cash.
        var exchange = new PostReturnOutcomeRequest(Guid.NewGuid(), "exchange", till, "Cambio de talla", [new(line, 1, "store")],
            ExchangeSaleId: Guid.NewGuid(), NewLines: [new(1, Ids.Item, 2, 120000)], NewTenders: [new(1, "cash", 120000, 120000, 0)]);
        var cases = new (string Label, PostReturnOutcomeRequest Request, string Code)[]
        {
            ("exchange TenderKind 21", exchange with { NewTenders = [new(1, Long(21), 120000, 120000, 0)] }, "input.text"),
            ("exchange tender Reference 121", exchange with { NewTenders = [new(1, "transfer", 120000, Reference: Long(121))] }, "input.text"),
            ("exchange null tender", exchange with { NewTenders = [null!] }, "return.exchange_lines"),
            ("exchange null new line", exchange with { NewLines = [null!] }, "return.exchange_lines"),
            ("return empty id", exchange with { ReversalId = Guid.Empty }, "input.id"),
        };
        foreach (var (label, request, code) in cases)
        {
            await Expect(label, () => _supervisor.PostAsJsonAsync($"{path}/outcome", request), Invalid, code);
            Saved(label, await CountAsync($"SELECT COUNT(*) FROM sales.Sales WHERE Id='{request.ExchangeSaleId}'"));
        }
        Saved("no reversal saved", await CountAsync($"SELECT COUNT(*) FROM sales.SaleReversals WHERE SaleId='{sale.SaleId}'"));
        // The valid exchange still posts, so each refusal above came from the field under test.
        await Expect("valid exchange", () => _supervisor.PostAsJsonAsync($"{path}/outcome", exchange with { ReversalId = Guid.NewGuid(), ExchangeSaleId = Guid.NewGuid() }),
            HttpStatusCode.OK, null);
        AssertNothingWrong();
    }

    [Fact]
    public async Task Receiving_labels_and_customers_refuse_overlong_fields_and_empty_ids()
    {
        // Gap 4 and Gap 6 on /receiving/sessions.
        OpenScanSessionRequest Session(string? device = "SCAN-01") => new(Guid.NewGuid(), Guid.NewGuid(), $"CONT-SEC05-{Guid.NewGuid():N}", Ids.Supplier, device);
        foreach (var (label, request, code) in new[]
        {
            ("session DeviceCode 81", Session(Long(81)), "input.text"),
            ("session empty id", Session() with { ScanSessionId = Guid.Empty }, "input.id"),
            ("session empty container", Session() with { ContainerId = Guid.Empty }, "input.id"),
        })
        {
            await Expect(label, () => _cashier.PostAsJsonAsync("/api/v1/receiving/sessions", request), Invalid, code);
            Saved(label, await CountAsync($"SELECT COUNT(*) FROM receiving.ScanSessions WHERE Id='{request.ScanSessionId}'"));
        }

        var session = Session();
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync("/api/v1/receiving/sessions", session));
        var scans = $"/api/v1/receiving/sessions/{session.ScanSessionId}/scans";
        foreach (var (label, request, code) in new[]
        {
            ("scan DeviceCode 81", new RecordScanRequest(Guid.NewGuid(), Ids.ItemBarcode, 1, Long(81)), "input.text"),
            ("scan empty id", new RecordScanRequest(Guid.Empty, Ids.ItemBarcode), "input.id"),
        })
            await Expect(label, () => _cashier.PostAsJsonAsync(scans, request), Invalid, code);
        Saved("scans refused", await CountAsync($"SELECT COUNT(*) FROM receiving.ScanEvents WHERE ScanSessionId='{session.ScanSessionId}'"));

        // A real label job: one matched unit, approved and posted.
        await HttpAssert.OkAsync<ScanResult>(await _cashier.PostAsJsonAsync(scans, new RecordScanRequest(Guid.NewGuid(), Ids.ItemBarcode)));
        await HttpAssert.OkAsync(await _supervisor.PostAsync($"/api/v1/receiving/sessions/{session.ScanSessionId}/approve", null));
        await HttpAssert.OkAsync<PostScanSessionResponse>(await _supervisor.PostAsync($"/api/v1/receiving/sessions/{session.ScanSessionId}/post", null));
        var job = Assert.Single(await HttpAssert.OkAsync<LabelJob[]>(await _cashier.GetAsync("/api/v1/labels/jobs"))).Id;
        foreach (var (label, request, code) in new[]
        {
            ("label PrinterResponse 501", new AckPrintRequest(Guid.NewGuid(), 1, false, Long(501)), "input.text"),   // Gap 3
            ("label AttemptNo 0", new AckPrintRequest(Guid.NewGuid(), 0, true), "label.attempt"),                   // Gaps 3 and 11
            ("label empty id", new AckPrintRequest(Guid.Empty, 1, true), "input.id"),                               // Gap 6
        })
            await Expect(label, () => _cashier.PostAsJsonAsync($"/api/v1/labels/jobs/{job}/attempts", request), Invalid, code);
        Saved("label attempts", await CountAsync($"SELECT COUNT(*) FROM labels.PrintAttempts WHERE PrintJobId='{job}'"));

        // Gap 6 on /customers.
        await Expect("customer empty id", () => _cashier.PostAsJsonAsync("/api/v1/customers",
            new CreateCustomerRequest(Guid.Empty, "Clienta SEC05", null, null, null)), Invalid, "input.id");
        Saved("customer empty id", await CountAsync($"SELECT COUNT(*) FROM crm.Customers WHERE Id='{Guid.Empty}'"));
        AssertNothingWrong();
    }

    [Fact]
    public async Task Catalog_refuses_overlong_codes_out_of_range_values_and_bad_import_rows()
    {
        await using var hub = SaviaNode.Cloud(_db);
        var owner = await hub.SignInAsync(Ids.Manager, "t_manager");
        await Expect("product empty id", () => owner.PostAsJsonAsync("/api/v1/catalog/products", new RegisterProductRequest(Guid.Empty, "Blusa SEC05 sin id")),
            Invalid, "input.id");
        Saved("product empty id", await CountAsync($"SELECT COUNT(*) FROM catalog.Products WHERE Id='{Guid.Empty}'"));
        // One product per item: a product holds one variant without size and color (UQ_Items_Product_Variant).
        async Task<RegisterItemRequest> ItemAsync()
        {
            var product = new RegisterProductRequest(Guid.NewGuid(), $"Blusa SEC05 {Guid.NewGuid():N}");
            await HttpAssert.OkAsync(await owner.PostAsJsonAsync("/api/v1/catalog/products", product));
            return new(Guid.NewGuid(), product.ProductId, $"SEC05-{Guid.NewGuid():N}"[..20], "Blusa SEC05 M", "NIO", 50000, 20000,
                $"SEC05{Random.Shared.NextInt64(1_000_000_000L, 9_999_999_999L)}");
        }
        var cases = new (string Label, RegisterItemRequest Request, string Code)[]
        {
            ("item Barcode 129", await ItemAsync() with { Barcode = Long(129) }, "input.text"),                                // Gap 2
            ("item SupplierSku 129", await ItemAsync() with { SupplierId = Ids.Supplier, SupplierSku = Long(129) }, "input.text"), // Gap 2
            ("item NIOX", await ItemAsync() with { CurrencyCode = "NIOX" }, "input.currency"),                                // Gap 5
            ("item null currency", await ItemAsync() with { CurrencyCode = null! }, "input.currency"),                        // Gap 9
            ("item negative cost", await ItemAsync() with { UnitCostMinor = -1 }, "db.check"),                                // Gap 11
            ("item empty id", await ItemAsync() with { ItemId = Guid.Empty }, "input.id"),                                    // Gap 6
        };
        foreach (var (label, request, code) in cases)
        {
            await Expect(label, () => owner.PostAsJsonAsync("/api/v1/catalog/items", request), Invalid, code);
            Saved(label, await CountAsync($"SELECT COUNT(*) FROM catalog.Items WHERE Id='{request.ItemId}'"));
        }
        var item = await ItemAsync();
        await HttpAssert.OkAsync(await owner.PostAsJsonAsync("/api/v1/catalog/items", item));

        // Gap 11: a price above CK_Items_Price (9e12) is a validation error; a negative cost keeps the procedure rule (V019:15).
        var values = $"/api/v1/catalog/items/{item.ItemId}/values";
        await Expect("values price 9e12+1", () => owner.PostAsJsonAsync(values, new ItemValuesRequest(Guid.NewGuid(), 9_000_000_000_001, 20000, "Precio")),
            Invalid, "db.check");
        await Expect("values negative cost", () => owner.PostAsJsonAsync(values, new ItemValuesRequest(Guid.NewGuid(), 50000, -1, "Costo")), Invalid, null);
        Saved("values unchanged", await CountAsync($"SELECT COUNT(*) FROM catalog.Items WHERE Id='{item.ItemId}' AND UnitPriceMinor=50000"), 1);

        // Gap 8: an overlong row field is a row error in the preview, and the commit refuses the file with import.row_errors; a null row is 422.
        ImportRow Row(int n) => new(n, "7501234567893", null, "Blusa importada", "Blusa", "M", "Azul", "200", "450", null);
        var overlong = new (string Label, ImportRow Row)[]
        {
            ("import Code 129", Row(2) with { Code = Long(129) }), ("import Sku 101", Row(2) with { Sku = Long(101) }),
            ("import Name 201", Row(2) with { Name = Long(201) }), ("import Type 121", Row(2) with { Type = Long(121) }),
            ("import Size 71", Row(2) with { Size = Long(71) }), ("import Color 71", Row(2) with { Color = Long(71) }),
            ("import Cost 41", Row(2) with { Cost = "1" + new string('0', 40) }), ("import Stock 41", Row(2) with { Stock = Long(41) }),
        };
        foreach (var (label, row) in overlong)
        {
            var request = new ImportCatalogRequest(Guid.NewGuid(), "sec05.csv", [row]);
            HttpResponseMessage response;
            try { response = await owner.PostAsJsonAsync("/api/v1/catalog/import/preview", request); }
            catch (Exception ex) { _wrong.Add($"{label}: threw {ex.GetType().Name}: {First(ex.Message)}"); continue; }
            var body = await response.Content.ReadAsStringAsync();
            if (response.StatusCode != HttpStatusCode.OK || JsonDocument.Parse(body).RootElement.GetProperty("errorCount").GetInt32() != 1)
                _wrong.Add($"{label}: expected 200 with one row error, got {(int)response.StatusCode} {First(body)}");
            await Expect($"{label} commit", () => owner.PostAsJsonAsync("/api/v1/catalog/import", request), HttpStatusCode.Conflict, "import.row_errors");
            Saved($"{label} batch", await CountAsync($"SELECT COUNT(*) FROM catalog.ImportBatches WHERE Id='{request.BatchId}'"));
        }
        var nullRow = $$"""{"batchId":"{{Guid.NewGuid()}}","fileName":"sec05.csv","rows":[null]}""";
        await Expect("import null row", () => owner.PostAsync("/api/v1/catalog/import/preview", Json(nullRow)), Invalid, "import.size");
        await Expect("import empty batch", () => owner.PostAsJsonAsync("/api/v1/catalog/import/preview",
            new ImportCatalogRequest(Guid.Empty, "sec05.csv", [Row(2)])), Invalid, "input.id");
        // The valid row still previews clean, so each row error above came from the field under test.
        var clean = await owner.PostAsJsonAsync("/api/v1/catalog/import/preview", new ImportCatalogRequest(Guid.NewGuid(), "sec05.csv", [Row(2)]));
        if (!(await clean.Content.ReadAsStringAsync()).Contains("\"errorCount\":0")) _wrong.Add("valid import row: not clean");
        AssertNothingWrong();
    }

    /// <summary>Gap 12: a body the binder cannot read is 400 with the app's problem code, before any service runs; never 500.</summary>
    [Fact]
    public async Task Remaining_client_ids_refuse_the_empty_id()
    {
        // Gap 6 on the ids the other tests do not reach. Each body is otherwise valid up to the id check, so only the empty id
        // can answer input.id; without Guard.Id the request reaches the store and answers something else.
        var till = await OpenTillAsync();
        await using var hub = SaviaNode.Cloud(_db);
        var hubOwner = await hub.SignInAsync(Ids.Manager, "t_manager");
        // The same owner signs in on the branch next, which ends this hub session, so the hub case runs first.
        await Expect("supplierId", () => hubOwner.PostAsJsonAsync("/api/v1/suppliers", new CreateSupplierRequest(Guid.Empty, "Proveedor SEC05")), Invalid, "input.id");
        var owner = await _branch.SignInAsync(Ids.Manager, "t_manager");
        var sale = $"/api/v1/sales/{Guid.NewGuid()}/returns";
        var cases = new (string Label, Func<Task<HttpResponseMessage>> Call)[]
        {
            ("cashCountId", () => _cashier.PostAsJsonAsync($"/api/v1/cash/tills/{till}/counts", new RecordCashCountRequest(Guid.Empty, [new(100000, 1)]))),
            ("closureId", () => _supervisor.PostAsJsonAsync($"/api/v1/cash/tills/{till}/close", new CloseTillRequest(Guid.Empty, Guid.NewGuid()))),
            ("item values changeId", () => owner.PostAsJsonAsync($"/api/v1/catalog/items/{Ids.Item}/values", new ItemValuesRequest(Guid.Empty, 125000, 62000, "Precio SEC05"))),
            ("return window changeId", () => owner.PostAsJsonAsync("/api/v1/returns/policy", new ReturnWindowRequest(Guid.Empty, 30, "Ventana SEC05"))),
            ("transferId", () => _cashier.PostAsJsonAsync("/api/v1/credit-transfers",
                new RequestCreditTransferRequest(Guid.Empty, Guid.NewGuid(), Ids.BranchA, Ids.BranchB, 1000, "Traslado SEC05"))),
            ("checkId", () => _supervisor.PostAsJsonAsync($"/api/v1/receiving/sessions/{Guid.NewGuid()}/quality",
                new QualityRequest(Guid.Empty, Ids.Item, 1, 0, 0, 0, 0, "Revision SEC05"))),
            ("creditId", () => _supervisor.PostAsJsonAsync($"{sale}/credit",
                new PostCreditReturnRequest(Guid.NewGuid(), Guid.Empty, till, Guid.NewGuid(), "Talla", [new(Guid.NewGuid(), 1, "store")]))),
            ("exchangeSaleId", () => _supervisor.PostAsJsonAsync($"{sale}/outcome",
                new PostReturnOutcomeRequest(Guid.NewGuid(), "exchange", till, "Cambio de talla", [new(Guid.NewGuid(), 1, "store")],
                    ExchangeSaleId: Guid.Empty, NewLines: [new(1, Ids.Item, 1, 120000)], NewTenders: [new(1, "cash", 120000, 120000, 0)]))),
        };
        foreach (var (label, call) in cases) await Expect(label, call, Invalid, "input.id");
        AssertNothingWrong();
    }

    [Fact]
    public async Task Unreadable_bodies_are_400_on_staff_routes()
    {
        var id = Guid.NewGuid();
        string[] routes =
        [
            "/api/v1/cash/tills", "/api/v1/sales", "/api/v1/customers", "/api/v1/receiving/sessions",
            $"/api/v1/sales/{id}/returns/outcome", "/api/v1/returns/policy", $"/api/v1/cash/tills/{id}/counts", $"/api/v1/labels/jobs/{id}/attempts",
        ];
        (string Label, string Body)[] bodies = [("empty", ""), ("null", "null"), ("malformed", "{\"tillId\":"), ("array", "[]"), ("string", "\"x\""), ("number", "5")];
        foreach (var route in routes)
            foreach (var (label, body) in bodies)
                await Expect($"{route} {label}", () => _supervisor.PostAsync(route, Json(body)), HttpStatusCode.BadRequest, "input.body");
        AssertNothingWrong();
    }
}
