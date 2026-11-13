using System.Net;
using System.Net.Http.Json;
using Savia.Contracts;

namespace Savia.Tests;

/// <summary>
/// Many requests at the same moment, through HTTP, against SQL Server 2022.
/// These are the cases a single-session SQL script cannot reach: races for the last unit,
/// the same request sent twice at once, and two people closing the same till.
/// </summary>
public sealed class ConcurrencyTests : IAsyncLifetime
{
    private string _database = "";
    private SaviaNode _branchA = null!;
    private HttpClient _cashier = null!;
    private HttpClient _supervisor = null!;

    public async Task InitializeAsync()
    {
        _database = await TestSql.CloneAsync("race");
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
    public async Task Sixty_parallel_sales_of_thirty_units_sell_exactly_thirty()
    {
        await SeedStockAsync(30);
        var till = await OpenTillAsync();

        var responses = await Task.WhenAll(Enumerable.Range(0, 60).Select(_ => _cashier.PostAsJsonAsync("/api/v1/sales", OneUnit(Guid.NewGuid(), till))));
        var bodies = await Task.WhenAll(responses.Select(r => r.Content.ReadAsStringAsync()));

        var sold = responses.Count(r => r.StatusCode == HttpStatusCode.OK);
        var noStock = bodies.Count(b => b.Contains("\"stock.insufficient\""));
        var other = responses.Zip(bodies).Where(x => x.First.StatusCode != HttpStatusCode.OK && !x.Second.Contains("\"stock.insufficient\""))
            .Select(x => $"{(int)x.First.StatusCode} {x.Second}").Distinct().ToArray();
        Assert.True(other.Length == 0, "unexpected answers: " + string.Join(" | ", other));
        Assert.Equal((30, 30), (sold, noStock));
        Assert.Equal(0, await TestSql.ScalarAsync<int>(_database, $"SELECT OnHand FROM inventory.StockBalances WHERE ItemId='{Ids.Item}' AND Pool='store'"));
        Assert.Equal(30, await TestSql.ScalarAsync<int>(_database, "SELECT COUNT(*) FROM sales.Sales"));
        Assert.Equal(30 * 120_000L, await TestSql.ScalarAsync<long>(_database, "SELECT SUM(DeltaMinor) FROM sales.CashEntries WHERE Kind='sale'"));
        await TestSql.AssertConservationAsync(_database);
    }

    [Fact]
    public async Task The_same_sale_sent_twenty_times_at_once_is_posted_once()
    {
        await SeedStockAsync(5);
        var till = await OpenTillAsync();
        var sale = OneUnit(Guid.NewGuid(), till);

        var responses = await Task.WhenAll(Enumerable.Range(0, 20).Select(_ => _cashier.PostAsJsonAsync("/api/v1/sales", sale)));
        var answers = await Task.WhenAll(responses.Select(async r => $"{(int)r.StatusCode} {await r.Content.ReadAsStringAsync()}"));

        Assert.True(responses.All(r => r.StatusCode == HttpStatusCode.OK), "every retry must succeed: " + string.Join(" | ", answers.Distinct()));
        Assert.Single(answers.Distinct());                                   // and every retry gets the same answer
        Assert.Equal(1, await TestSql.ScalarAsync<int>(_database, "SELECT COUNT(*) FROM sales.Sales"));
        Assert.Equal(4, await TestSql.ScalarAsync<int>(_database, $"SELECT OnHand FROM inventory.StockBalances WHERE ItemId='{Ids.Item}' AND Pool='store'"));
        await TestSql.AssertConservationAsync(_database);
    }

    [Fact]
    public async Task Parallel_scans_count_each_scan_id_once()
    {
        var session = Guid.NewGuid();
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync("/api/v1/receiving/sessions",
            new OpenScanSessionRequest(Guid.NewGuid(), session, "CONT-RACE", Ids.Supplier)));
        var scans = Enumerable.Range(0, 100).Select(_ => new RecordScanRequest(Guid.NewGuid(), Ids.ItemBarcode)).ToArray();

        // Two scanners send every reading at the same time: 200 requests, 100 distinct scan ids.
        var responses = await Task.WhenAll(scans.Concat(scans).Select(s => _cashier.PostAsJsonAsync($"/api/v1/receiving/sessions/{session}/scans", s)));
        var failed = (await Task.WhenAll(responses.Where(r => !r.IsSuccessStatusCode)
            .Select(async r => $"{(int)r.StatusCode} {await r.Content.ReadAsStringAsync()}"))).Distinct().ToArray();
        Assert.True(failed.Length == 0, "unexpected answers: " + string.Join(" | ", failed));

        var progress = await HttpAssert.OkAsync<ScanSessionProgress>(await _cashier.GetAsync($"/api/v1/receiving/sessions/{session}"));
        Assert.Equal((100, 100L), (progress.ScanEvents, progress.MatchedUnits));
        await HttpAssert.OkAsync(await _supervisor.PostAsync($"/api/v1/receiving/sessions/{session}/approve", null));

        // Ten people press "post" at once: one receipt, stock added once.
        var posts = await Task.WhenAll(Enumerable.Range(0, 10).Select(_ => _supervisor.PostAsync($"/api/v1/receiving/sessions/{session}/post", null)));
        var receipts = await Task.WhenAll(posts.Select(HttpAssert.OkAsync<PostScanSessionResponse>));
        Assert.Single(receipts.Select(r => r.ReceiptId).Distinct());
        Assert.Equal(100, await TestSql.ScalarAsync<int>(_database, $"SELECT OnHand FROM inventory.StockBalances WHERE ItemId='{Ids.Item}' AND Pool='store'"));
        await TestSql.AssertConservationAsync(_database);
    }

    [Fact]
    public async Task Ten_parallel_closes_of_one_till_close_it_once()
    {
        await SeedStockAsync(3);
        var till = await OpenTillAsync();
        await HttpAssert.OkAsync<SaleResponse>(await _cashier.PostAsJsonAsync("/api/v1/sales", OneUnit(Guid.NewGuid(), till)));
        var count = new RecordCashCountRequest(Guid.NewGuid(), [new CashCountLine(10_000, 17)]);     // 50000 opening + 120000 sale
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync($"/api/v1/cash/tills/{till}/counts", count));
        var close = new CloseTillRequest(Guid.NewGuid(), count.CashCountId);

        var responses = await Task.WhenAll(Enumerable.Range(0, 10).Select(_ => _supervisor.PostAsJsonAsync($"/api/v1/cash/tills/{till}/close", close)));
        var answers = await Task.WhenAll(responses.Select(async r => $"{(int)r.StatusCode} {await r.Content.ReadAsStringAsync()}"));

        Assert.True(responses.All(r => r.StatusCode == HttpStatusCode.OK), "every retry of the same close must succeed: " + string.Join(" | ", answers.Distinct()));
        Assert.Equal(1, await TestSql.ScalarAsync<int>(_database, "SELECT COUNT(*) FROM sales.CashClosures"));
        Assert.Equal(1, await TestSql.ScalarAsync<int>(_database, "SELECT COUNT(*) FROM accounting.CloseDocuments"));
        await TestSql.AssertConservationAsync(_database);
    }

    [Fact]
    public async Task Ten_parallel_opens_of_one_till_open_it_once()
    {
        var open = new OpenTillRequest(Guid.NewGuid(), Ids.RegisterA, "NIO", 50_000, [new(50000, 1)]);

        var responses = await Task.WhenAll(Enumerable.Range(0, 10).Select(_ => _cashier.PostAsJsonAsync("/api/v1/cash/tills", open)));
        var answers = await Task.WhenAll(responses.Select(async r => $"{(int)r.StatusCode} {await r.Content.ReadAsStringAsync()}"));

        Assert.True(responses.All(r => r.IsSuccessStatusCode), "every retry of the same opening must succeed: " + string.Join(" | ", answers.Distinct()));
        Assert.Equal(1, await TestSql.ScalarAsync<int>(_database, "SELECT COUNT(*) FROM sales.CashTills"));
        Assert.Equal(50_000L, await TestSql.ScalarAsync<long>(_database, "SELECT SUM(DeltaMinor) FROM sales.CashEntries WHERE Kind='opening'"));
        await TestSql.AssertConservationAsync(_database);
    }

    private static PostSaleRequest OneUnit(Guid saleId, Guid till) => new(saleId, till, "NIO",
        [new SaleLine(1, Ids.Item, 1, 120_000)], [new SaleTender(1, "cash", 120_000, ReceivedMinor: 120_000, ChangeMinor: 0)]);

    private async Task<Guid> OpenTillAsync()
    {
        var till = Guid.NewGuid();
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync("/api/v1/cash/tills", new OpenTillRequest(till, Ids.RegisterA, "NIO", 50_000, [new(50000, 1)])));
        return till;
    }

    private Task SeedStockAsync(int units) => TestSql.ScalarAsync<int>(_database, $"""
        DECLARE @item uniqueidentifier='{Ids.Item}',@loc uniqueidentifier='{Ids.LocA}';
        EXEC test.SeedStock @item,@loc,{units};
        SELECT 1;
        """);
}
