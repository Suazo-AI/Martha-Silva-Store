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
    Task<JsonElement> ApprovalsAsync(Guid branch, Guid actor, CancellationToken ct);
    Task<JsonElement> SellersAsync(Guid branch, CancellationToken ct);
    Task<JsonElement> CommissionsAsync(Guid branch, Guid actor, string period, DateOnly date, CancellationToken ct);
    Task SetSellerRateAsync(Guid seller, SellerRateRequest request, Guid actor, CancellationToken ct);
    Task<JsonElement> ItemValuesAsync(Guid branch, Guid actor, string query, CancellationToken ct);
    Task SetItemValuesAsync(Guid item, ItemValuesRequest request, Guid actor, Guid node, CancellationToken ct);
    Task RecordQualityAsync(Guid session, QualityRequest request, Guid actor, Guid location, CancellationToken ct);
    Task<JsonElement> QualityAsync(Guid session, Guid location, CancellationToken ct);
    Task<JsonElement> QualityReportAsync(Guid branch, DateOnly from, DateOnly to, CancellationToken ct);
    Task ReturnOutcomeAsync(Guid branch, Guid location, Guid sale, PostReturnOutcomeRequest request, Guid actor, Guid node, CancellationToken ct);
    Task<JsonElement> ReturnPolicyAsync(Guid branch, CancellationToken ct);
    Task SetReturnWindowAsync(Guid branch, ReturnWindowRequest request, Guid actor, CancellationToken ct);
    Task<JsonElement> KpiBusinessAsync(Guid branch, Guid actor, string period, DateOnly date, CancellationToken ct);
    Task<JsonElement> KpiTeamAsync(Guid branch, Guid actor, string period, DateOnly date, CancellationToken ct);
    Task<JsonElement> ImportCatalogAsync(Guid branch, Guid location, ImportCatalogRequest request, Guid actor, Guid node, bool commit, CancellationToken ct);
}

public sealed class PilotSalesService(IPilotSalesStore store, NodeContext node)
{
    private Guid StockWorker(Actor actor)
    {
        var branch=Guard.Branch(actor,node);Guard.Role(actor,Roles.Inventory,Roles.Manager,Roles.Owner);return branch;
    }
    public Task RecordQualityAsync(Actor actor,Guid session,QualityRequest request,CancellationToken ct)
    {
        StockWorker(actor);Guard.Text(request.Reason,"reason",250);
        return store.RecordQualityAsync(session,request,actor.StaffId,node.RequireLocation(),ct);
    }
    public Task<JsonElement> QualityAsync(Actor actor,Guid session,CancellationToken ct)
    {
        StockWorker(actor);return store.QualityAsync(session,node.RequireLocation(),ct);
    }
    public Task<JsonElement> QualityReportAsync(Actor actor,DateOnly from,DateOnly to,CancellationToken ct)=>
        store.QualityReportAsync(StockWorker(actor),from,to,ct);
    public Task<JsonElement> ItemValuesAsync(Actor actor,string? query,CancellationToken ct) =>
        store.ItemValuesAsync(Manager(actor),actor.StaffId,query?.Trim() ?? "",ct);
    public Task SetItemValuesAsync(Actor actor,Guid item,ItemValuesRequest request,CancellationToken ct)
    {
        Guard.Branch(actor,node); Guard.Role(actor,Roles.Owner); Guard.Text(request.Reason,"reason",250);
        return store.SetItemValuesAsync(item,request,actor.StaffId,node.NodeId,ct);
    }
    public Task<JsonElement> SellersAsync(Actor actor, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Seller, Roles.Manager, Roles.Owner, Roles.Cashier);
        return store.SellersAsync(branch, ct);
    }
    public Task<JsonElement> CommissionsAsync(Actor actor, string period, DateOnly date, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Seller, Roles.Manager, Roles.Owner);
        return store.CommissionsAsync(branch, actor.StaffId, period, date, ct);
    }
    public Task SetSellerRateAsync(Actor actor, Guid seller, SellerRateRequest request, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Owner);
        Guard.Text(request.Reason,"reason",250);
        return store.SetSellerRateAsync(seller,request,actor.StaffId,ct);
    }
    public Task<JsonElement> ApprovalsAsync(Actor actor, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Owner);
        return store.ApprovalsAsync(branch, actor.StaffId, ct);
    }
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
    private static readonly string[] Outcomes = ["cash", "transfer", "exchange"];
    public async Task<SaleReversal> ReturnOutcomeAsync(Actor actor, Guid sale, PostReturnOutcomeRequest request, CancellationToken ct)
    {
        var branch = Seller(actor);
        Guard.Role(actor, Roles.Manager, Roles.Owner);
        Guard.Text(request.Reason, "reason", 500);
        if (!Outcomes.Contains(request.Outcome)) throw Errors.Invalid("return.outcome", "Elija cambio, efectivo o transferencia; el credito usa la devolucion a credito.");
        if (request.Lines is not { Length: > 0 } || request.Lines.Select(l => l.SaleLineId).Distinct().Count() != request.Lines.Length)
            throw Errors.Invalid("return.lines", "Indique lineas de devolucion sin duplicados.");
        foreach (var line in request.Lines) Guard.Text(line.RestockPool, "restockPool", 12);
        if (request.Reference?.Length > 120 || request.DifferenceReference?.Length > 120) throw Errors.Invalid("input.text", "La referencia admite hasta 120 caracteres.");
        if (request.NewLines?.Length > 50 || request.NewTenders?.Length > 10) throw Errors.Invalid("return.exchange_lines", "Demasiadas lineas en el cambio.");
        await store.ReturnOutcomeAsync(branch, node.RequireLocation(), sale, request, actor.StaffId, node.NodeId, ct);
        var detail = await DetailAsync(actor, sale, ct);
        return detail.Reversals.Single(r => r.ReversalId == request.ReversalId);
    }
    public Task<JsonElement> ReturnPolicyAsync(Actor actor, CancellationToken ct) => store.ReturnPolicyAsync(Seller(actor), ct);
    public Task SetReturnWindowAsync(Actor actor, ReturnWindowRequest request, CancellationToken ct)
    {
        var branch = Owner(actor);
        Guard.Text(request.Reason, "reason", 250);
        return store.SetReturnWindowAsync(branch, request, actor.StaffId, ct);
    }
    private static string Period(string period) =>
        period is "day" or "week" or "month" or "year" ? period : throw Errors.Invalid("report.range", "Periodo invalido.");
    public Task<JsonElement> KpiBusinessAsync(Actor actor, string period, DateOnly date, CancellationToken ct) =>
        store.KpiBusinessAsync(Manager(actor), actor.StaffId, Period(period), date, ct);
    public Task<JsonElement> KpiTeamAsync(Actor actor, string period, DateOnly date, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Seller, Roles.Manager, Roles.Owner);
        return store.KpiTeamAsync(branch, actor.StaffId, Period(period), date, ct);
    }
    private Guid Owner(Actor actor)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Owner);
        return branch;
    }
    public ImportFile ParseImport(Actor actor, ImportFileRequest request)
    {
        Owner(actor);
        Guard.Text(request.FileName, "fileName", 200);
        byte[] content;
        try { content = Convert.FromBase64String(request.ContentBase64 ?? ""); }
        catch (FormatException) { throw Errors.Invalid("import.format", "El archivo no se pudo leer."); }
        return CatalogFile.Parse(request.FileName, content);
    }
    public Task<JsonElement> ImportCatalogAsync(Actor actor, ImportCatalogRequest request, bool commit, CancellationToken ct)
    {
        var branch = Owner(actor);
        Guard.Text(request.FileName, "fileName", 200);
        if (request.Rows is not { Length: > 0 } || request.Rows.Length > CatalogFile.MaxRows)
            throw Errors.Invalid("import.size", $"El archivo debe tener entre 1 y {CatalogFile.MaxRows} filas.");
        return store.ImportCatalogAsync(branch, node.RequireLocation(), request, actor.StaffId, node.NodeId, commit, ct);
    }
    public Task<DayReport> DayAsync(Actor actor, DateOnly date, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Manager, Roles.Owner);
        if (date.Year == 9999) throw Errors.Invalid("report.range", "Fecha invalida.");
        return store.DayAsync(branch, date, ct);
    }
}
