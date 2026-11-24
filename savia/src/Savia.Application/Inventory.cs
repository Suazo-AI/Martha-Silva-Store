using System.Text.Json;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

public interface IInventoryStore
{
    /// <summary>Rows in SKU, location and pool order, starting after the row that <paramref name="after"/> names.</summary>
    Task<Page<StockRow>> GetStockAsync(Guid? branchId, Guid? itemId, string? after, int limit, CancellationToken ct);
    Task<IReadOnlyList<LabelJob>> GetLabelJobsAsync(Guid branchId, string? status, CancellationToken ct);
    Task AcknowledgePrintAsync(Guid printJobId, Guid branchId, AckPrintRequest request, CancellationToken ct);
    Task<JsonElement> ExceptionsAsync(Guid branch, CancellationToken ct);
    Task ReviewExceptionAsync(Guid branch, Guid exceptionId, Guid actor, string reason, CancellationToken ct);
}

public sealed class InventoryService(IInventoryStore store, NodeContext node)
{
    public Task<Page<StockRow>> GetStockAsync(Actor actor, Guid? itemId, string? after, int? limit, CancellationToken ct)
    {
        if (node.Kind == NodeKind.Branch) Guard.Branch(actor, node);
        else Guard.Role(actor, Roles.CloudReaders);
        return store.GetStockAsync(node.BranchId, itemId, after, Paging.Limit(limit), ct);
    }

    public Task<IReadOnlyList<LabelJob>> GetLabelJobsAsync(Actor actor, string? status, CancellationToken ct) =>
        store.GetLabelJobsAsync(Guard.Branch(actor, node), status, ct);

    /// <summary>The print worker reports each attempt. A failed attempt keeps the job visible as failed.</summary>
    public Task AcknowledgePrintAsync(Actor actor, Guid printJobId, AckPrintRequest request, CancellationToken ct) =>
        store.AcknowledgePrintAsync(printJobId, Guard.Branch(actor, node), request, ct);

    public Task<JsonElement> ExceptionsAsync(Actor actor, CancellationToken ct) => store.ExceptionsAsync(Guard.BranchRole(actor, node, Roles.Approvers), ct);

    public Task ReviewExceptionAsync(Actor actor, Guid id, ResolveExceptionRequest request, CancellationToken ct) =>
        store.ReviewExceptionAsync(Guard.BranchRole(actor, node, Roles.Approvers), id, actor.StaffId, Guard.Text(request.Reason, "reason", 500), ct);
}
