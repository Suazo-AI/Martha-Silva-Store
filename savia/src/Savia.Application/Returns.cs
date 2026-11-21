using System.Text.Json;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

public interface IReturnsStore
{
    Task ReturnAsync(Guid branch, Guid location, Guid sale, PostCreditReturnRequest request, Guid actor, Guid node, CancellationToken ct);
    Task ReturnOutcomeAsync(Guid branch, Guid location, Guid sale, PostReturnOutcomeRequest request, Guid actor, Guid node, CancellationToken ct);
    Task<JsonElement> ReturnPolicyAsync(Guid branch, CancellationToken ct);
    Task SetReturnWindowAsync(Guid branch, ReturnWindowRequest request, Guid actor, CancellationToken ct);
}

public sealed class ReturnsService(IReturnsStore store, SalesService sales, NodeContext node)
{
    private static readonly string[] Outcomes = ["cash", "transfer", "exchange"];

    public async Task<SaleReversal> ReturnAsync(Actor actor, Guid sale, PostCreditReturnRequest request, CancellationToken ct)
    {
        var branch = Guard.BranchRole(actor, node, Roles.TillOperators);
        Guard.Role(actor, Roles.Approvers);
        Guard.Text(request.Reason, "reason", 500);
        if (request.Lines is not { Length: > 0 } || request.Lines.Select(l => l.SaleLineId).Distinct().Count() != request.Lines.Length)
            throw Errors.Invalid("return.lines", "Indique lineas de devolucion sin duplicados.");
        foreach (var line in request.Lines) Guard.Text(line.RestockPool, "restockPool", 12);
        // Approval is the authenticated supervisor, never an approver id supplied by the browser.
        await store.ReturnAsync(branch, node.RequireLocation(), sale, request, actor.StaffId, node.NodeId, ct);
        var detail = await sales.DetailAsync(actor, sale, ct);
        return detail.Reversals.Single(r => r.ReversalId == request.ReversalId);
    }

    public async Task<SaleReversal> ReturnOutcomeAsync(Actor actor, Guid sale, PostReturnOutcomeRequest request, CancellationToken ct)
    {
        var branch = Guard.BranchRole(actor, node, Roles.TillOperators);
        Guard.Role(actor, Roles.Approvers);
        Guard.Text(request.Reason, "reason", 500);
        if (!Outcomes.Contains(request.Outcome))
            throw Errors.Invalid("return.outcome", "Elija cambio, efectivo o transferencia; el credito usa la devolucion a credito.");
        if (request.Lines is not { Length: > 0 } || request.Lines.Select(l => l.SaleLineId).Distinct().Count() != request.Lines.Length)
            throw Errors.Invalid("return.lines", "Indique lineas de devolucion sin duplicados.");
        foreach (var line in request.Lines) Guard.Text(line.RestockPool, "restockPool", 12);
        if (request.Reference?.Length > 120 || request.DifferenceReference?.Length > 120)
            throw Errors.Invalid("input.text", "La referencia admite hasta 120 caracteres.");
        if (request.NewLines?.Length > 50 || request.NewTenders?.Length > 10) throw Errors.Invalid("return.exchange_lines", "Demasiadas lineas en el cambio.");
        if (request.NewTenders?.Any(ForeignCash.HasFields) == true)
            throw Errors.Invalid("return.fx", "El cambio no admite dólares.");
        await store.ReturnOutcomeAsync(branch, node.RequireLocation(), sale, request, actor.StaffId, node.NodeId, ct);
        var detail = await sales.DetailAsync(actor, sale, ct);
        return detail.Reversals.Single(r => r.ReversalId == request.ReversalId);
    }

    public Task<JsonElement> ReturnPolicyAsync(Actor actor, CancellationToken ct) =>
        store.ReturnPolicyAsync(Guard.BranchRole(actor, node, Roles.TillOperators), ct);

    public Task SetReturnWindowAsync(Actor actor, ReturnWindowRequest request, CancellationToken ct)
    {
        var branch = Guard.BranchRole(actor, node, Roles.OwnerOnly);
        Guard.Text(request.Reason, "reason", 250);
        return store.SetReturnWindowAsync(branch, request, actor.StaffId, ct);
    }
}
