using System.Text.Json;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

public interface IInventoryStore
{
    Task<IReadOnlyList<StockRow>> GetStockAsync(Guid? branchId, Guid? itemId, CancellationToken ct);
    Task<IReadOnlyList<LabelJob>> GetLabelJobsAsync(Guid branchId, string? status, CancellationToken ct);
    Task AcknowledgePrintAsync(Guid printJobId, Guid branchId, AckPrintRequest request, CancellationToken ct);
    Task<JsonElement> ExceptionsAsync(Guid branch, CancellationToken ct);
    Task ReviewExceptionAsync(Guid branch, Guid exceptionId, Guid actor, string reason, CancellationToken ct);
}

public sealed class InventoryService(IInventoryStore store, NodeContext node)
{
    public Task<IReadOnlyList<StockRow>> GetStockAsync(Actor actor, Guid? itemId, CancellationToken ct)
    {
        if (node.Kind == NodeKind.Branch) Guard.Branch(actor, node);
        else Guard.Role(actor, Roles.CloudReaders);
        return store.GetStockAsync(node.BranchId, itemId, ct);
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
