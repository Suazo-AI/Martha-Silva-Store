using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

public interface ICashStore
{
    Task OpenTillAsync(OpenTillRequest request, Guid cashierId, Guid nodeId, CancellationToken ct);
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
    Task<IReadOnlyList<long>> DenominationsAsync(CancellationToken ct);
}

public sealed class CashService(ICashStore store, NodeContext node)
{
    public async Task OpenTillAsync(Actor actor, OpenTillRequest request, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.TillOperators);
        if (await store.GetRegisterBranchAsync(request.RegisterId, ct) != branch)
            throw Errors.NotFound("cash.register_not_found", "La caja no existe en esta sucursal.");
        await store.OpenTillAsync(request, actor.StaffId, node.NodeId, ct);
    }

    public async Task RecordCashCountAsync(Actor actor, Guid tillId, RecordCashCountRequest request, CancellationToken ct)
    {
        Guard.Role(actor, Roles.TillOperators);
        await RequireTillHereAsync(actor, tillId, ct);
        if (request.Lines is not { Length: > 0 }) throw Errors.Invalid("cash.count_empty", "El arqueo necesita denominaciones.");
        await store.RecordCashCountAsync(tillId, request, actor.StaffId, ct);
    }

    public async Task<CloseTillResponse> CloseTillAsync(Actor actor, Guid tillId, CloseTillRequest request, CancellationToken ct)
    {
        Guard.Role(actor, Roles.Approvers);
        await RequireTillHereAsync(actor, tillId, ct);
        await store.CloseTillAsync(tillId, request, actor.StaffId, node.NodeId, ct);
        return await store.GetClosureAsync(tillId, ct)
            ?? throw Errors.NotFound("cash.closure_not_found", "El cierre no quedó registrado.");
    }

    public Task<IReadOnlyList<RegisterRow>> ListRegistersAsync(Actor actor, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.TillOperators);
        return store.ListRegistersAsync(branch, ct);
    }

    /// <summary>The open till of the signed-in staff member at this branch.</summary>
    public async Task<TillSummary> GetCurrentTillAsync(Actor actor, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.TillOperators);
        var till = await store.FindOpenTillAsync(actor.StaffId, branch, ct)
            ?? throw Errors.NotFound("cash.no_open_till", "No tiene un turno de caja abierto.");
        return await GetTillSummaryAsync(actor, till, ct);
    }

    /// <summary>A cashier sees only their own tills; a manager or owner sees every till of the branch.</summary>
    public async Task<TillSummary> GetTillSummaryAsync(Actor actor, Guid tillId, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.TillOperators);
        var summary = await store.GetTillSummaryAsync(tillId, branch, ct);
        var supervisor = actor.Roles.Contains(Roles.Manager) || actor.Roles.Contains(Roles.Owner);
        if (summary is null || (!supervisor && summary.CashierId != actor.StaffId))
            throw Errors.NotFound("cash.till_not_found", "El turno de caja no existe en esta sucursal.");
        return summary;
    }

    public Task<IReadOnlyList<long>> DenominationsAsync(Actor actor, CancellationToken ct)
    {
        Guard.BranchRole(actor, node, Roles.TillOperators);
        return store.DenominationsAsync(ct);
    }

    private async Task RequireTillHereAsync(Actor actor, Guid tillId, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        if (await store.GetTillBranchAsync(tillId, ct) != branch)
            throw Errors.NotFound("cash.till_not_found", "El turno de caja no existe en esta sucursal.");
    }
}
