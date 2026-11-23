using Savia.Application;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Api;

public static class CatalogEndpoints
{
    public static void Map(RouteGroupBuilder open, RouteGroupBuilder api, NodeContext node)
    {
        api.MapGet("/catalog/lookup", async (string code, Guid? supplierId, HttpContext http, CatalogService catalog, CancellationToken ct) =>
            await catalog.LookupAsync(http.Actor(), code, supplierId, ct)).Produces<ItemLookup[]>().WithTags("catalog");
        api.MapGet("/catalog/items", async (string? after, int? limit, HttpContext http, CatalogService catalog, CancellationToken ct) =>
            http.Paged(await catalog.ListAsync(http.Actor(), after, limit, ct))).Produces<CatalogProduct[]>().WithTags("catalog");
        api.MapGet("/catalog/search", async (string q, int? limit, HttpContext http, CatalogService catalog, CancellationToken ct) =>
            await catalog.SearchAsync(http.Actor(), q, limit, ct)).Produces<ProductSearchRow[]>().WithTags("catalog");

        // Catalog writes: the cloud node, or a branch with the explicit local-catalog exception. A store with a hub maps
        // them too, so a write gets the named refusal catalog.managed_by_hub rather than a bare 404 (D-039).
        if (node.Kind == NodeKind.Cloud || node.LocalCatalog || node.CatalogManagedByHub)
        {
            api.MapPost("/catalog/products", async (RegisterProductRequest request, HttpContext http, CatalogService catalog, CancellationToken ct) =>
            {
                await catalog.RegisterProductAsync(http.Actor(), request, ct);
                return Results.NoContent();
            }).WithTags("catalog");
            api.MapPost("/catalog/items", async (RegisterItemRequest request, HttpContext http, CatalogService catalog, CancellationToken ct) =>
            {
                await catalog.RegisterItemAsync(http.Actor(), request, ct);
                return Results.NoContent();
            }).WithTags("catalog");
            api.MapPost("/suppliers", async (CreateSupplierRequest request, HttpContext http, CatalogService catalog, CancellationToken ct) =>
            {
                await catalog.CreateSupplierAsync(http.Actor(), request, ct);
                return Results.NoContent();
            }).WithTags("catalog");
        }
        else
        {
            // GET shares this path; preserve the disabled write contract (404 rather than 405).
            open.MapPost("/catalog/items", () => Results.NotFound()).ExcludeFromDescription();
        }

        // D-039: the hub owns prices and costs; a store with a hub refuses the write by name, a store without one keeps it.
        api.MapPost("/catalog/items/{itemId:guid}/values",
            async (Guid itemId, ItemValuesRequest request, HttpContext http, CatalogService catalog, CancellationToken ct) =>
            {
                await catalog.SetItemValuesAsync(http.Actor(), itemId, request, ct);
                return Results.NoContent();
            }).WithTags("catalog");
        // Prices and the catalog import: on a store, and on the hub, where the import writes no stock (D-039).
        api.MapGet("/catalog/values", async (string? q, HttpContext http, CatalogService catalog, CancellationToken ct) =>
            await catalog.ItemValuesAsync(http.Actor(), q, ct)).WithTags("catalog");
        api.MapPost("/catalog/import/file", (ImportFileRequest request, HttpContext http, CatalogService catalog) =>
            catalog.ParseImport(http.Actor(), request)).WithTags("catalog");
        api.MapPost("/catalog/import/preview", async (ImportCatalogRequest request, HttpContext http, CatalogService catalog, CancellationToken ct) =>
            await catalog.ImportCatalogAsync(http.Actor(), request, false, ct)).WithTags("catalog");
        api.MapPost("/catalog/import", async (ImportCatalogRequest request, HttpContext http, CatalogService catalog, CancellationToken ct) =>
            await catalog.ImportCatalogAsync(http.Actor(), request, true, ct)).WithTags("catalog");
    }
}
