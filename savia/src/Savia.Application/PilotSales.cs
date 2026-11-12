using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

public interface IPilotSalesStore
{
    Task<SalesPage> SearchAsync(Guid branch, DateOnly? from, DateOnly? to, string query, int page, int pageSize, CancellationToken ct);
    Task<SaleDetailResponse?> DetailAsync(Guid branch, Guid sale, CancellationToken ct);
    Task ReturnAsync(Guid branch, Guid location, Guid sale, PostCreditReturnRequest request, Guid actor, Guid node, CancellationToken ct);
    Task<IReadOnlyList<CustomerRow>> CustomersAsync(string query, CancellationToken ct);
    Task<IReadOnlyList<CustomerCreditRow>> CreditsAsync(string query, Guid actor, CancellationToken ct);
    Task<DayReport> DayAsync(Guid branch, DateOnly date, CancellationToken ct);
}

public sealed class PilotSalesService(IPilotSalesStore store, NodeContext node)
{
    private Guid Seller(Actor actor)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Cashier, Roles.Manager, Roles.Owner);
        return branch;
    }
    public Task<SalesPage> SearchAsync(Actor actor, DateOnly? from, DateOnly? to, string? q, int? page, int? pageSize, CancellationToken ct)
    {
        var branch = Seller(actor);
        if (q?.Length > 100) throw Errors.Invalid("input.text", "La busqueda admite hasta 100 caracteres.");
        if (page is < 1 or > 1000000 || pageSize is < 1 or > 100 || from > to || from?.Year == 9999 || to?.Year == 9999)
            throw Errors.Invalid("report.range", "Rango de fechas o pagina invalida.");
        return store.SearchAsync(branch, from, to, q?.Trim() ?? "", page ?? 1, pageSize ?? 25, ct);
    }
    public async Task<SaleDetailResponse> DetailAsync(Actor actor, Guid sale, CancellationToken ct) =>
        await store.DetailAsync(Seller(actor), sale, ct) ?? throw Errors.NotFound("sale.not_found", "La venta no existe en esta sucursal.");
    public async Task<SaleReversal> ReturnAsync(Actor actor, Guid sale, PostCreditReturnRequest request, CancellationToken ct)
    {
        var branch = Seller(actor);
        Guard.Role(actor, Roles.Manager, Roles.Owner);
        Guard.Text(request.Reason, "reason", 500);
        if (request.Lines is not { Length: > 0 } || request.Lines.Select(l => l.SaleLineId).Distinct().Count() != request.Lines.Length)
            throw Errors.Invalid("return.lines", "Indique lineas de devolucion sin duplicados.");
        foreach (var line in request.Lines) Guard.Text(line.RestockPool, "restockPool", 12);
        // Approval is the authenticated supervisor, never an approver id supplied by the browser.
        await store.ReturnAsync(branch, node.RequireLocation(), sale, request, actor.StaffId, node.NodeId, ct);
        var detail = await DetailAsync(actor, sale, ct);
        return detail.Reversals.Single(r => r.ReversalId == request.ReversalId);
    }
    public Task<IReadOnlyList<CustomerRow>> CustomersAsync(Actor actor, string q, CancellationToken ct)
    {
        Seller(actor);
        return store.CustomersAsync(Guard.Text(q, "q", 100).Trim(), ct);
    }
    public Task<IReadOnlyList<CustomerCreditRow>> CreditsAsync(Actor actor, string q, CancellationToken ct)
    {
        Seller(actor);
        return store.CreditsAsync(Guard.Text(q, "q", 100).Trim(), actor.StaffId, ct);
    }
    public Task<DayReport> DayAsync(Actor actor, DateOnly date, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Manager, Roles.Owner);
        if (date.Year == 9999) throw Errors.Invalid("report.range", "Fecha invalida.");
        return store.DayAsync(branch, date, ct);
    }
}
