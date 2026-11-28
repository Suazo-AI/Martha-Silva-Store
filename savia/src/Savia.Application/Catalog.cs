using System.Text.Json;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

public interface ICatalogStore
{
    /// <summary>Whole products in name order, at most <paramref name="limit"/> variants unless one product alone has more.</summary>
    Task<Page<CatalogProduct>> ListAsync(Guid locationId, string? after, int limit, CancellationToken ct);
    Task<IReadOnlyList<ItemLookup>> LookupAsync(string rawCode, Guid? supplierId, CancellationToken ct);
    /// <summary>Active or draft variants whose product name, variant name, SKU or a code contains the text.</summary>
    Task<IReadOnlyList<ProductSearchRow>> SearchAsync(string text, Guid? locationId, int limit, CancellationToken ct);
    Task RegisterProductAsync(RegisterProductRequest request, Guid actorId, Guid nodeId, CancellationToken ct);
    Task RegisterItemAsync(RegisterItemRequest request, Guid actorId, Guid nodeId, CancellationToken ct);
}

/// <summary>
/// Prices, costs and bulk import on the branch that owns its catalog. It is a second port because the tag
/// reader depends on <see cref="ICatalogStore"/> alone and its tests replace that one with a fake.
/// </summary>
public interface ICatalogMaintenanceStore
{
    /// <summary>A null branch is the hub, where the owner needs no branch grant.</summary>
    Task<JsonElement> ItemValuesAsync(Guid? branch, Guid actor, string query, CancellationToken ct);
    Task SetItemValuesAsync(Guid item, ItemValuesRequest request, Guid actor, Guid node, CancellationToken ct);
    /// <summary>A null branch and location is the hub: products, items, barcodes and prices, and no stock.</summary>
    Task<JsonElement> ImportCatalogAsync(Guid? branch, Guid? location, ImportCatalogRequest request, Guid actor, Guid node, bool commit,
        CancellationToken ct);
    Task CreateSupplierAsync(CreateSupplierRequest request, Guid actor, CancellationToken ct);
}

public sealed class CatalogService(ICatalogStore store, ICatalogMaintenanceStore maintenance, NodeContext node)
{
    private static bool HidePrice(Actor actor) =>
        actor.Roles.Contains(Roles.Inventory) && !actor.Roles.Contains(Roles.Owner) && !actor.Roles.Contains(Roles.Manager);

    public async Task<Page<CatalogProduct>> ListAsync(Actor actor, string? after, int? limit, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        var page = await store.ListAsync(node.RequireLocation(), after, Paging.Limit(limit), ct);
        return HidePrice(actor)
            ? page with { Items = page.Items.Select(p => p with { Variants = p.Variants.Select(v => v with { UnitPriceMinor = null }).ToArray() }).ToArray() }
            : page;
    }

    /// <summary>Returns every variant the code may mean. The caller must not pick one when there are several.</summary>
    public async Task<IReadOnlyList<ItemLookup>> LookupAsync(Actor actor, string rawCode, Guid? supplierId, CancellationToken ct)
    {
        if (node.Kind == NodeKind.Branch) Guard.Branch(actor, node);
        var rows = await store.LookupAsync(Guard.Text(rawCode, "code", 128), supplierId, ct);
        return HidePrice(actor) ? rows.Select(v => v with { UnitPriceMinor = null }).ToArray() : rows;
    }

    /// <summary>Finds variants by a fragment of name, SKU or code, with stock of this node's store location.</summary>
    public async Task<IReadOnlyList<ProductSearchRow>> SearchAsync(Actor actor, string text, int? limit, CancellationToken ct)
    {
        if (node.Kind == NodeKind.Branch) Guard.Branch(actor, node);
        else Guard.Role(actor, Roles.CloudReaders);
        var q = Guard.Text(text, "q", 100).Trim();
        if (q.Length < 2) throw Errors.Invalid("catalog.search_too_short", "Escriba al menos 2 caracteres.");
        var rows = await store.SearchAsync(q, node.LocationId, Math.Clamp(limit ?? 25, 1, 100), ct);
        return HidePrice(actor) ? rows.Select(v => v with { UnitPriceMinor = null }).ToArray() : rows;
    }

    // D-039: a store with a hub refuses catalog writes by name, so its screens can say where the catalog is managed.
    private void RefuseOnHubStore()
    {
        if (node.CatalogManagedByHub) throw new SaviaException(Errors.CatalogManagedByHub);
    }

    // The hub has no branch, so there only the owner works on prices and imports. A store keeps its branch check.
    private Guid? CatalogBranch(Actor actor, string[] storeRoles)
    {
        if (node.Kind == NodeKind.Branch) return Guard.BranchRole(actor, node, storeRoles);
        Guard.Role(actor, Roles.OwnerOnly);
        return null;
    }

    // The catalog has one writer: cloud normally, or this branch during the explicit local pilot.
    private void RequireCatalogWriter(Actor actor)
    {
        RefuseOnHubStore();
        if (node.Kind == NodeKind.Branch && node.LocalCatalog) Guard.Branch(actor, node);
        else Guard.Kind(node, NodeKind.Cloud);
        Guard.Role(actor, Roles.Approvers);
    }

    /// <summary>Suppliers are reference data with the catalog's single writer; stores receive them by sync (V053).</summary>
    public Task CreateSupplierAsync(Actor actor, CreateSupplierRequest request, CancellationToken ct)
    {
        RequireCatalogWriter(actor);
        Guard.Text(request.Name, "name", 200);
        Guard.Id(request.SupplierId, "supplierId");
        return maintenance.CreateSupplierAsync(request, actor.StaffId, ct);
    }

    public Task RegisterProductAsync(Actor actor, RegisterProductRequest request, CancellationToken ct)
    {
        RequireCatalogWriter(actor);
        Guard.Text(request.Name, "name", 200);
        Guard.Id(request.ProductId, "productId");
        return store.RegisterProductAsync(request, actor.StaffId, node.NodeId, ct);
    }

    public Task RegisterItemAsync(Actor actor, RegisterItemRequest request, CancellationToken ct)
    {
        RequireCatalogWriter(actor);
        Guard.Role(actor, Roles.OwnerOnly);
        Guard.Text(request.Sku, "sku", 100);
        Guard.Text(request.VariantName, "variantName", 200);
        Guard.Id(request.ItemId, "itemId");
        Guard.Currency(request.CurrencyCode);
        Guard.MaxLength(request.Barcode, "barcode", 128);
        Guard.MaxLength(request.SupplierSku, "supplierSku", 128);
        return store.RegisterItemAsync(request, actor.StaffId, node.NodeId, ct);
    }

    public Task<JsonElement> ItemValuesAsync(Actor actor, string? query, CancellationToken ct) =>
        maintenance.ItemValuesAsync(CatalogBranch(actor, Roles.Approvers), actor.StaffId, query?.Trim() ?? "", ct);

    public Task SetItemValuesAsync(Actor actor, Guid item, ItemValuesRequest request, CancellationToken ct)
    {
        // D-039: the hub owns prices; it has no branch, so only the owner role applies there.
        RefuseOnHubStore();
        if (node.BranchId is not null) Guard.Branch(actor, node);
        Guard.Role(actor, Roles.OwnerOnly);
        Guard.Text(request.Reason, "reason", 250);
        Guard.Id(request.ChangeId, "changeId");
        return maintenance.SetItemValuesAsync(item, request, actor.StaffId, node.NodeId, ct);
    }

    public ImportFile ParseImport(Actor actor, ImportFileRequest request)
    {
        RefuseOnHubStore();
        CatalogBranch(actor, Roles.OwnerOnly);
        Guard.Text(request.FileName, "fileName", 200);
        byte[] content;
        try { content = Convert.FromBase64String(request.ContentBase64 ?? ""); }
        catch (FormatException) { throw Errors.Invalid("import.format", "El archivo no se pudo leer."); }
        return CatalogFile.Parse(request.FileName, content);
    }

    public Task<JsonElement> ImportCatalogAsync(Actor actor, ImportCatalogRequest request, bool commit, CancellationToken ct)
    {
        RefuseOnHubStore();
        var branch = CatalogBranch(actor, Roles.OwnerOnly);
        Guard.Text(request.FileName, "fileName", 200);
        if (request.Rows is not { Length: > 0 } || request.Rows.Length > CatalogFile.MaxRows || request.Rows.Contains(null))
            throw Errors.Invalid("import.size", $"El archivo debe tener entre 1 y {CatalogFile.MaxRows} filas.");
        Guard.Id(request.BatchId, "batchId");
        var location = branch is null ? (Guid?)null : node.RequireLocation();
        return maintenance.ImportCatalogAsync(branch, location, request, actor.StaffId, node.NodeId, commit, ct);
    }
}
