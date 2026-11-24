using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Tests;

/// <summary>S9 (D-039): the hub writes the catalog; a store with a hub only reads it and refuses writes by name.</summary>
public sealed class HubCatalogTests : IAsyncLifetime
{
    private string _database = "";

    public async Task InitializeAsync() => _database = await TestSql.CloneAsync("hubcatalog");

    public async Task DisposeAsync() => await TestSql.DropAsync(_database);

    private static readonly ImportRow[] Rows =
    [
        new(2, "7501234567893", null, "Blusa central", "Blusa", "M", "Azul", "200", "450", null),
        new(3, "7501234567886", null, "Blusa central", "Blusa", "L", "Azul", "200", "450", "0"),
        new(4, "HUB-0001", "HUB-FAL-S", "Falda central", "Falda", "S", "Negro", "150", "1,250.00", null),
    ];

    private static ImportFileRequest Csv() => new("central.csv", Convert.ToBase64String(Encoding.UTF8.GetBytes(
        "codigo,nombre,precio\n7501234567893,Blusa central,450\n")));

    [Fact]
    public async Task Hub_imports_catalog_without_stock_and_reads_prices_without_a_branch()
    {
        await using var hub = new SaviaNode(_database, NodeKind.Cloud, Ids.NodeCloud, null, null);
        var owner = await hub.SignInAsync(Ids.Manager, "t_manager");
        var supervisor = await hub.SignInAsync(Ids.SupervisorA, "t_super_a");
        Assert.False((await HttpAssert.OkAsync<MeResponse>(await owner.GetAsync("/api/v1/me"))).CatalogManagedByHub);

        await HttpAssert.OkAsync<ImportFile>(await owner.PostAsJsonAsync("/api/v1/catalog/import/file", Csv()));
        var request = new ImportCatalogRequest(Guid.NewGuid(), "central.csv", Rows);
        await HttpAssert.ProblemAsync(await supervisor.PostAsJsonAsync("/api/v1/catalog/import/preview", request),
            HttpStatusCode.Forbidden, "auth.role_required");
        var stocked = request with { Rows = [Rows[0] with { Stock = "3" }] };
        var refused = await HttpAssert.OkAsync<JsonElement>(await owner.PostAsJsonAsync("/api/v1/catalog/import/preview", stocked));
        Assert.Equal(1, refused.GetProperty("errorCount").GetInt32());
        var preview = await HttpAssert.OkAsync<JsonElement>(await owner.PostAsJsonAsync("/api/v1/catalog/import/preview", request));
        Assert.Equal(0, preview.GetProperty("errorCount").GetInt32());
        var done = await HttpAssert.OkAsync<JsonElement>(await owner.PostAsJsonAsync("/api/v1/catalog/import", request));
        Assert.Equal((3, 0), (done.GetProperty("itemsCreated").GetInt32(), done.GetProperty("unitsAdded").GetInt32()));
        Assert.Equal(0, await TestSql.ScalarAsync<int>(_database,
            $"SELECT COUNT(*) FROM inventory.StockMovements WHERE SourceType='catalog_import' AND SourceId='{request.BatchId}'"));
        Assert.Equal(1, await TestSql.ScalarAsync<int>(_database,
            $"SELECT COUNT(*) FROM catalog.ImportBatches WHERE Id='{request.BatchId}' AND BranchId IS NULL AND LocationId IS NULL"));

        var values = await HttpAssert.OkAsync<JsonElement>(await owner.GetAsync("/api/v1/catalog/values?q=HUB-FAL-S"));
        var item = Assert.Single(values.EnumerateArray());
        Assert.Equal(125000, item.GetProperty("priceMinor").GetInt64());
        await HttpAssert.ProblemAsync(await supervisor.GetAsync("/api/v1/catalog/values"), HttpStatusCode.Forbidden, "auth.role_required");
        await HttpAssert.OkAsync(await owner.PostAsJsonAsync($"/api/v1/catalog/items/{item.GetProperty("itemId").GetGuid()}/values",
            new ItemValuesRequest(Guid.NewGuid(), 130000, 15000, "Precio central")));
        await TestSql.AssertConservationAsync(_database);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("true")]
    public async Task Store_with_a_hub_refuses_catalog_writes_by_name(string? localCatalog)
    {
        // A node credential alone marks the hub; HubUrl would also start the sync worker, which this test does not need.
        await using var store = new SaviaNode(_database, NodeKind.Branch, Ids.NodeA, Ids.BranchA, Ids.LocA,
            new Dictionary<string, string?> { ["Savia:Sync:NodeSecret"] = "test-only", ["Savia:Pilot:LocalCatalog"] = localCatalog });
        var owner = await store.SignInAsync(Ids.Manager, "t_manager");
        Assert.True((await HttpAssert.OkAsync<MeResponse>(await owner.GetAsync("/api/v1/me"))).CatalogManagedByHub);

        var product = new RegisterProductRequest(Guid.NewGuid(), "Tienda");
        var item = new RegisterItemRequest(Guid.NewGuid(), product.ProductId, "STORE-SKU", "Tienda", "NIO", 50000, 20000, "STORE-CODE");
        var request = new ImportCatalogRequest(Guid.NewGuid(), "central.csv", Rows);
        foreach (var response in new[]
        {
            await owner.PostAsJsonAsync("/api/v1/catalog/products", product),
            await owner.PostAsJsonAsync("/api/v1/catalog/items", item),
            await owner.PostAsJsonAsync($"/api/v1/catalog/items/{Ids.Item}/values", new ItemValuesRequest(Guid.NewGuid(), 1, 1, "x")),
            await owner.PostAsJsonAsync("/api/v1/catalog/import/file", Csv()),
            await owner.PostAsJsonAsync("/api/v1/catalog/import/preview", request),
            await owner.PostAsJsonAsync("/api/v1/catalog/import", request),
        })
            await HttpAssert.ProblemAsync(response, HttpStatusCode.Conflict, "catalog.managed_by_hub");
        // Reading the catalog and its prices stays open.
        await HttpAssert.OkAsync<JsonElement>(await owner.GetAsync("/api/v1/catalog/values"));
        Assert.Equal(0, await TestSql.ScalarAsync<int>(_database,
            $"SELECT COUNT(*) FROM catalog.Products WHERE Id='{product.ProductId}'"));
    }

    [Fact]
    public async Task Store_without_a_hub_keeps_its_catalog_routes()
    {
        await using var store = new SaviaNode(_database, NodeKind.Branch, Ids.NodeA, Ids.BranchA, Ids.LocA);
        var owner = await store.SignInAsync(Ids.Manager, "t_manager");
        Assert.False((await HttpAssert.OkAsync<MeResponse>(await owner.GetAsync("/api/v1/me"))).CatalogManagedByHub);
        await HttpAssert.OkAsync<ImportFile>(await owner.PostAsJsonAsync("/api/v1/catalog/import/file", Csv()));
        Assert.Equal(HttpStatusCode.NotFound, (await owner.PostAsJsonAsync("/api/v1/catalog/products",
            new RegisterProductRequest(Guid.NewGuid(), "Tienda"))).StatusCode);
    }
}
