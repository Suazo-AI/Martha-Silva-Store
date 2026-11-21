using System.Text.Json;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

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
    Task RecordQualityAsync(Guid session, QualityRequest request, Guid actor, Guid location, CancellationToken ct);
    Task<JsonElement> QualityAsync(Guid session, Guid location, CancellationToken ct);
}

public sealed class ReceivingService(IReceivingStore store, NodeContext node)
{
    public Task OpenSessionAsync(Actor actor, OpenScanSessionRequest request, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Receivers);
        Guard.Text(request.Reference, "reference", 100);
        return store.OpenSessionAsync(request, node.RequireLocation(), actor.StaffId, ct);
    }

    /// <summary>One reading of the scanner. The same <c>ScanId</c> sent twice counts once.</summary>
    public async Task<ScanResult> RecordScanAsync(Actor actor, Guid sessionId, RecordScanRequest request, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Receivers);
        Guard.Text(request.RawCode, "rawCode", 128);
        await RequireSessionHereAsync(sessionId, ct);
        return await store.RecordScanAsync(sessionId, request, actor.StaffId, ct);
    }

    public async Task ApproveAsync(Actor actor, Guid sessionId, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Approvers);
        await RequireSessionHereAsync(sessionId, ct);
        await store.ApproveAsync(sessionId, actor.StaffId, ct);
    }

    /// <summary>Moves the approved count into stock, once. Returns the same receipt on a retry.</summary>
    public async Task<PostScanSessionResponse> PostAsync(Actor actor, Guid sessionId, string currencyCode, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Approvers);
        await RequireSessionHereAsync(sessionId, ct);
        return new(await store.PostAsync(sessionId, actor.StaffId, node.NodeId, currencyCode, ct));
    }

    public async Task<ScanSessionProgress> GetProgressAsync(Actor actor, Guid sessionId, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Receivers);
        return await RequireSessionHereAsync(sessionId, ct);
    }

    /// <summary>Most recent sessions of this location, newest first. <paramref name="openOnly"/> hides posted and cancelled ones.</summary>
    public Task<IReadOnlyList<ScanSessionSummary>> ListSessionsAsync(Actor actor, bool openOnly, int? limit, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Receivers);
        return store.ListSessionsAsync(node.RequireLocation(), openOnly, Math.Clamp(limit ?? 50, 1, 200), ct);
    }

    public async Task<IReadOnlyList<ScanSessionLine>> GetLinesAsync(Actor actor, Guid sessionId, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Receivers);
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
        Guard.Role(actor, Roles.Approvers);
        Guard.Text(request.Reason, "reason", 250);
        await RequireSessionHereAsync(sessionId, ct);
        if (!await store.ScanInSessionAsync(scanId, sessionId, ct))
            throw Errors.NotFound("receiving.scan_not_found", "La lectura no existe en esta sesión.");
        await store.ResolveScanAsync(scanId, request.ItemId, actor.StaffId, request.Reason, ct);
    }

    public Task<IReadOnlyList<SupplierRow>> ListSuppliersAsync(Actor actor, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Receivers);
        return store.ListSuppliersAsync(ct);
    }

    public async Task RejectScanAsync(Actor actor, Guid sessionId, Guid scanId, RejectScanRequest request, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Approvers);
        Guard.Text(request.Reason, "reason", 250);
        await RequireSessionHereAsync(sessionId, ct);
        if (!await store.ScanInSessionAsync(scanId, sessionId, ct))
            throw Errors.NotFound("receiving.scan_not_found", "La lectura no existe en esta sesión.");
        await store.RejectScanAsync(scanId, actor.StaffId, request.Reason, ct);
    }

    public Task RecordQualityAsync(Actor actor, Guid session, QualityRequest request, CancellationToken ct)
    {
        Guard.BranchRole(actor, node, Roles.StockWorkers);
        Guard.Text(request.Reason, "reason", 250);
        return store.RecordQualityAsync(session, request, actor.StaffId, node.RequireLocation(), ct);
    }

    public Task<JsonElement> QualityAsync(Actor actor, Guid session, CancellationToken ct)
    {
        Guard.BranchRole(actor, node, Roles.StockWorkers);
        return store.QualityAsync(session, node.RequireLocation(), ct);
    }

    // A session of another branch's location does not exist for this node.
    private async Task<ScanSessionProgress> RequireSessionHereAsync(Guid sessionId, CancellationToken ct) =>
        await store.GetProgressAsync(sessionId, node.RequireLocation(), ct)
        ?? throw Errors.NotFound("receiving.session_not_found", "La sesión de conteo no existe en esta sucursal.");
}
