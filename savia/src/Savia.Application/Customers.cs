using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

public interface ICustomersStore
{
    Task<IReadOnlyList<CustomerRow>> CustomersAsync(string query, CancellationToken ct);
    Task<IReadOnlyList<CustomerCreditRow>> CreditsAsync(string query, Guid actor, CancellationToken ct);
    Task CreateAsync(CreateCustomerRequest request, Guid actor, CancellationToken ct);
    Task<IReadOnlyList<CreditTransferRow>> TransfersAsync(Guid? branch, CancellationToken ct);
    Task RequestTransferAsync(RequestCreditTransferRequest request, Guid actor, Guid node, CancellationToken ct);
    Task DecideTransferAsync(Guid transfer, TransferStep step, Guid actor, Guid node, CancellationToken ct, string? reason = null);
}

/// <summary>The transfer writes after the request, each on the node that owns it (V009): the hub approves and
/// cancels, the origin store dispatches, the destination store receives.</summary>
public enum TransferStep { Approve, Cancel, Dispatch, Receive }

public sealed class CustomersService(ICustomersStore store, NodeContext node)
{
    public Task<IReadOnlyList<CustomerRow>> CustomersAsync(Actor actor, string q, CancellationToken ct)
    {
        Guard.BranchRole(actor, node, Roles.TillOperators);
        return store.CustomersAsync(Guard.Text(q, "q", 100).Trim(), ct);
    }

    /// <summary>The store that creates a customer owns the row; it reaches the hub and the other stores by sync (V053).</summary>
    public Task CreateAsync(Actor actor, CreateCustomerRequest request, CancellationToken ct)
    {
        Guard.BranchRole(actor, node, Roles.TillOperators);
        Guard.Text(request.DisplayName, "displayName", 200);
        Optional(request.DocumentNumber, "documentNumber", 40);
        Optional(request.Phone, "phone", 40);
        Optional(request.Email, "email", 254);
        return store.CreateAsync(request, actor.StaffId, ct);
    }

    /// <summary>A store lists the transfers of its own branch; the hub lists every branch's.</summary>
    public Task<IReadOnlyList<CreditTransferRow>> TransfersAsync(Actor actor, CancellationToken ct)
    {
        if (node.Kind == NodeKind.Cloud)
        {
            Guard.Role(actor, Roles.Approvers);
            return store.TransfersAsync(null, ct);
        }
        return store.TransfersAsync(Guard.BranchRole(actor, node, Roles.TillOperators), ct);
    }

    /// <summary>V010: the customer may ask at the origin or the destination; the request is written on that store.</summary>
    public Task RequestTransferAsync(Actor actor, RequestCreditTransferRequest request, CancellationToken ct)
    {
        Guard.BranchRole(actor, node, Roles.TillOperators);
        Guard.Text(request.Reason, "reason", 400);
        return store.RequestTransferAsync(request, actor.StaffId, node.NodeId, ct);
    }

    public Task DecideTransferAsync(Actor actor, Guid transfer, TransferStep step, CancellationToken ct, string? reason = null)
    {
        if (step is TransferStep.Approve or TransferStep.Cancel)
        {
            Guard.Kind(node, NodeKind.Cloud);
            Guard.Role(actor, Roles.Approvers);
            if (step == TransferStep.Cancel) Guard.Text(reason, "reason", 400);
        }
        else Guard.BranchRole(actor, node, Roles.TillOperators);
        return store.DecideTransferAsync(transfer, step, actor.StaffId, node.NodeId, ct, reason);
    }

    private static void Optional(string? value, string field, int max)
    {
        if (value is { Length: > 0 }) Guard.Text(value, field, max);
    }

    public Task<IReadOnlyList<CustomerCreditRow>> CreditsAsync(Actor actor, string q, CancellationToken ct)
    {
        Guard.BranchRole(actor, node, Roles.TillOperators);
        return store.CreditsAsync(Guard.Text(q, "q", 100).Trim(), actor.StaffId, ct);
    }
}
