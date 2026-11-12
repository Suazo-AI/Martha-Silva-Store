using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

// Use cases. Each one authorizes, checks the shape of the input and calls one port.
// Stock, cash and sale rules are NOT here: they live in the SQL procedures behind the ports (ADR-001 D2).

// ------------------------------------------------------------------ catalog
public interface ICatalogStore
{
    Task<IReadOnlyList<ItemLookup>> LookupAsync(string rawCode, Guid? supplierId, CancellationToken ct);
    /// <summary>Active or draft variants whose product name, variant name, SKU or a code contains the text.</summary>
    Task<IReadOnlyList<ProductSearchRow>> SearchAsync(string text, Guid? locationId, int limit, CancellationToken ct);
    Task RegisterProductAsync(RegisterProductRequest request, Guid actorId, Guid nodeId, CancellationToken ct);
    Task RegisterItemAsync(RegisterItemRequest request, Guid actorId, Guid nodeId, CancellationToken ct);
}

public sealed class CatalogService(ICatalogStore store, NodeContext node)
{
    /// <summary>Returns every variant the code may mean. The caller must not pick one when there are several.</summary>
    public Task<IReadOnlyList<ItemLookup>> LookupAsync(Actor actor, string rawCode, Guid? supplierId, CancellationToken ct)
    {
        _ = actor;
        return store.LookupAsync(Guard.Text(rawCode, "code", 128), supplierId, ct);
    }

    /// <summary>Finds variants by a fragment of name, SKU or code, with stock of this node's store location.</summary>
    public Task<IReadOnlyList<ProductSearchRow>> SearchAsync(Actor actor, string text, int? limit, CancellationToken ct)
    {
        if (node.Kind == NodeKind.Branch) Guard.Branch(actor, node);
        else Guard.Role(actor, Roles.Owner, Roles.Manager, Roles.Accountant);
        var q = Guard.Text(text, "q", 100).Trim();
        if (q.Length < 2) throw Errors.Invalid("catalog.search_too_short", "Escriba al menos 2 caracteres.");
        return store.SearchAsync(q, node.LocationId, Math.Clamp(limit ?? 25, 1, 100), ct);
    }

    // The catalog has one writer: cloud normally, or this branch during the explicit local pilot.
    private void RequireCatalogWriter(Actor actor)
    {
        if (node.Kind == NodeKind.Branch && node.LocalCatalog) Guard.Branch(actor, node);
        else Guard.Kind(node, NodeKind.Cloud);
        Guard.Role(actor, Roles.Owner, Roles.Manager);
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
        Guard.Text(request.Sku, "sku", 100);
        Guard.Text(request.VariantName, "variantName", 200);
        return store.RegisterItemAsync(request, actor.StaffId, node.NodeId, ct);
    }
}

// ---------------------------------------------------------------- receiving
public interface IReceivingStore
{
    Task OpenSessionAsync(OpenScanSessionRequest request, Guid locationId, Guid actorId, CancellationToken ct);
    Task<ScanResult> RecordScanAsync(Guid sessionId, RecordScanRequest request, Guid actorId, CancellationToken ct);
    Task ApproveAsync(Guid sessionId, Guid reviewerId, CancellationToken ct);
    Task<Guid> PostAsync(Guid sessionId, Guid actorId, Guid nodeId, string currencyCode, CancellationToken ct);
    Task<ScanSessionProgress?> GetProgressAsync(Guid sessionId, Guid locationId, CancellationToken ct);
    Task<IReadOnlyList<ScanSessionSummary>> ListSessionsAsync(Guid locationId, bool openOnly, int limit, CancellationToken ct);
    Task<IReadOnlyList<ScanSessionLine>> GetLinesAsync(Guid sessionId, CancellationToken ct);
    /// <summary>True when the reading belongs to the session.</summary>
    Task<bool> ScanInSessionAsync(Guid scanId, Guid sessionId, CancellationToken ct);
    Task ResolveScanAsync(Guid scanId, Guid itemId, Guid reviewerId, string reason, CancellationToken ct);
    Task RejectScanAsync(Guid scanId, Guid reviewerId, string reason, CancellationToken ct);
    Task<IReadOnlyList<SupplierRow>> ListSuppliersAsync(CancellationToken ct);
}

public sealed class ReceivingService(IReceivingStore store, NodeContext node)
{
    private static readonly string[] Counters = [Roles.Inventory, Roles.Cashier, Roles.Manager, Roles.Owner];
    private static readonly string[] Approvers = [Roles.Manager, Roles.Owner];

    public Task OpenSessionAsync(Actor actor, OpenScanSessionRequest request, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Counters);
        Guard.Text(request.Reference, "reference", 100);
        return store.OpenSessionAsync(request, node.RequireLocation(), actor.StaffId, ct);
    }

    /// <summary>One reading of the scanner. The same <c>ScanId</c> sent twice counts once.</summary>
    public async Task<ScanResult> RecordScanAsync(Actor actor, Guid sessionId, RecordScanRequest request, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Counters);
        Guard.Text(request.RawCode, "rawCode", 128);
        await RequireSessionHereAsync(sessionId, ct);
        return await store.RecordScanAsync(sessionId, request, actor.StaffId, ct);
    }

    public async Task ApproveAsync(Actor actor, Guid sessionId, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Approvers);
        await RequireSessionHereAsync(sessionId, ct);
        await store.ApproveAsync(sessionId, actor.StaffId, ct);
    }

    /// <summary>Moves the approved count into stock, once. Returns the same receipt on a retry.</summary>
    public async Task<PostScanSessionResponse> PostAsync(Actor actor, Guid sessionId, string currencyCode, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Approvers);
        await RequireSessionHereAsync(sessionId, ct);
        return new(await store.PostAsync(sessionId, actor.StaffId, node.NodeId, currencyCode, ct));
    }

    public async Task<ScanSessionProgress> GetProgressAsync(Actor actor, Guid sessionId, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        return await RequireSessionHereAsync(sessionId, ct);
    }

    /// <summary>Most recent sessions of this location, newest first. <paramref name="openOnly"/> hides posted and cancelled ones.</summary>
    public Task<IReadOnlyList<ScanSessionSummary>> ListSessionsAsync(Actor actor, bool openOnly, int? limit, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Counters);
        return store.ListSessionsAsync(node.RequireLocation(), openOnly, Math.Clamp(limit ?? 50, 1, 200), ct);
    }

    public async Task<IReadOnlyList<ScanSessionLine>> GetLinesAsync(Actor actor, Guid sessionId, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Counters);
        await RequireSessionHereAsync(sessionId, ct);
        return await store.GetLinesAsync(sessionId, ct);
    }

    /// <summary>
    /// Ties an unknown or ambiguous reading to a variant. The procedure accepts it only when the catalog
    /// already has that code for the variant (51306), so resolving never invents catalog identifiers.
    /// </summary>
    public async Task ResolveScanAsync(Actor actor, Guid sessionId, Guid scanId, ResolveScanRequest request, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Approvers);
        Guard.Text(request.Reason, "reason", 250);
        await RequireSessionHereAsync(sessionId, ct);
        if (!await store.ScanInSessionAsync(scanId, sessionId, ct))
            throw Errors.NotFound("receiving.scan_not_found", "La lectura no existe en esta sesión.");
        await store.ResolveScanAsync(scanId, request.ItemId, actor.StaffId, request.Reason, ct);
    }

    public Task<IReadOnlyList<SupplierRow>> ListSuppliersAsync(Actor actor, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Counters);
        return store.ListSuppliersAsync(ct);
    }

    public async Task RejectScanAsync(Actor actor, Guid sessionId, Guid scanId, RejectScanRequest request, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Approvers);
        Guard.Text(request.Reason, "reason", 250);
        await RequireSessionHereAsync(sessionId, ct);
        if (!await store.ScanInSessionAsync(scanId, sessionId, ct))
            throw Errors.NotFound("receiving.scan_not_found", "La lectura no existe en esta sesión.");
        await store.RejectScanAsync(scanId, actor.StaffId, request.Reason, ct);
    }

    // A session of another branch's location does not exist for this node.
    private async Task<ScanSessionProgress> RequireSessionHereAsync(Guid sessionId, CancellationToken ct) =>
        await store.GetProgressAsync(sessionId, node.RequireLocation(), ct)
        ?? throw Errors.NotFound("receiving.session_not_found", "La sesión de conteo no existe en esta sucursal.");
}

// ------------------------------------------------------- stock and labels
public interface IInventoryStore
{
    Task<IReadOnlyList<StockRow>> GetStockAsync(Guid? branchId, Guid? itemId, CancellationToken ct);
    Task<IReadOnlyList<LabelJob>> GetLabelJobsAsync(Guid branchId, string? status, CancellationToken ct);
    Task AcknowledgePrintAsync(Guid printJobId, Guid branchId, AckPrintRequest request, CancellationToken ct);
}

public sealed class InventoryService(IInventoryStore store, NodeContext node)
{
    public Task<IReadOnlyList<StockRow>> GetStockAsync(Actor actor, Guid? itemId, CancellationToken ct)
    {
        if (node.Kind == NodeKind.Branch) Guard.Branch(actor, node);
        else Guard.Role(actor, Roles.Owner, Roles.Manager, Roles.Accountant);
        return store.GetStockAsync(node.BranchId, itemId, ct);
    }

    public Task<IReadOnlyList<LabelJob>> GetLabelJobsAsync(Actor actor, string? status, CancellationToken ct) =>
        store.GetLabelJobsAsync(Guard.Branch(actor, node), status, ct);

    /// <summary>The print worker reports each attempt. A failed attempt keeps the job visible as failed.</summary>
    public Task AcknowledgePrintAsync(Actor actor, Guid printJobId, AckPrintRequest request, CancellationToken ct) =>
        store.AcknowledgePrintAsync(printJobId, Guard.Branch(actor, node), request, ct);
}

// --------------------------------------------------------- cash and sales
public interface ISalesStore
{
    Task OpenTillAsync(OpenTillRequest request, Guid cashierId, Guid nodeId, CancellationToken ct);
    Task PostSaleAsync(PostSaleRequest request, Guid branchId, Guid locationId, Guid cashierId, Guid nodeId, CancellationToken ct);
    Task<SaleResponse?> GetSaleAsync(Guid saleId, Guid branchId, CancellationToken ct);
    Task RecordCashCountAsync(Guid tillId, RecordCashCountRequest request, Guid actorId, CancellationToken ct);
    Task CloseTillAsync(Guid tillId, CloseTillRequest request, Guid actorId, Guid nodeId, CancellationToken ct);
    Task<CloseTillResponse?> GetClosureAsync(Guid tillId, CancellationToken ct);
    /// <summary>Branch that owns the till's register, or null when the till does not exist.</summary>
    Task<Guid?> GetTillBranchAsync(Guid tillId, CancellationToken ct);
    /// <summary>Branch of an active register, or null when it does not exist.</summary>
    Task<Guid?> GetRegisterBranchAsync(Guid registerId, CancellationToken ct);
    Task<IReadOnlyList<RegisterRow>> ListRegistersAsync(Guid branchId, CancellationToken ct);
    /// <summary>Newest open till of the cashier on a register of the branch, or null.</summary>
    Task<Guid?> FindOpenTillAsync(Guid cashierId, Guid branchId, CancellationToken ct);
    Task<TillSummary?> GetTillSummaryAsync(Guid tillId, Guid branchId, CancellationToken ct);
}

public sealed class SalesService(ISalesStore store, NodeContext node)
{
    private static readonly string[] Sellers = [Roles.Cashier, Roles.Manager, Roles.Owner];

    public async Task OpenTillAsync(Actor actor, OpenTillRequest request, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Sellers);
        if (await store.GetRegisterBranchAsync(request.RegisterId, ct) != branch)
            throw Errors.NotFound("cash.register_not_found", "La caja no existe en esta sucursal.");
        await store.OpenTillAsync(request, actor.StaffId, node.NodeId, ct);
    }

    /// <summary>
    /// Posts a sale in the local database of the branch. It never calls the cloud.
    /// The same <c>SaleId</c> with the same content is accepted again and changes nothing.
    /// </summary>
    public async Task<SaleResponse> PostSaleAsync(Actor actor, PostSaleRequest request, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Sellers);
        if (request.Lines is not { Length: > 0 } || request.Tenders is not { Length: > 0 })
            throw Errors.Invalid("sale.empty", "La venta necesita al menos un artículo y un pago.");
        if (request.Lines.Select(l => l.LineNumber).Distinct().Count() != request.Lines.Length ||
            request.Tenders.Select(t => t.TenderNumber).Distinct().Count() != request.Tenders.Length)
            throw Errors.Invalid("sale.duplicate_line", "Números de línea o de pago repetidos.");
        foreach (var tender in request.Tenders)
        {
            Guard.Text(tender.TenderKind, "tenderKind", 20);
            if (tender.Reference?.Length > 120)
                throw Errors.Invalid("input.text", "La referencia admite hasta 120 caracteres.");
        }
        await store.PostSaleAsync(request, branch, node.RequireLocation(), actor.StaffId, node.NodeId, ct);
        return await store.GetSaleAsync(request.SaleId, branch, ct)
            ?? throw Errors.NotFound("sale.not_found", "La venta no quedó registrada.");
    }

    public async Task<SaleResponse> GetSaleAsync(Actor actor, Guid saleId, CancellationToken ct) =>
        await store.GetSaleAsync(saleId, Guard.Branch(actor, node), ct)
        ?? throw Errors.NotFound("sale.not_found", "La venta no existe en esta sucursal.");

    public async Task RecordCashCountAsync(Actor actor, Guid tillId, RecordCashCountRequest request, CancellationToken ct)
    {
        Guard.Role(actor, Sellers);
        await RequireTillHereAsync(actor, tillId, ct);
        if (request.Lines is not { Length: > 0 }) throw Errors.Invalid("cash.count_empty", "El arqueo necesita denominaciones.");
        await store.RecordCashCountAsync(tillId, request, actor.StaffId, ct);
    }

    public async Task<CloseTillResponse> CloseTillAsync(Actor actor, Guid tillId, CloseTillRequest request, CancellationToken ct)
    {
        Guard.Role(actor, Roles.Manager, Roles.Owner);
        await RequireTillHereAsync(actor, tillId, ct);
        await store.CloseTillAsync(tillId, request, actor.StaffId, node.NodeId, ct);
        return await store.GetClosureAsync(tillId, ct)
            ?? throw Errors.NotFound("cash.closure_not_found", "El cierre no quedó registrado.");
    }

    public Task<IReadOnlyList<RegisterRow>> ListRegistersAsync(Actor actor, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Sellers);
        return store.ListRegistersAsync(branch, ct);
    }

    /// <summary>The open till of the signed-in staff member at this branch.</summary>
    public async Task<TillSummary> GetCurrentTillAsync(Actor actor, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Sellers);
        var till = await store.FindOpenTillAsync(actor.StaffId, branch, ct)
            ?? throw Errors.NotFound("cash.no_open_till", "No tiene un turno de caja abierto.");
        return await GetTillSummaryAsync(actor, till, ct);
    }

    /// <summary>A cashier sees only their own tills; a manager or owner sees every till of the branch.</summary>
    public async Task<TillSummary> GetTillSummaryAsync(Actor actor, Guid tillId, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Sellers);
        var summary = await store.GetTillSummaryAsync(tillId, branch, ct);
        var supervisor = actor.Roles.Contains(Roles.Manager) || actor.Roles.Contains(Roles.Owner);
        if (summary is null || (!supervisor && summary.CashierId != actor.StaffId))
            throw Errors.NotFound("cash.till_not_found", "El turno de caja no existe en esta sucursal.");
        return summary;
    }

    private async Task RequireTillHereAsync(Actor actor, Guid tillId, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        if (await store.GetTillBranchAsync(tillId, ct) != branch)
            throw Errors.NotFound("cash.till_not_found", "El turno de caja no existe en esta sucursal.");
    }
}

/// <summary>Names of the branch and location this node serves, for the signed-in screen.</summary>
public sealed record SiteInfo(string BranchName, string StoreDisplayName, string? LocationName);

public interface ISiteStore
{
    Task<SiteInfo?> GetSiteAsync(Guid branchId, Guid? locationId, CancellationToken ct);
}

public sealed class SiteService(ISiteStore store, NodeContext node)
{
    /// <summary>The actor plus the branch, location and names of this node, so a client needs no fixed ids.</summary>
    public async Task<MeResponse> GetMeAsync(Actor actor, CancellationToken ct)
    {
        var site = node.BranchId is Guid branch ? await store.GetSiteAsync(branch, node.LocationId, ct) : null;
        return new MeResponse(actor.StaffId, actor.DisplayName, [.. actor.Roles.Order()], node.Kind.ToString(), node.NodeId, node.BranchId,
            node.LocationId, site?.BranchName, site?.StoreDisplayName, site?.LocationName);
    }
}
