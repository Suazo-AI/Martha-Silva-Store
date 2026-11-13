using Savia.Contracts;
using Savia.Domain;
using System.Text.Json;

namespace Savia.Application;

public interface IPilotSalesStore
{
    Task<SalesPage> SearchAsync(Guid branch, DateOnly? from, DateOnly? to, string query, int page, int pageSize, CancellationToken ct);
    Task<SaleDetailResponse?> DetailAsync(Guid branch, Guid sale, CancellationToken ct);
    Task ReturnAsync(Guid branch, Guid location, Guid sale, PostCreditReturnRequest request, Guid actor, Guid node, CancellationToken ct);
    Task<IReadOnlyList<CustomerRow>> CustomersAsync(string query, CancellationToken ct);
    Task<IReadOnlyList<CustomerCreditRow>> CreditsAsync(string query, Guid actor, CancellationToken ct);
    Task<DayReport> DayAsync(Guid branch, DateOnly date, CancellationToken ct);
    Task<JsonElement> SummaryAsync(Guid branch, string period, DateOnly date, CancellationToken ct);
    Task<JsonElement> ExceptionsAsync(Guid branch, CancellationToken ct);
    Task ReviewExceptionAsync(Guid branch, Guid exceptionId, Guid actor, string reason, CancellationToken ct);
    Task<IReadOnlyList<long>> DenominationsAsync(CancellationToken ct);
}

public sealed class PilotSalesService(IPilotSalesStore store, NodeContext node)
{
    private Guid Manager(Actor actor)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Manager, Roles.Owner);
        return branch;
    }
    public Task<JsonElement> SummaryAsync(Actor actor, string period, DateOnly date, CancellationToken ct) =>
        store.SummaryAsync(Manager(actor), Guard.Text(period, "period", 8), date, ct);
    public Task<JsonElement> ExceptionsAsync(Actor actor, CancellationToken ct) => store.ExceptionsAsync(Manager(actor), ct);
    public Task ReviewExceptionAsync(Actor actor, Guid id, ResolveExceptionRequest request, CancellationToken ct) =>
        store.ReviewExceptionAsync(Manager(actor), id, actor.StaffId, Guard.Text(request.Reason, "reason", 500), ct);
    public Task<IReadOnlyList<long>> DenominationsAsync(Actor actor, CancellationToken ct)
    {
        Seller(actor);
        return store.DenominationsAsync(ct);
    }

    // Serialize every leaf of the same SQL response. No totals are recalculated in the export.
    public static byte[] SummaryCsv(JsonElement report)
    {
        var rows = new List<string> { "campo,valor" };
        static string Cell(string value) => "\"" + value.Replace("\"", "\"\"") + "\"";
        void Walk(JsonElement value, string path)
        {
            if (value.ValueKind == JsonValueKind.Object)
                foreach (var property in value.EnumerateObject()) Walk(property.Value, path.Length == 0 ? property.Name : path + "." + property.Name);
            else if (value.ValueKind == JsonValueKind.Array)
            {
                var index = 0;
                foreach (var entry in value.EnumerateArray()) Walk(entry, path + "[" + index++ + "]");
            }
            else rows.Add(Cell(path) + "," + Cell(value.ToString()));
        }
        Walk(report, "");
        return System.Text.Encoding.UTF8.GetBytes("\uFEFF" + string.Join("\r\n", rows) + "\r\n");
    }
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
