using System.Net;
using System.Net.Http.Json;
using Microsoft.Data.SqlClient;
using Savia.Contracts;

namespace Savia.Tests;

/// <summary>
/// Read endpoints the pilot browser client needs (search, session list and lines, registers, till summary, me),
/// the reviewer's resolve call and static hosting. Each group has at least one authorization failure.
/// </summary>
public sealed class PilotEndpointsTests : IAsyncLifetime
{
    private string _database = "";
    private SaviaNode _branchA = null!;
    private HttpClient _cashier = null!;
    private HttpClient _supervisor = null!;

    public async Task InitializeAsync()
    {
        _database = await TestSql.CloneAsync("pilot");
        _branchA = SaviaNode.BranchA(_database);
        _cashier = await _branchA.SignInAsync(Ids.CashierA, "t_cashier_a");
        _supervisor = await _branchA.SignInAsync(Ids.SupervisorA, "t_super_a");
    }

    public async Task DisposeAsync()
    {
        await _branchA.DisposeAsync();
        await TestSql.DropAsync(_database);
    }

    private async Task ExecAsync(string sql)
    {
        await using var connection = new SqlConnection(TestSql.ConnectionFor(_database));
        await connection.OpenAsync();
        await using var command = new SqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync();
    }

    [Fact]
    public async Task Search_matches_name_sku_and_code_fragments_with_local_stock()
    {
        await ExecAsync($"EXEC test.SeedStock @ItemId='{Ids.Item}',@LocationId='{Ids.LocA}',@Quantity=7;");

        var byName = await HttpAssert.OkAsync<ProductSearchRow[]>(await _cashier.GetAsync("/api/v1/catalog/search?q=bl%C3%BAsa"));
        Assert.Equal(3, byName.Length);                                     // accent- and case-insensitive
        var item = Assert.Single(byName, r => r.ItemId == Ids.Item);
        Assert.Equal(("T-SKU-0001", "Blusa Test", "M", Ids.ItemBarcode, 120_000L, "NIO", "active", (int?)7, (int?)7),
            (item.Sku, item.ProductName, item.SizeCode, item.Barcode, item.UnitPriceMinor, item.CurrencyCode, item.Status, item.OnHand, item.Available));
        Assert.Equal((int?)0, Assert.Single(byName, r => r.Sku == "T-SKU-0002").OnHand);

        Assert.Equal("T-SKU-0002", Assert.Single(await HttpAssert.OkAsync<ProductSearchRow[]>(
            await _cashier.GetAsync("/api/v1/catalog/search?q=sku-0002"))).Sku);
        Assert.Equal(Ids.Item, Assert.Single(await HttpAssert.OkAsync<ProductSearchRow[]>(
            await _cashier.GetAsync("/api/v1/catalog/search?q=PROV-00"))).ItemId);   // supplier code fragment
        Assert.Equal(Ids.Item, Assert.Single(await HttpAssert.OkAsync<ProductSearchRow[]>(
            await _cashier.GetAsync("/api/v1/catalog/search?q=1234567"))).ItemId);   // barcode fragment
        Assert.Empty(await HttpAssert.OkAsync<ProductSearchRow[]>(await _cashier.GetAsync("/api/v1/catalog/search?q=T%25SKU")));
        Assert.Single(await HttpAssert.OkAsync<ProductSearchRow[]>(await _cashier.GetAsync("/api/v1/catalog/search?q=blusa&limit=1")));
        await HttpAssert.ProblemAsync(await _cashier.GetAsync("/api/v1/catalog/search?q=b"),
            HttpStatusCode.UnprocessableEntity, "catalog.search_too_short");

        var cashierB = await _branchA.SignInAsync(Ids.CashierB, "t_cashier_b");
        await HttpAssert.ProblemAsync(await cashierB.GetAsync("/api/v1/catalog/search?q=blusa"), HttpStatusCode.Forbidden, "auth.branch_access");
        await HttpAssert.ProblemAsync(await _branchA.CreateClient().GetAsync("/api/v1/catalog/search?q=blusa"),
            HttpStatusCode.Unauthorized, "auth.required");

        // The cloud has no location: stock is null. A cashier has no business searching the whole catalog there.
        await using var cloud = SaviaNode.Cloud(_database);
        var manager = await cloud.SignInAsync(Ids.Manager, "t_manager");
        var cloudRow = Assert.Single(await HttpAssert.OkAsync<ProductSearchRow[]>(await manager.GetAsync("/api/v1/catalog/search?q=T-SKU-0001")));
        Assert.Null(cloudRow.OnHand);
        var cloudCashier = await cloud.SignInAsync(Ids.CashierA, "t_cashier_a");
        await HttpAssert.ProblemAsync(await cloudCashier.GetAsync("/api/v1/catalog/search?q=blusa"), HttpStatusCode.Forbidden, "auth.role_required");
    }

    [Fact]
    public async Task Sessions_list_lines_and_a_reviewer_resolves_an_unknown_code()
    {
        var session = Guid.NewGuid();
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync("/api/v1/receiving/sessions",
            new OpenScanSessionRequest(Guid.NewGuid(), session, "CONT-PILOT-1", Ids.Supplier)));
        for (var i = 0; i < 5; i++)
            await HttpAssert.OkAsync<ScanResult>(await _cashier.PostAsJsonAsync($"/api/v1/receiving/sessions/{session}/scans",
                new RecordScanRequest(Guid.NewGuid(), Ids.ItemBarcode)));
        var unknown = await HttpAssert.OkAsync<ScanResult>(await _cashier.PostAsJsonAsync($"/api/v1/receiving/sessions/{session}/scans",
            new RecordScanRequest(Guid.NewGuid(), "0007770001112")));
        Assert.Equal("unknown", unknown.MatchStatus);

        var listed = Assert.Single(await HttpAssert.OkAsync<ScanSessionSummary[]>(await _cashier.GetAsync("/api/v1/receiving/sessions")));
        Assert.Equal((session, "CONT-PILOT-1", "Proveedor Test", 6, 5L, 1L),
            (listed.ScanSessionId, listed.Reference, listed.SupplierName, listed.ScanEvents, listed.MatchedUnits, listed.UnitsPendingReview));

        var lines = await HttpAssert.OkAsync<ScanSessionLine[]>(await _cashier.GetAsync($"/api/v1/receiving/sessions/{session}/lines"));
        Assert.Equal(2, lines.Length);
        Assert.Equal(((Guid?)null, (Guid?)Ids.Item, "matched", 5L, 5, "T-SKU-0001"),
            (lines[0].ScanId, lines[0].ItemId, lines[0].MatchStatus, lines[0].Quantity, lines[0].Scans, lines[0].Sku));
        Assert.Equal(((Guid?)unknown.ScanId, (Guid?)null, "unknown", "0007770001112", 1L),
            (lines[1].ScanId, lines[1].ItemId, lines[1].MatchStatus, lines[1].RawCode, lines[1].Quantity));

        // One unknown code blocks approval until a reviewer ties it to a variant the catalog already knows by that code.
        await HttpAssert.ProblemAsync(await _supervisor.PostAsync($"/api/v1/receiving/sessions/{session}/approve", null),
            HttpStatusCode.Conflict, "receiving.unresolved_codes");
        var resolveUrl = $"/api/v1/receiving/sessions/{session}/scans/{unknown.ScanId}/resolve";
        var newItem = Guid.NewGuid();
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync(resolveUrl, new ResolveScanRequest(Ids.Item, "es la blusa")),
            HttpStatusCode.Forbidden, "auth.role_required");
        await HttpAssert.ProblemAsync(await _supervisor.PostAsJsonAsync(resolveUrl, new ResolveScanRequest(Ids.Item, "es la blusa")),
            HttpStatusCode.Conflict, "receiving.code_not_registered");
        await HttpAssert.ProblemAsync(await _supervisor.PostAsJsonAsync(resolveUrl, new ResolveScanRequest(Ids.Item, " ")),
            HttpStatusCode.UnprocessableEntity, "input.text");
        await HttpAssert.ProblemAsync(await _supervisor.PostAsJsonAsync(
            $"/api/v1/receiving/sessions/{session}/scans/{Guid.NewGuid()}/resolve", new ResolveScanRequest(Ids.Item, "x")),
            HttpStatusCode.NotFound, "receiving.scan_not_found");

        // The cloud catalog registers the new code (ADR-001 D6); here SQL plays the cloud.
        await ExecAsync($"""
            DECLARE @p uniqueidentifier=NEWID(),@e1 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID();
            EXEC catalog.usp_RegisterProduct @ProductId=@p,@Name=N'Falda Test',@ActorId='{Ids.Manager}',@OriginNodeId='{Ids.NodeCloud}',@EventId=@e1;
            EXEC catalog.usp_RegisterItem @ProductId=@p,@Sku=N'T-NEW-0001',@VariantName=N'Falda Test',@CurrencyCode='NIO',
              @UnitPriceMinor=50000,@UnitCostMinor=20000,@Barcode=N'0007770001112',@ActorId='{Ids.Manager}',@ItemId='{newItem}',
              @OriginNodeId='{Ids.NodeCloud}',@EventId=@e2;
            """);
        await HttpAssert.OkAsync(await _supervisor.PostAsJsonAsync(resolveUrl, new ResolveScanRequest(newItem, "codigo nuevo del proveedor")));
        await HttpAssert.OkAsync(await _supervisor.PostAsJsonAsync(resolveUrl, new ResolveScanRequest(newItem, "codigo nuevo del proveedor")));
        lines = await HttpAssert.OkAsync<ScanSessionLine[]>(await _cashier.GetAsync($"/api/v1/receiving/sessions/{session}/lines"));
        Assert.All(lines, l => Assert.Equal("matched", l.MatchStatus));

        await HttpAssert.OkAsync(await _supervisor.PostAsync($"/api/v1/receiving/sessions/{session}/approve", null));
        await HttpAssert.OkAsync<PostScanSessionResponse>(await _supervisor.PostAsync($"/api/v1/receiving/sessions/{session}/post", null));
        Assert.Empty(await HttpAssert.OkAsync<ScanSessionSummary[]>(await _cashier.GetAsync("/api/v1/receiving/sessions")));
        Assert.Equal("posted", Assert.Single(await HttpAssert.OkAsync<ScanSessionSummary[]>(
            await _cashier.GetAsync("/api/v1/receiving/sessions?open=false"))).Status);

        var suppliers = await HttpAssert.OkAsync<SupplierRow[]>(await _cashier.GetAsync("/api/v1/suppliers"));
        Assert.Contains(suppliers, s => s.SupplierId == Ids.Supplier && s.Name == "Proveedor Test");

        var cashierB = await _branchA.SignInAsync(Ids.CashierB, "t_cashier_b");
        await HttpAssert.ProblemAsync(await cashierB.GetAsync("/api/v1/receiving/sessions"), HttpStatusCode.Forbidden, "auth.branch_access");
        await HttpAssert.ProblemAsync(await cashierB.GetAsync($"/api/v1/receiving/sessions/{session}/lines"), HttpStatusCode.Forbidden, "auth.branch_access");
        await HttpAssert.ProblemAsync(await cashierB.GetAsync("/api/v1/suppliers"), HttpStatusCode.Forbidden, "auth.branch_access");
        await TestSql.AssertConservationAsync(_database);
    }

    [Fact]
    public async Task Registers_current_till_and_summary_follow_the_close()
    {
        await ExecAsync($"EXEC test.SeedStock @ItemId='{Ids.Item}',@LocationId='{Ids.LocA}',@Quantity=5;");
        var register = Assert.Single(await HttpAssert.OkAsync<RegisterRow[]>(await _cashier.GetAsync("/api/v1/cash/registers")));
        Assert.Equal((Ids.RegisterA, Ids.LocA, (Guid?)null), (register.RegisterId, register.LocationId, register.OpenTillId));
        await HttpAssert.ProblemAsync(await _cashier.GetAsync("/api/v1/cash/tills/current"), HttpStatusCode.NotFound, "cash.no_open_till");

        var till = Guid.NewGuid();
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync("/api/v1/cash/tills", new OpenTillRequest(till, Ids.RegisterA, "NIO", 100_000,
            [new(100000, 1)])));
        register = Assert.Single(await HttpAssert.OkAsync<RegisterRow[]>(await _cashier.GetAsync("/api/v1/cash/registers")));
        Assert.Equal(((Guid?)till, (Guid?)Ids.CashierA), (register.OpenTillId, register.OpenTillCashierId));
        await HttpAssert.OkAsync<SaleResponse>(await _cashier.PostAsJsonAsync("/api/v1/sales", new PostSaleRequest(Guid.NewGuid(), till, "NIO",
            [new SaleLine(1, Ids.Item, 2, 120_000)], [new SaleTender(1, "cash", 240_000, ReceivedMinor: 250_000, ChangeMinor: 10_000)])));

        var current = await HttpAssert.OkAsync<TillSummary>(await _cashier.GetAsync("/api/v1/cash/tills/current"));
        Assert.Equal((till, "open", "Caja A", "Cajera A", 100_000L, 240_000L, 0L, 0L, 340_000L, 1, 240_000L, (Guid?)null),
            (current.TillId, current.Status, current.RegisterName, current.CashierName, current.OpeningMinor, current.CashSalesMinor,
             current.CashRefundsMinor, current.OtherCashMinor, current.ExpectedCashMinor, current.SaleCount, current.SalesTotalMinor, current.ClosureId));

        var count = new RecordCashCountRequest(Guid.NewGuid(), [new CashCountLine(100_000, 3), new CashCountLine(10_000, 4)],
            UsdCashCountId: Guid.NewGuid(), UsdLines: [new(100, 0)]);
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync($"/api/v1/cash/tills/{till}/counts", count));
        var closure = await HttpAssert.OkAsync<CloseTillResponse>(await _supervisor.PostAsJsonAsync($"/api/v1/cash/tills/{till}/close",
            new CloseTillRequest(Guid.NewGuid(), count.CashCountId, count.UsdCashCountId)));
        var closed = await HttpAssert.OkAsync<TillSummary>(await _supervisor.GetAsync($"/api/v1/cash/tills/{till}/summary"));
        Assert.Equal(("closed", closure.ExpectedMinor, (Guid?)closure.ClosureId), (closed.Status, closed.ExpectedCashMinor, closed.ClosureId));
        await HttpAssert.ProblemAsync(await _cashier.GetAsync("/api/v1/cash/tills/current"), HttpStatusCode.NotFound, "cash.no_open_till");
        await HttpAssert.ProblemAsync(await _supervisor.GetAsync($"/api/v1/cash/tills/{Guid.NewGuid()}/summary"), HttpStatusCode.NotFound,
            "cash.till_not_found");

        // A cashier sees only her own tills; a till of another branch does not exist here.
        await ExecAsync($"""
            INSERT INTO security.StaffBranchAccess(StaffId,BranchId,CanApproveTransfers,CanApproveReturns) VALUES('{Ids.CashierB}','{Ids.BranchA}',0,0);
            """);
        var cashierB = await _branchA.SignInAsync(Ids.CashierB, "t_cashier_b");
        await HttpAssert.ProblemAsync(await cashierB.GetAsync($"/api/v1/cash/tills/{till}/summary"), HttpStatusCode.NotFound, "cash.till_not_found");
        await using var branchB = SaviaNode.BranchB(_database);
        var managerB = await branchB.SignInAsync(Ids.Manager, "t_manager");
        await HttpAssert.ProblemAsync(await managerB.GetAsync($"/api/v1/cash/tills/{till}/summary"), HttpStatusCode.NotFound, "cash.till_not_found");

        var supervisorC = await _branchA.SignInAsync(new Guid("C0000000-0000-0000-0000-0000000000C5"), "t_super_c");
        await HttpAssert.ProblemAsync(await supervisorC.GetAsync("/api/v1/cash/registers"), HttpStatusCode.Forbidden, "auth.branch_access");
        await HttpAssert.ProblemAsync(await _branchA.CreateClient().GetAsync("/api/v1/cash/tills/current"), HttpStatusCode.Unauthorized, "auth.required");
        await TestSql.AssertConservationAsync(_database);
    }

    [Fact]
    public async Task Me_names_the_branch_and_location_of_the_node()
    {
        var me = await HttpAssert.OkAsync<MeResponse>(await _supervisor.GetAsync("/api/v1/me"));
        Assert.Equal((Ids.BranchA, (Guid?)Ids.LocA, "Sucursal A", "SAVIA Test", "Tienda A"),
            (me.BranchId!.Value, me.LocationId, me.BranchName, me.StoreDisplayName, me.LocationName));
        Assert.Equal(["MANAGER"], me.Roles);

        await using var cloud = SaviaNode.Cloud(_database);
        var manager = await cloud.SignInAsync(Ids.Manager, "t_manager");
        var cloudMe = await HttpAssert.OkAsync<MeResponse>(await manager.GetAsync("/api/v1/me"));
        Assert.Equal(("Cloud", (Guid?)null, (Guid?)null, (string?)null), (cloudMe.NodeKind, cloudMe.BranchId, cloudMe.LocationId, cloudMe.BranchName));
        await HttpAssert.ProblemAsync(await cloud.CreateClient().GetAsync("/api/v1/me"), HttpStatusCode.Unauthorized, "auth.required");
    }

    [Fact]
    public async Task Openapi_lists_the_pilot_endpoints()
    {
        var json = await (await _branchA.CreateClient().GetAsync("/openapi/v1.json")).Content.ReadAsStringAsync();
        foreach (var path in new[] { "/api/v1/catalog/search", "/api/v1/receiving/sessions/{sessionId}/lines",
                     "/api/v1/receiving/sessions/{sessionId}/scans/{scanId}/resolve", "/api/v1/suppliers", "/api/v1/cash/registers",
                     "/api/v1/cash/tills/current", "/api/v1/cash/tills/{tillId}/summary" })
            Assert.Contains($"\"{path}\"", json);
        foreach (var schema in new[] { "ProductSearchRow", "ScanSessionSummary", "ScanSessionLine", "RegisterRow", "TillSummary" })
            Assert.Contains($"\"{schema}\"", json);
    }

    [Fact]
    public async Task Static_client_is_served_at_root_and_a_missing_folder_is_harmless()
    {
        var web = Directory.CreateTempSubdirectory("savia-web-");
        try
        {
            await File.WriteAllTextAsync(Path.Combine(web.FullName, "index.html"), "<!doctype html><title>t</title>");
            await using (var node = new SaviaNode(_database, Savia.Domain.NodeKind.Branch, Ids.NodeA, Ids.BranchA, Ids.LocA,
                             new Dictionary<string, string?> { ["Savia:Web:Root"] = web.FullName }))
            {
                var client = node.CreateClient();
                var root = await client.GetAsync("/");
                Assert.Equal(HttpStatusCode.OK, root.StatusCode);
                Assert.Equal("text/html", root.Content.Headers.ContentType?.MediaType);
                Assert.Contains("no-cache", root.Headers.CacheControl?.ToString());
                Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/health")).StatusCode);
                await HttpAssert.ProblemAsync(await client.GetAsync("/api/v1/me"), HttpStatusCode.Unauthorized, "auth.required");
            }

            await using var bare = new SaviaNode(_database, Savia.Domain.NodeKind.Branch, Ids.NodeA, Ids.BranchA, Ids.LocA,
                new Dictionary<string, string?> { ["Savia:Web:Root"] = Path.Combine(web.FullName, "missing") });
            var bareClient = bare.CreateClient();
            Assert.Equal(HttpStatusCode.OK, (await bareClient.GetAsync("/health")).StatusCode);
            Assert.Equal(HttpStatusCode.NotFound, (await bareClient.GetAsync("/")).StatusCode);
        }
        finally
        {
            web.Delete(recursive: true);
        }
    }
}
