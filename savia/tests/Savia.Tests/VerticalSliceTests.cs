using System.Net;
using System.Net.Http.Json;
using Savia.Contracts;

namespace Savia.Tests;

/// <summary>
/// The first vertical slice, end to end through HTTP against SQL Server 2022:
/// scan a supplier code -> receive N units -> label job -> sell -> count and close the till.
/// The branch node has no cloud configured at all, so every step proves it works offline.
/// </summary>
public sealed class VerticalSliceTests : IAsyncLifetime
{
    private string _database = "";
    private SaviaNode _branchA = null!;
    private HttpClient _cashier = null!;
    private HttpClient _supervisor = null!;

    public async Task InitializeAsync()
    {
        _database = await TestSql.CloneAsync("slice");
        _branchA = SaviaNode.BranchA(_database);
        _cashier = await _branchA.SignInAsync(Ids.CashierA, "t_cashier_a");
        _supervisor = await _branchA.SignInAsync(Ids.SupervisorA, "t_super_a");
    }

    public async Task DisposeAsync()
    {
        await _branchA.DisposeAsync();
        await TestSql.DropAsync(_database);
    }

    [Fact]
    public async Task Receive_100_scans_sell_offline_and_close_the_till()
    {
        // --- receive: 100 readings of one code, every 10th sent twice (the scanner did not get the reply)
        var session = Guid.NewGuid();
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync("/api/v1/receiving/sessions",
            new OpenScanSessionRequest(Guid.NewGuid(), session, "CONT-SLICE-1", Ids.Supplier, "SCAN-01")));
        for (var i = 0; i < 100; i++)
        {
            var scan = new RecordScanRequest(Guid.NewGuid(), Ids.ItemBarcode);
            var first = await HttpAssert.OkAsync<ScanResult>(await _cashier.PostAsJsonAsync($"/api/v1/receiving/sessions/{session}/scans", scan));
            Assert.Equal("matched", first.MatchStatus);
            Assert.Equal(Ids.Item, first.ItemId);
            if (i % 10 != 0) continue;
            var retry = await HttpAssert.OkAsync<ScanResult>(await _cashier.PostAsJsonAsync($"/api/v1/receiving/sessions/{session}/scans", scan));
            Assert.Equal(first, retry);
        }
        var progress = await HttpAssert.OkAsync<ScanSessionProgress>(await _cashier.GetAsync($"/api/v1/receiving/sessions/{session}"));
        Assert.Equal((100, 100L, 0L), (progress.ScanEvents, progress.MatchedUnits, progress.UnitsPendingReview));
        Assert.Empty(await StockAsync());                                    // a reading alone never adds stock

        // --- only a manager approves and posts; posting twice gives the same receipt
        await HttpAssert.ProblemAsync(await _cashier.PostAsync($"/api/v1/receiving/sessions/{session}/approve", null),
            HttpStatusCode.Forbidden, "auth.role_required");
        await HttpAssert.ProblemAsync(await _supervisor.PostAsync($"/api/v1/receiving/sessions/{session}/post", null),
            HttpStatusCode.Conflict, "receiving.not_approved");
        await HttpAssert.OkAsync(await _supervisor.PostAsync($"/api/v1/receiving/sessions/{session}/approve", null));
        var receipt = await HttpAssert.OkAsync<PostScanSessionResponse>(await _supervisor.PostAsync($"/api/v1/receiving/sessions/{session}/post", null));
        var again = await HttpAssert.OkAsync<PostScanSessionResponse>(await _supervisor.PostAsync($"/api/v1/receiving/sessions/{session}/post", null));
        Assert.Equal(receipt.ReceiptId, again.ReceiptId);
        var stock = Assert.Single(await StockAsync());
        Assert.Equal(("store", 100, 100), (stock.Pool, stock.OnHand, stock.Available));
        Assert.Equal(1, await TestSql.ScalarAsync<int>(_database, "SELECT COUNT(*) FROM purchasing.GoodsReceiptLines"));

        // --- label job: original supplier code, barcode with its leading zeros, store name, one copy per unit
        var jobs = await HttpAssert.OkAsync<LabelJob[]>(await _cashier.GetAsync("/api/v1/labels/jobs"));
        var job = Assert.Single(jobs);
        Assert.Equal(("PROV-0001", Ids.ItemBarcode, "SAVIA Test", 100), (job.Sku, job.Barcode, job.StoreName, job.CopiesRequested));
        Assert.Equal("waiting_config", job.Status);                           // no printer configured: visible, not lost

        // --- sell: two units, cash. The same request again changes nothing.
        var till = Guid.NewGuid();
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync("/api/v1/cash/tills", new OpenTillRequest(till, Ids.RegisterA, "NIO", 100_000, [new(100000, 1)])));
        var sale = new PostSaleRequest(Guid.NewGuid(), till, "NIO",
            [new SaleLine(1, Ids.Item, 2, 120_000)],
            [new SaleTender(1, "cash", 240_000, ReceivedMinor: 300_000, ChangeMinor: 60_000)]);
        var posted = await HttpAssert.OkAsync<SaleResponse>(await _cashier.PostAsJsonAsync("/api/v1/sales", sale));
        Assert.Equal((240_000L, "recorded"), (posted.TotalMinor, posted.Status));
        Assert.Equal(posted, await HttpAssert.OkAsync<SaleResponse>(await _cashier.PostAsJsonAsync("/api/v1/sales", sale)));
        Assert.Equal(98, Assert.Single(await StockAsync()).OnHand);

        // The sale is durable locally and waits for the cloud: one event, routed to the cloud node, still pending.
        Assert.Equal(1, await TestSql.ScalarAsync<int>(_database, $"""
            SELECT COUNT(*) FROM sync.Outbox o JOIN sync.EventDeliveries d ON d.EventId=o.EventId
            WHERE o.AggregateId='{sale.SaleId}' AND o.EventType='sales.sale_posted' AND d.Status='pending'
              AND d.DestinationNodeId='{Ids.NodeCloud}'
            """));

        // --- rejected sales leave nothing behind
        var tooMany = sale with
        {
            SaleId = Guid.NewGuid(),
            Lines = [new SaleLine(1, Ids.Item, 1_000, 120_000)],
            Tenders = [new SaleTender(1, "cash", 120_000_000, ReceivedMinor: 120_000_000, ChangeMinor: 0)]
        };
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/sales", tooMany), HttpStatusCode.Conflict, "stock.insufficient");
        var changed = sale with
        {
            Lines = [new SaleLine(1, Ids.Item, 1, 120_000)],
            Tenders = [new SaleTender(1, "cash", 120_000, ReceivedMinor: 120_000, ChangeMinor: 0)]
        };
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/sales", changed), HttpStatusCode.Conflict, "sale.id_reused");
        Assert.Equal(98, Assert.Single(await StockAsync()).OnHand);
        Assert.Equal(1, await TestSql.ScalarAsync<int>(_database, "SELECT COUNT(*) FROM sales.Sales"));

        // --- count and close: expected = opening 100000 + cash sale 240000
        var count = new RecordCashCountRequest(Guid.NewGuid(), [new CashCountLine(100_000, 3), new CashCountLine(10_000, 4)]);
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync($"/api/v1/cash/tills/{till}/counts", count));
        var close = new CloseTillRequest(Guid.NewGuid(), count.CashCountId);
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync($"/api/v1/cash/tills/{till}/close", close),
            HttpStatusCode.Forbidden, "auth.role_required");
        var closure = await HttpAssert.OkAsync<CloseTillResponse>(await _supervisor.PostAsJsonAsync($"/api/v1/cash/tills/{till}/close", close));
        Assert.Equal((340_000L, 340_000L, 0L), (closure.ExpectedMinor, closure.CountedMinor, closure.DifferenceMinor));
        Assert.Equal(closure, await HttpAssert.OkAsync<CloseTillResponse>(await _supervisor.PostAsJsonAsync($"/api/v1/cash/tills/{till}/close", close)));
        Assert.Equal(1, await TestSql.ScalarAsync<int>(_database, "SELECT COUNT(*) FROM accounting.CloseDocuments"));
        Assert.Equal(1, await TestSql.ScalarAsync<int>(_database, "SELECT COUNT(*) FROM accounting.ExportJobs"));

        // --- a closed till sells nothing
        var late = sale with { SaleId = Guid.NewGuid() };
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/sales", late), HttpStatusCode.Conflict, "cash.till_mismatch");

        // --- after everything, accepted and rejected, the books of the node still add up
        await TestSql.AssertConservationAsync(_database);
    }

    [Fact]
    public async Task Unknown_code_is_recorded_but_never_becomes_stock()
    {
        var session = Guid.NewGuid();
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync("/api/v1/receiving/sessions",
            new OpenScanSessionRequest(Guid.NewGuid(), session, "CONT-UNKNOWN", Ids.Supplier)));
        var scan = await HttpAssert.OkAsync<ScanResult>(await _cashier.PostAsJsonAsync($"/api/v1/receiving/sessions/{session}/scans",
            new RecordScanRequest(Guid.NewGuid(), "0009999999999", 5)));
        Assert.Equal(("unknown", (Guid?)null), (scan.MatchStatus, scan.ItemId));
        await HttpAssert.ProblemAsync(await _supervisor.PostAsync($"/api/v1/receiving/sessions/{session}/approve", null),
            HttpStatusCode.Conflict, "receiving.unresolved_codes");
        Assert.Empty(await StockAsync());
        Assert.Empty(await HttpAssert.OkAsync<ItemLookup[]>(await _cashier.GetAsync("/api/v1/catalog/lookup?code=0009999999999")));
        var known = await HttpAssert.OkAsync<ItemLookup[]>(await _cashier.GetAsync($"/api/v1/catalog/lookup?code={Ids.ItemBarcode}"));
        Assert.Equal(Ids.Item, Assert.Single(known).ItemId);
        await TestSql.AssertConservationAsync(_database);
    }

    [Fact]
    public async Task Staff_of_another_branch_cannot_operate_this_branch()
    {
        // Cashier B has a valid account, but this host serves branch A only.
        var cashierB = await _branchA.SignInAsync(Ids.CashierB, "t_cashier_b");
        await HttpAssert.ProblemAsync(await cashierB.PostAsJsonAsync("/api/v1/cash/tills",
            new OpenTillRequest(Guid.NewGuid(), Ids.RegisterA, "NIO", 0, [new(100000, 0)])), HttpStatusCode.Forbidden, "auth.branch_access");
        await HttpAssert.ProblemAsync(await cashierB.GetAsync("/api/v1/stock"), HttpStatusCode.Forbidden, "auth.branch_access");
        await HttpAssert.ProblemAsync(await cashierB.PostAsJsonAsync("/api/v1/receiving/sessions",
            new OpenScanSessionRequest(Guid.NewGuid(), Guid.NewGuid(), "CONT-B", Ids.Supplier)), HttpStatusCode.Forbidden, "auth.branch_access");

        // Cashier A cannot open a till on a register of branch B through the branch A host.
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/cash/tills",
            new OpenTillRequest(Guid.NewGuid(), Ids.RegisterB, "NIO", 0, [new(100000, 0)])), HttpStatusCode.NotFound, "cash.register_not_found");
        Assert.Equal(0, await TestSql.ScalarAsync<int>(_database, "SELECT COUNT(*) FROM sales.CashTills"));
    }

    [Fact]
    public async Task Calls_without_a_valid_session_are_rejected()
    {
        var anonymous = _branchA.CreateClient();
        await HttpAssert.ProblemAsync(await anonymous.GetAsync("/api/v1/me"), HttpStatusCode.Unauthorized, "auth.required");
        await HttpAssert.ProblemAsync(await anonymous.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest("t_cashier_a", "wrong-password-1")),
            HttpStatusCode.Unauthorized, "auth.bad_credentials");
        await HttpAssert.ProblemAsync(await anonymous.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest("nobody", Ids.Password)),
            HttpStatusCode.Unauthorized, "auth.bad_credentials");

        var me = await HttpAssert.OkAsync<MeResponse>(await _cashier.GetAsync("/api/v1/me"));
        Assert.Equal((Ids.CashierA, "Branch", Ids.BranchA), (me.StaffId, me.NodeKind, me.BranchId));
        Assert.Equal(["CASHIER"], me.Roles);

        // After logout the same token is dead.
        await HttpAssert.OkAsync(await _cashier.PostAsync("/api/v1/auth/logout", null));
        await HttpAssert.ProblemAsync(await _cashier.GetAsync("/api/v1/me"), HttpStatusCode.Unauthorized, "auth.required");
        // The token is stored only as a hash.
        Assert.Equal(0, await TestSql.ScalarAsync<int>(_database, "SELECT COUNT(*) FROM security.Sessions WHERE TokenHash IS NULL"));
    }

    [Fact]
    public async Task Branch_node_does_not_expose_catalog_writes()
    {
        var response = await _supervisor.PostAsJsonAsync("/api/v1/catalog/products", new RegisterProductRequest(Guid.NewGuid(), "Falda"));
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal(0, await TestSql.ScalarAsync<int>(_database, "SELECT COUNT(*) FROM catalog.Products WHERE Name=N'Falda'"));
    }

    private async Task<StockRow[]> StockAsync() =>
        await HttpAssert.OkAsync<StockRow[]>(await _cashier.GetAsync($"/api/v1/stock?itemId={Ids.Item}"));
}
