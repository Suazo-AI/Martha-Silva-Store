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

    private static readonly Guid Customer = new("00000000-0000-0000-0000-00000000C051");
    private static string Today => DateTime.UtcNow.AddHours(-6).ToString("yyyy-MM-dd");
    private async Task<Guid> OpenTill()
    {
        await Exec($"EXEC test.SeedStock @ItemId='{Ids.Item}',@LocationId='{Ids.LocA}',@Quantity=20;");
        var till = Guid.NewGuid();
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync("/api/v1/cash/tills", new OpenTillRequest(till, Ids.RegisterA, "NIO", 100000)));
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
