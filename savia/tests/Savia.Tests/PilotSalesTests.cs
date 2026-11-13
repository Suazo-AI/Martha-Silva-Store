using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using Savia.Contracts;

namespace Savia.Tests;

public sealed class PilotSalesTests : IAsyncLifetime
{
    private string _db = "";
    private SaviaNode _node = null!;
    private HttpClient _cashier = null!, _supervisor = null!;
    public async Task InitializeAsync()
    {
        _db = await TestSql.CloneAsync("pilot_sales");
        _node = SaviaNode.BranchA(_db);
        _cashier = await _node.SignInAsync(Ids.CashierA, "t_cashier_a");
        _supervisor = await _node.SignInAsync(Ids.SupervisorA, "t_super_a");
    }
    public async Task DisposeAsync() { await _node.DisposeAsync(); await TestSql.DropAsync(_db); }
    private async Task Exec(string text)
    {
        await using var c = new SqlConnection(TestSql.ConnectionFor(_db)); await c.OpenAsync();
        await using var cmd = new SqlCommand(text, c); await cmd.ExecuteNonQueryAsync();
    }
    [Theory]
    [InlineData("/api/v1/sales")]
    [InlineData("/api/v1/customers?q=Clienta")]
    [InlineData("/api/v1/credits/search?q=Clienta")]
    [InlineData("/api/v1/reports/day?date=2026-11-12")]
    public async Task New_reads_require_authentication(string path) =>
        await HttpAssert.ProblemAsync(await _node.CreateClient().GetAsync(path), HttpStatusCode.Unauthorized, "auth.required");

    [Fact]
    public async Task Catalog_grid_is_authenticated_grouped_and_local()
    {
        await HttpAssert.ProblemAsync(await _node.CreateClient().GetAsync("/api/v1/catalog/items"), HttpStatusCode.Unauthorized, "auth.required");
        var response = await _cashier.GetAsync("/api/v1/catalog/items");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var groups = await response.Content.ReadFromJsonAsync<JsonElement>();
        var product = Assert.Single(groups.EnumerateArray(), p => p.GetProperty("variants").EnumerateArray().Any(v => v.GetProperty("itemId").GetGuid() == Ids.Item));
        Assert.Equal("Blusas", product.GetProperty("type").GetString());
        Assert.All(product.GetProperty("variants").EnumerateArray(), v => Assert.Equal(0, v.GetProperty("available").GetInt32()));
        await Exec($"EXEC test.SeedStock @ItemId='{Ids.Item}',@LocationId='{Ids.LocA}',@Quantity=20;");
        groups = await (await _cashier.GetAsync("/api/v1/catalog/items")).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Contains(groups.EnumerateArray().SelectMany(p => p.GetProperty("variants").EnumerateArray()), v => v.GetProperty("itemId").GetGuid() == Ids.Item && v.GetProperty("available").GetInt32() == 20);
        var noAccess = await _node.SignInAsync(new("C0000000-0000-0000-0000-0000000000C5"), "t_super_c");
        await HttpAssert.ProblemAsync(await noAccess.GetAsync("/api/v1/catalog/items"), HttpStatusCode.Forbidden, "auth.branch_access");
    }

    [Fact]
    public async Task Cashier_discount_requires_live_local_supervisor()
    {
        var till = await OpenTill();
        PostSaleRequest Request(long discount) => new(Guid.NewGuid(), till, "NIO", [new(1, Ids.Item, 1, 120000, discount)], [new(1, "cash", 120000-discount, 120000-discount, 0)]);
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/sales", Request(24000)), HttpStatusCode.Forbidden, "sale.discount_approval_required");
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/sales", Request(12000)), HttpStatusCode.Forbidden, "sale.discount_approval_required");
        _cashier.DefaultRequestHeaders.Add("X-Savia-Approval", _cashier.DefaultRequestHeaders.Authorization!.Parameter);
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/sales", Request(24000)), HttpStatusCode.Forbidden, "auth.role_required");
        _cashier.DefaultRequestHeaders.Remove("X-Savia-Approval");
        _cashier.DefaultRequestHeaders.Add("X-Savia-Approval", _supervisor.DefaultRequestHeaders.Authorization!.Parameter);
        var approvedRequest = Request(24000) with { DiscountReason = "Atencion autorizada" };
        var approved = await HttpAssert.OkAsync<SaleResponse>(await _cashier.PostAsJsonAsync("/api/v1/sales", approvedRequest));
        Assert.Equal(96000, approved.TotalMinor);
        var approvedDetail = await HttpAssert.OkAsync<SaleDetailResponse>(await _cashier.GetAsync($"/api/v1/sales/{approved.SaleId}"));
        Assert.Equal(Ids.SupervisorA, approvedDetail.DiscountApprovedBy);
        Assert.Equal("Atencion autorizada", approvedDetail.DiscountReason);
        Assert.NotNull(approvedDetail.ReceiptNumber);
        Assert.Equal(Ids.CashierA, (await HttpAssert.OkAsync<SaleDetailResponse>(await _cashier.GetAsync($"/api/v1/sales/{approved.SaleId}"))).CashierId);
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync("/api/v1/sales", approvedRequest));
        var full = Request(120000) with { Tenders = [], DiscountReason = "Cortesia autorizada" };
        var free = await HttpAssert.OkAsync<SaleResponse>(await _cashier.PostAsJsonAsync("/api/v1/sales", full));
        Assert.Equal(0, free.TotalMinor);
        _cashier.DefaultRequestHeaders.Remove("X-Savia-Approval");
        _cashier.DefaultRequestHeaders.Add("X-Savia-Approval", new string('x', 32));
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/sales", Request(24000)), HttpStatusCode.Unauthorized, "auth.required");
    }

    private static readonly Guid Customer = new("00000000-0000-0000-0000-00000000C051");
    [Theory]
    [InlineData("day")]
    [InlineData("week")]
    [InlineData("month")]
    [InlineData("year")]
    public async Task Period_reports_and_csv_use_sql_totals_and_require_manager(string period)
    {
        var till = await OpenTill();
        await Sale(till, 2);
        var path = $"/api/v1/reports/summary?period={period}&date={Today}";
        await HttpAssert.ProblemAsync(await _cashier.GetAsync(path), HttpStatusCode.Forbidden, "auth.role_required");
        var report = await HttpAssert.OkAsync<JsonElement>(await _supervisor.GetAsync(path));
        Assert.Equal(1, report.GetProperty("salesCount").GetInt32());
        Assert.Equal(2, report.GetProperty("unitsSold").GetInt32());
        Assert.Equal(240000, report.GetProperty("grossMinor").GetInt64());
        Assert.Equal(240000, report.GetProperty("netMinor").GetInt64());
        Assert.Equal(1, report.GetProperty("customersServed").GetInt32());
        Assert.Single(report.GetProperty("salesByDay").EnumerateArray());
        var csv=await _supervisor.GetAsync($"/api/v1/reports/summary.csv?period={period}&date={Today}");
        Assert.Equal(HttpStatusCode.OK,csv.StatusCode);
        Assert.Equal("text/csv",csv.Content.Headers.ContentType!.MediaType);
        Assert.Contains("\"netMinor\",\"240000\"",await csv.Content.ReadAsStringAsync());
        await HttpAssert.ProblemAsync(await _supervisor.GetAsync($"/api/v1/reports/summary?period=bad&date={Today}"), HttpStatusCode.UnprocessableEntity, "report.range");
    }
    [Fact]
    public async Task Opening_amount_must_equal_denominations()
    {
        var response = await _cashier.PostAsJsonAsync("/api/v1/cash/tills", new {
            tillId=Guid.NewGuid(), registerId=Ids.RegisterA, currencyCode="NIO", openingMinor=100000,
            lines=new[]{new {denominationMinor=50000,quantity=1}} });
        Assert.Equal(HttpStatusCode.UnprocessableEntity, response.StatusCode);
    }
    [Fact]
    public async Task Opening_breakdown_round_trips_and_cannot_be_changed_on_retry()
    {
        var denominations=await HttpAssert.OkAsync<long[]>(await _cashier.GetAsync("/api/v1/cash/denominations"));
        Assert.Equal(new long[]{100000,50000,20000,10000,5000,2000,1000,500,100,50,25,10},denominations);
        var lines=denominations.Select(d=>new CashCountLine(d,1)).ToArray();
        var request=new OpenTillRequest(Guid.NewGuid(),Ids.RegisterA,"NIO",denominations.Sum(),lines);
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync("/api/v1/cash/tills",request));
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync("/api/v1/cash/tills",request));
        var summary=await HttpAssert.OkAsync<TillSummary>(await _cashier.GetAsync($"/api/v1/cash/tills/{request.TillId}/summary"));
        Assert.Equal(lines,summary.OpeningLines);
        Assert.Equal(lines.Sum(l=>l.DenominationMinor*l.Quantity),summary.OpeningMinor);
        var changed=request with {Lines=[new(100000,1)],OpeningMinor=100000};
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/cash/tills",changed),HttpStatusCode.Conflict,"cash.till_id_reused");
        await HttpAssert.ProblemAsync(await _supervisor.PostAsJsonAsync($"/api/v1/cash/tills/{request.TillId}/close",new CloseTillRequest(Guid.NewGuid(),request.TillId)),HttpStatusCode.Conflict,"cash.count_missing");
        await TestSql.AssertConservationAsync(_db);
    }
    [Fact]
    public async Task Zero_stock_sale_records_exception_and_keeps_conservation()
    {
        var till=Guid.NewGuid();
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync("/api/v1/cash/tills", new {
            tillId=till,registerId=Ids.RegisterA,currencyCode="NIO",openingMinor=0,
            lines=new[]{new {denominationMinor=100000,quantity=0}} }));
        var sale=Guid.NewGuid();
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync("/api/v1/sales", new {
            saleId=sale,tillId=till,currencyCode="NIO",stockExceptionNote="Existencia fisica confirmada",
            lines=new[]{new {lineNumber=1,itemId=Ids.Item,quantity=1,unitPriceMinor=120000}},
            tenders=new[]{new {tenderNumber=1,tenderKind="cash",amountMinor=120000,receivedMinor=120000,changeMinor=0}} }));
        await TestSql.AssertConservationAsync(_db);
        var pending=await HttpAssert.OkAsync<JsonElement>(await _supervisor.GetAsync("/api/v1/stock/exceptions"));
        var exception=Assert.Single(pending.EnumerateArray());
        Assert.Equal(sale,exception.GetProperty("saleId").GetGuid());
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync($"/api/v1/stock/exceptions/{exception.GetProperty("id").GetGuid()}/review",new {reason="Revisado"}),HttpStatusCode.Forbidden,"auth.role_required");
        await HttpAssert.OkAsync(await _supervisor.PostAsJsonAsync($"/api/v1/stock/exceptions/{exception.GetProperty("id").GetGuid()}/review",new {reason="Revisado"}));
    }
    private static string Today => DateTime.UtcNow.AddHours(-6).ToString("yyyy-MM-dd");
    private async Task<Guid> OpenTill()
    {
        await Exec($"EXEC test.SeedStock @ItemId='{Ids.Item}',@LocationId='{Ids.LocA}',@Quantity=20;");
        var till = Guid.NewGuid();
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync("/api/v1/cash/tills", new OpenTillRequest(till, Ids.RegisterA, "NIO", 100000, [new(100000, 1)])));
        return till;
    }
    private async Task<Guid> Sale(Guid till, int quantity = 2, SaleTender[]? tenders = null)
    {
        var id = Guid.NewGuid();
        var total = quantity * 120000L;
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync("/api/v1/sales", new PostSaleRequest(id, till, "NIO",
            [new(1, Ids.Item, quantity, 120000)], tenders ?? [new(1, "cash", total, total, 0)], Customer)));
        return id;
    }
    [Fact]
    public async Task History_detail_search_pagination_dates_and_branch_isolation()
    {
        var till = await OpenTill();
        var first = await Sale(till);
        var second = await Sale(till);
        var foreign = Guid.NewGuid();
        await Exec($"EXEC test.SeedSale @SaleId='{foreign}',@Key='B';");
        var all = await HttpAssert.OkAsync<SalesPage>(await _cashier.GetAsync($"/api/v1/sales?from={Today}&to={Today}&pageSize=1"));
        Assert.Equal(2, all.Total); Assert.Single(all.Items);
        var next = await HttpAssert.OkAsync<SalesPage>(await _cashier.GetAsync($"/api/v1/sales?page=2&pageSize=1"));
        Assert.NotEqual(all.Items[0].SaleId, next.Items[0].SaleId);
        foreach (var q in new[] { "T-SKU-0001", "Blusa", "Cli%C3%A9nta", first.ToString()[..8] })
        {
            var found = await HttpAssert.OkAsync<SalesPage>(await _cashier.GetAsync($"/api/v1/sales?q={q}"));
            Assert.Contains(found.Items, s => s.SaleId == first);
            Assert.DoesNotContain(found.Items, s => s.SaleId == foreign);
        }
        Assert.Empty((await HttpAssert.OkAsync<SalesPage>(await _cashier.GetAsync("/api/v1/sales?q=%25"))).Items);
        Assert.Empty((await HttpAssert.OkAsync<SalesPage>(await _cashier.GetAsync("/api/v1/sales?to=2000-01-01"))).Items);
        var detail = await HttpAssert.OkAsync<SaleDetailResponse>(await _cashier.GetAsync($"/api/v1/sales/{first}"));
        Assert.Equal((Ids.CashierA, till, "Cajera A", 240000L), (detail.CashierId, detail.TillId!.Value, detail.CashierName, detail.TotalMinor));
        var line = Assert.Single(detail.Lines);
        Assert.Equal(("T-SKU-0001", "M", 2, 0, 120000L), (line.Sku, line.SizeCode, line.Quantity, line.ReturnedQuantity, line.UnitPriceMinor));
        Assert.NotEmpty(line.Name); Assert.Single(detail.Tenders); Assert.Empty(detail.Reversals);
        await HttpAssert.ProblemAsync(await _cashier.GetAsync($"/api/v1/sales/{foreign}"), HttpStatusCode.NotFound, "sale.not_found");
        await HttpAssert.ProblemAsync(await _node.CreateClient().GetAsync($"/api/v1/sales/{first}"), HttpStatusCode.Unauthorized, "auth.required");
        await HttpAssert.ProblemAsync(await _cashier.GetAsync("/api/v1/sales?page=0"), HttpStatusCode.UnprocessableEntity, "report.range");
        await HttpAssert.ProblemAsync(await _cashier.GetAsync("/api/v1/sales?from=2026-11-13&to=2026-11-12"), HttpStatusCode.UnprocessableEntity, "report.range");
        var noAccess = await _node.SignInAsync(new("C0000000-0000-0000-0000-0000000000C5"), "t_super_c");
        foreach (var path in new[] { "/api/v1/sales", $"/api/v1/sales/{first}", "/api/v1/customers?q=Clienta", "/api/v1/credits/search?q=Clienta", $"/api/v1/reports/day?date={Today}" })
            await HttpAssert.ProblemAsync(await noAccess.GetAsync(path), HttpStatusCode.Forbidden, "auth.branch_access");
    }

    [Fact]
    public async Task Return_requires_supervisor_and_sql_permission_and_preserves_stock_credit_and_retry()
    {
        var till = await OpenTill(); var sale = await Sale(till);
        var detail = await HttpAssert.OkAsync<SaleDetailResponse>(await _cashier.GetAsync($"/api/v1/sales/{sale}"));
        var request = new PostCreditReturnRequest(Guid.NewGuid(), Guid.NewGuid(), till, Customer, "Talla MUESTRA", [new(detail.Lines[0].SaleLineId, 1, "quarantine")]);
        var path = $"/api/v1/sales/{sale}/returns/credit";
        await HttpAssert.ProblemAsync(await _node.CreateClient().PostAsJsonAsync(path, request), HttpStatusCode.Unauthorized, "auth.required");
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync(path, request), HttpStatusCode.Forbidden, "auth.role_required");
        await Exec($"UPDATE security.StaffBranchAccess SET CanApproveReturns=0 WHERE StaffId='{Ids.SupervisorA}';");
        await HttpAssert.ProblemAsync(await _supervisor.PostAsJsonAsync(path, request), HttpStatusCode.Forbidden, "return.approval_required");
        await Exec($"UPDATE security.StaffBranchAccess SET CanApproveReturns=1 WHERE StaffId='{Ids.SupervisorA}';");
        var result = await HttpAssert.OkAsync<SaleReversal>(await _supervisor.PostAsJsonAsync(path, request));
        var retry = await HttpAssert.OkAsync<SaleReversal>(await _supervisor.PostAsJsonAsync(path, request));
        Assert.Equal((request.ReversalId, request.CreditId, 120000L, Ids.SupervisorA, "credit"),
            (result.ReversalId, result.CreditId!.Value, result.CreditMinor, result.ApprovedBy!.Value, result.SettlementKind));
        Assert.Equal(result.ReversalId, retry.ReversalId);
        Assert.Equal(1, await TestSql.ScalarAsync<int>(_db, $"SELECT COUNT(*) FROM credits.Credits WHERE Id='{request.CreditId}'"));
        var stocks = await HttpAssert.OkAsync<StockRow[]>(await _cashier.GetAsync($"/api/v1/stock?itemId={Ids.Item}"));
        Assert.Equal(1, Assert.Single(stocks, s => s.Pool == "quarantine").OnHand);
        await HttpAssert.ProblemAsync(await _supervisor.PostAsJsonAsync(path, request with { ReversalId = Guid.NewGuid(), CreditId = Guid.NewGuid(), Lines = [new(detail.Lines[0].SaleLineId, 2, "store")] }), HttpStatusCode.Conflict, "return.quantity");
        await HttpAssert.ProblemAsync(await _supervisor.PostAsJsonAsync(path, request with { Lines = [new(detail.Lines[0].SaleLineId, 2, "store")] }), HttpStatusCode.Conflict, "sale.reversal_id_reused");
        var foreign = Guid.NewGuid(); await Exec($"EXEC test.SeedSale @SaleId='{foreign}',@Key='B';");
        await HttpAssert.ProblemAsync(await _supervisor.PostAsJsonAsync($"/api/v1/sales/{foreign}/returns/credit", request with { ReversalId = Guid.NewGuid(), CreditId = Guid.NewGuid() }), HttpStatusCode.Forbidden, "auth.branch_access");
        var after = await HttpAssert.OkAsync<SaleDetailResponse>(await _cashier.GetAsync($"/api/v1/sales/{sale}"));
        Assert.Equal(("partially_returned", 1), (after.Status, after.Lines[0].ReturnedQuantity)); Assert.Single(after.Reversals);
        await TestSql.AssertConservationAsync(_db);
    }

    [Fact]
    public async Task All_tenders_customer_credit_search_redemption_and_day_accounting_are_real_sql()
    {
        var till = await OpenTill();
        var customers = await HttpAssert.OkAsync<CustomerRow[]>(await _cashier.GetAsync("/api/v1/customers?q=Cli%C3%A9nta"));
        Assert.Contains(customers, c => c.CustomerId == Customer);
        await HttpAssert.ProblemAsync(await _cashier.GetAsync("/api/v1/customers?q=x"), HttpStatusCode.UnprocessableEntity, "customer.search_too_short");
        await HttpAssert.ProblemAsync(await _cashier.GetAsync("/api/v1/credits/search?q=x"), HttpStatusCode.UnprocessableEntity, "credit.search_too_short");
        var sale = await Sale(till);
        var detail = await HttpAssert.OkAsync<SaleDetailResponse>(await _cashier.GetAsync($"/api/v1/sales/{sale}"));
        var ret = new PostCreditReturnRequest(Guid.NewGuid(), Guid.NewGuid(), till, Customer, "MUESTRA", [new(detail.Lines[0].SaleLineId, 1, "store")]);
        await HttpAssert.OkAsync(await _supervisor.PostAsJsonAsync($"/api/v1/sales/{sale}/returns/credit", ret));
        var credits = await HttpAssert.OkAsync<CustomerCreditRow[]>(await _cashier.GetAsync("/api/v1/credits/search?q=Clienta"));
        Assert.Equal(120000L, Assert.Single(credits, c => c.CreditId == ret.CreditId).AvailableMinor);
        var mixedId = await Sale(till, 1, [new(1, "card", 30000, Reference: "AUTH-MUESTRA"),
            new(2, "transfer", 30000, Reference: "TRANSFER-MUESTRA"), new(3, "other", 30000, Reference: "OTRO-MUESTRA"), new(4, "credit", 30000, CreditId: ret.CreditId)]);
        var mixed = await HttpAssert.OkAsync<SaleDetailResponse>(await _cashier.GetAsync($"/api/v1/sales/{mixedId}"));
        Assert.Equal(4, mixed.Tenders.Length); Assert.Contains(mixed.Tenders, t => t.Reference == "AUTH-MUESTRA");
        Assert.Equal(90000L, Assert.Single(await HttpAssert.OkAsync<CustomerCreditRow[]>(await _cashier.GetAsync("/api/v1/credits/search?q=Clienta")), c => c.CreditId == ret.CreditId).AvailableMinor);
        var insufficient = new PostSaleRequest(Guid.NewGuid(), till, "NIO", [new(1, Ids.Item, 1, 120000)], [new(1, "credit", 120000, CreditId: ret.CreditId)], Customer);
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/sales", insufficient), HttpStatusCode.Conflict, "credit.insufficient");
        await HttpAssert.ProblemAsync(await _node.CreateClient().PostAsJsonAsync("/api/v1/sales", insufficient), HttpStatusCode.Unauthorized, "auth.required");
        foreach (var kind in new[] { "card", "transfer" })
            await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/sales", insufficient with
            { SaleId = Guid.NewGuid(), Tenders = [new(1, kind, 120000)] }), HttpStatusCode.UnprocessableEntity, "rule.51509");
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/sales", insufficient with
            { SaleId = Guid.NewGuid(), CustomerId = new Guid("00000000-0000-0000-0000-00000000C052"), Tenders = [new(1, "credit", 120000, CreditId: ret.CreditId)] }),
            HttpStatusCode.Conflict, "credit.customer_or_currency");
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/sales", insufficient with
            { SaleId = Guid.NewGuid(), Tenders = [new(1, "card", 120000, Reference: new string('x', 121))] }), HttpStatusCode.UnprocessableEntity, "input.text");
        await HttpAssert.ProblemAsync(await _cashier.GetAsync($"/api/v1/reports/day?date={Today}"), HttpStatusCode.Forbidden, "auth.role_required");
        var report = await HttpAssert.OkAsync<DayReport>(await _supervisor.GetAsync($"/api/v1/reports/day?date={Today}"));
        Assert.Equal((2, 3L, 360000L), (report.SalesCount, report.UnitsSold, Assert.Single(report.Totals).TotalMinor));
        Assert.Equal(5, report.Tenders.Length); Assert.Equal(120000L, Assert.Single(report.Returns).CreditMinor);
        Assert.Equal(3L, Assert.Single(report.TopItems).UnitsSold); Assert.Null(Assert.Single(report.Tills).CountedMinor);
        var count = new RecordCashCountRequest(Guid.NewGuid(), [new(10000, 34)]);
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync($"/api/v1/cash/tills/{till}/counts", count));
        await HttpAssert.OkAsync(await _supervisor.PostAsJsonAsync($"/api/v1/cash/tills/{till}/close", new CloseTillRequest(Guid.NewGuid(), count.CashCountId)));
        report = await HttpAssert.OkAsync<DayReport>(await _supervisor.GetAsync($"/api/v1/reports/day?date={Today}"));
        var closed = Assert.Single(report.Tills);
        Assert.Equal(("closed", 340000L, 340000L, 0L, 360000L, 120000L, 240000L), (closed.Status, closed.ExpectedMinor, closed.CountedMinor, closed.DifferenceMinor, closed.SaleGrossMinor, closed.ReturnGrossMinor, closed.NetSalesMinor));
        Assert.NotNull(closed.AccountingDocumentId);
        var empty = await HttpAssert.OkAsync<DayReport>(await _supervisor.GetAsync("/api/v1/reports/day?date=2000-01-01"));
        Assert.Equal(0, empty.SalesCount); Assert.Empty(empty.Tills); Assert.Empty(empty.Totals);
        await TestSql.AssertConservationAsync(_db);
    }
}
