using System.Net;
using System.Net.Http.Json;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Tests;

public sealed class LocalCatalogRejectTests : IAsyncLifetime
{
    private string _database = "";
    private SaviaNode _node = null!;
    private HttpClient _manager = null!;
    private HttpClient _cashier = null!;
    private HttpClient _owner = null!;

    public async Task InitializeAsync()
    {
        _database = await TestSql.CloneAsync("localcatalog");
        _node = new SaviaNode(_database, NodeKind.Branch, Ids.NodeA, Ids.BranchA, Ids.LocA,
            new Dictionary<string, string?> { ["Savia:Pilot:LocalCatalog"] = "true" });
        _manager = await _node.SignInAsync(Ids.SupervisorA, "t_super_a");
        _owner = await _node.SignInAsync(Ids.Manager, "t_manager");
        _cashier = await _node.SignInAsync(Ids.CashierA, "t_cashier_a");
    }

    public async Task DisposeAsync()
    {
        await _node.DisposeAsync();
        await TestSql.DropAsync(_database);
    }

    private async Task<Guid> SessionAsync()
    {
        var session = Guid.NewGuid();
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync("/api/v1/receiving/sessions",
            new OpenScanSessionRequest(Guid.NewGuid(), session, $"REJECT-{session:N}", Ids.Supplier)));
        return session;
    }

    private async Task<ScanResult> ScanAsync(Guid session, string code) =>
        await HttpAssert.OkAsync<ScanResult>(await _cashier.PostAsJsonAsync($"/api/v1/receiving/sessions/{session}/scans",
            new RecordScanRequest(Guid.NewGuid(), code)));

    [Theory]
    [InlineData(null)]
    [InlineData("false")]
    public async Task Branch_catalog_stays_absent_unless_enabled(string? flag)
    {
        await using var branch = new SaviaNode(_database, NodeKind.Branch, Ids.NodeA, Ids.BranchA, Ids.LocA,
            new Dictionary<string, string?> { ["Savia:Pilot:LocalCatalog"] = flag });
        var client = await branch.SignInAsync(Ids.SupervisorA, "t_super_a");
        Assert.Equal(HttpStatusCode.NotFound, (await client.PostAsJsonAsync("/api/v1/catalog/products", new { productId = Guid.NewGuid(), name = "Test" })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.PostAsJsonAsync("/api/v1/catalog/items", new { })).StatusCode);
    }

    [Fact]
    public async Task Local_catalog_requires_manager_and_branch_access()
    {
        var product = new RegisterProductRequest(Guid.NewGuid(), "Local sample");
        var item = new RegisterItemRequest(Guid.NewGuid(), product.ProductId, "LOCAL-SKU", "Local sample", "NIO", 50000, 20000, "UNKNOWN-LOCAL");
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/catalog/products", product), HttpStatusCode.Forbidden, "auth.role_required");
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/catalog/items", item), HttpStatusCode.Forbidden, "auth.role_required");
        var outsider = await _node.SignInAsync(new Guid("B0000000-0000-0000-0000-0000000000B5"), "t_super_b");
        await HttpAssert.ProblemAsync(await outsider.PostAsJsonAsync("/api/v1/catalog/products", product), HttpStatusCode.Forbidden, "auth.branch_access");
        await HttpAssert.ProblemAsync(await outsider.PostAsJsonAsync("/api/v1/catalog/items", item), HttpStatusCode.Forbidden, "auth.branch_access");
        await HttpAssert.OkAsync(await _manager.PostAsJsonAsync("/api/v1/catalog/products", product));
        await HttpAssert.OkAsync(await _owner.PostAsJsonAsync("/api/v1/catalog/items", item));
        // Existing procedure retries and barcode ownership rules still apply.
        await HttpAssert.OkAsync(await _owner.PostAsJsonAsync("/api/v1/catalog/items", item));
        await HttpAssert.ProblemAsync(await _owner.PostAsJsonAsync("/api/v1/catalog/items", item with { ItemId = Guid.NewGuid(), Sku = "OTHER" }), HttpStatusCode.Conflict, "catalog.code_taken");
    }

    [Theory]
    [InlineData("false")]
    [InlineData("true")]
    public async Task Cloud_catalog_keeps_its_existing_permissions(string flag)
    {
        await using var cloud = new SaviaNode(_database, NodeKind.Cloud, Ids.NodeCloud, null, null,
            new Dictionary<string, string?> { ["Savia:Pilot:LocalCatalog"] = flag });
        var manager = await cloud.SignInAsync(Ids.Manager, "t_manager");
        var cashier = await cloud.SignInAsync(Ids.CashierA, "t_cashier_a");
        var product = new RegisterProductRequest(Guid.NewGuid(), "Cloud sample");
        var item = new RegisterItemRequest(Guid.NewGuid(), product.ProductId, "CLOUD-SKU", "Cloud sample", "NIO", 50000, 20000, "CLOUD-BARCODE");
        await HttpAssert.ProblemAsync(await cashier.PostAsJsonAsync("/api/v1/catalog/products", product), HttpStatusCode.Forbidden, "auth.role_required");
        await HttpAssert.ProblemAsync(await cashier.PostAsJsonAsync("/api/v1/catalog/items", item), HttpStatusCode.Forbidden, "auth.role_required");
        await HttpAssert.OkAsync(await manager.PostAsJsonAsync("/api/v1/catalog/products", product));
        await HttpAssert.OkAsync(await manager.PostAsJsonAsync("/api/v1/catalog/items", item));
    }

    [Fact]
    public async Task Reject_endpoint_authorizes_scopes_audits_and_posts_only_matched_units()
    {
        var session = await SessionAsync();
        var matched = await ScanAsync(session, Ids.ItemBarcode);
        var unknown = await ScanAsync(session, "REJECT-UNKNOWN");
        var url = $"/api/v1/receiving/sessions/{session}/scans/{unknown.ScanId}/reject";
        await HttpAssert.ProblemAsync(await _node.CreateClient().PostAsJsonAsync(url, new { reason = "bad label" }), HttpStatusCode.Unauthorized, "auth.required");
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync(url, new { reason = "bad label" }), HttpStatusCode.Forbidden, "auth.role_required");
        var outsider = await _node.SignInAsync(new Guid("B0000000-0000-0000-0000-0000000000B5"), "t_super_b");
        await HttpAssert.ProblemAsync(await outsider.PostAsJsonAsync(url, new { reason = "bad label" }), HttpStatusCode.Forbidden, "auth.branch_access");
        await HttpAssert.ProblemAsync(await _manager.PostAsJsonAsync(url, new { reason = " " }), HttpStatusCode.UnprocessableEntity, "input.text");
        await HttpAssert.ProblemAsync(await _manager.PostAsJsonAsync(url, new { reason = new string('x', 251) }), HttpStatusCode.UnprocessableEntity, "input.text");
        await HttpAssert.ProblemAsync(await _manager.PostAsJsonAsync($"/api/v1/receiving/sessions/{session}/scans/{matched.ScanId}/reject", new { reason = "matched" }), HttpStatusCode.Conflict, "receiving.scan_not_rejectable");
        await HttpAssert.ProblemAsync(await _manager.PostAsJsonAsync($"/api/v1/receiving/sessions/{session}/scans/{Guid.NewGuid()}/reject", new { reason = "missing" }), HttpStatusCode.NotFound, "receiving.scan_not_found");
        var otherSession = await SessionAsync();
        await HttpAssert.ProblemAsync(await _manager.PostAsJsonAsync($"/api/v1/receiving/sessions/{otherSession}/scans/{unknown.ScanId}/reject", new { reason = "wrong session" }), HttpStatusCode.NotFound, "receiving.scan_not_found");
        await HttpAssert.ProblemAsync(await _manager.PostAsJsonAsync($"/api/v1/receiving/sessions/{Guid.NewGuid()}/scans/{unknown.ScanId}/reject", new { reason = "missing" }), HttpStatusCode.NotFound, "receiving.session_not_found");
        await HttpAssert.OkAsync(await _manager.PostAsJsonAsync(url, new { reason = "bad label" }));
        await HttpAssert.OkAsync(await _manager.PostAsJsonAsync(url, new { reason = "retry" }));
        Assert.Equal("bad label", await TestSql.ScalarAsync<string>(_database, $"SELECT ResolutionReason FROM receiving.ScanEvents WHERE Id='{unknown.ScanId}' AND ModifiedBy='{Ids.SupervisorA}' AND ModifiedAt IS NOT NULL"));
        var lines = await HttpAssert.OkAsync<ScanSessionLine[]>(await _manager.GetAsync($"/api/v1/receiving/sessions/{session}/lines"));
        Assert.Equal("rejected", Assert.Single(lines, l => l.ScanId == unknown.ScanId).MatchStatus);
        var progress = await HttpAssert.OkAsync<ScanSessionProgress>(await _manager.GetAsync($"/api/v1/receiving/sessions/{session}"));
        Assert.Equal(0, progress.UnitsPendingReview);
        await HttpAssert.OkAsync(await _manager.PostAsync($"/api/v1/receiving/sessions/{session}/approve", null));
        await HttpAssert.ProblemAsync(await _manager.PostAsJsonAsync(url, new { reason = "closed" }), HttpStatusCode.Conflict, "receiving.session_not_counting");
        await HttpAssert.OkAsync<PostScanSessionResponse>(await _manager.PostAsync($"/api/v1/receiving/sessions/{session}/post", null));
        await TestSql.AssertConservationAsync(_database);
    }

    [Fact]
    public async Task Unknown_code_registered_via_local_api_resolves_and_becomes_stock()
    {
        var session = await SessionAsync();
        var unknown = await ScanAsync(session, "NEW-LOCAL-BARCODE");
        Assert.Equal("unknown", unknown.MatchStatus);
        var product = new RegisterProductRequest(Guid.NewGuid(), "New sample");
        var item = new RegisterItemRequest(Guid.NewGuid(), product.ProductId, "NEW-SAMPLE", "New sample", "NIO", 50000, 20000, "NEW-LOCAL-BARCODE");
        await HttpAssert.OkAsync(await _manager.PostAsJsonAsync("/api/v1/catalog/products", product));
        await HttpAssert.OkAsync(await _owner.PostAsJsonAsync("/api/v1/catalog/items", item));
        await HttpAssert.OkAsync(await _manager.PostAsJsonAsync($"/api/v1/receiving/sessions/{session}/scans/{unknown.ScanId}/resolve", new ResolveScanRequest(item.ItemId, "registered locally")));
        var line = Assert.Single(await HttpAssert.OkAsync<ScanSessionLine[]>(await _manager.GetAsync($"/api/v1/receiving/sessions/{session}/lines")));
        Assert.Equal((item.ItemId, "matched", 1L), (line.ItemId!.Value, line.MatchStatus, line.Quantity));
        await HttpAssert.OkAsync(await _manager.PostAsync($"/api/v1/receiving/sessions/{session}/approve", null));
        await HttpAssert.OkAsync<PostScanSessionResponse>(await _manager.PostAsync($"/api/v1/receiving/sessions/{session}/post", null));
        var stock = Assert.Single(await HttpAssert.OkAsync<StockRow[]>(await _manager.GetAsync($"/api/v1/stock?itemId={item.ItemId}")));
        Assert.Equal(1, stock.OnHand);
        await TestSql.AssertConservationAsync(_database);
    }
}
