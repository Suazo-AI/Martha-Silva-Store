using System.Text.Json;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

public interface ICatalogStore
{
    Task<IReadOnlyList<CatalogProduct>> ListAsync(Guid locationId, CancellationToken ct);
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
    Task<JsonElement> ItemValuesAsync(Guid branch, Guid actor, string query, CancellationToken ct);
    Task SetItemValuesAsync(Guid item, ItemValuesRequest request, Guid actor, Guid node, CancellationToken ct);
    Task<JsonElement> ImportCatalogAsync(Guid branch, Guid location, ImportCatalogRequest request, Guid actor, Guid node, bool commit, CancellationToken ct);
}

public sealed class CatalogService(ICatalogStore store, ICatalogMaintenanceStore maintenance, NodeContext node)
{
    private static bool HidePrice(Actor actor) =>
        actor.Roles.Contains(Roles.Inventory) && !actor.Roles.Contains(Roles.Owner) && !actor.Roles.Contains(Roles.Manager);

    public async Task<IReadOnlyList<CatalogProduct>> ListAsync(Actor actor, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        var rows = await store.ListAsync(node.RequireLocation(), ct);
        return HidePrice(actor) ? rows.Select(p => p with { Variants = p.Variants.Select(v => v with { UnitPriceMinor = null }).ToArray() }).ToArray() : rows;
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

    // The catalog has one writer: cloud normally, or this branch during the explicit local pilot.
    private void RequireCatalogWriter(Actor actor)
    {
        if (node.Kind == NodeKind.Branch && node.LocalCatalog) Guard.Branch(actor, node);
        else Guard.Kind(node, NodeKind.Cloud);
        Guard.Role(actor, Roles.Approvers);
    }

    public Task RegisterProductAsync(Actor actor, RegisterProductRequest request, CancellationToken ct)
    {
        RequireCatalogWriter(actor);
        Guard.Text(request.Name, "name", 200);
        return store.RegisterProductAsync(request, actor.StaffId, node.NodeId, ct);
    }

    public Task RegisterItemAsync(Actor actor, RegisterItemRequest request, CancellationToken ct)
    {
        RequireCatalogWriter(actor);
        Guard.Role(actor, Roles.OwnerOnly);
        Guard.Text(request.Sku, "sku", 100);
        Guard.Text(request.VariantName, "variantName", 200);
        return store.RegisterItemAsync(request, actor.StaffId, node.NodeId, ct);
    }

    public Task<JsonElement> ItemValuesAsync(Actor actor, string? query, CancellationToken ct) =>
        maintenance.ItemValuesAsync(Guard.BranchRole(actor, node, Roles.Approvers), actor.StaffId, query?.Trim() ?? "", ct);

    public Task SetItemValuesAsync(Actor actor, Guid item, ItemValuesRequest request, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Roles.OwnerOnly);
        Guard.Text(request.Reason, "reason", 250);
        return maintenance.SetItemValuesAsync(item, request, actor.StaffId, node.NodeId, ct);
    }

    public ImportFile ParseImport(Actor actor, ImportFileRequest request)
    {
        Guard.BranchRole(actor, node, Roles.OwnerOnly);
        Guard.Text(request.FileName, "fileName", 200);
        byte[] content;
        try { content = Convert.FromBase64String(request.ContentBase64 ?? ""); }
        catch (FormatException) { throw Errors.Invalid("import.format", "El archivo no se pudo leer."); }
        return CatalogFile.Parse(request.FileName, content);
    }

    public Task<JsonElement> ImportCatalogAsync(Actor actor, ImportCatalogRequest request, bool commit, CancellationToken ct)
    {
        var branch = Guard.BranchRole(actor, node, Roles.OwnerOnly);
        Guard.Text(request.FileName, "fileName", 200);
        if (request.Rows is not { Length: > 0 } || request.Rows.Length > CatalogFile.MaxRows)
            throw Errors.Invalid("import.size", $"El archivo debe tener entre 1 y {CatalogFile.MaxRows} filas.");
        return maintenance.ImportCatalogAsync(branch, node.RequireLocation(), request, actor.StaffId, node.NodeId, commit, ct);
    }
}
