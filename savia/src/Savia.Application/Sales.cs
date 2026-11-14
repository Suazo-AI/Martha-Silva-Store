using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

public interface ISalesStore
{
    Task PostSaleAsync(PostSaleRequest request, Guid branchId, Guid locationId, Guid cashierId, Guid nodeId, Guid? discountApproverId, CancellationToken ct);
    Task<SaleResponse?> GetSaleAsync(Guid saleId, Guid branchId, CancellationToken ct);
    Task<SalesPage> SearchAsync(Guid branch, DateOnly? from, DateOnly? to, string query, int page, int pageSize, CancellationToken ct);
    Task<SaleDetailResponse?> DetailAsync(Guid branch, Guid sale, CancellationToken ct);
}

public sealed class SalesService(ISalesStore store, NodeContext node)
{
    /// <summary>
    /// Posts a sale in the local database of the branch. It never calls the cloud.
    /// The same <c>SaleId</c> with the same content is accepted again and changes nothing.
    /// </summary>
    public async Task<SaleResponse> PostSaleAsync(Actor actor, PostSaleRequest request, CancellationToken ct, Actor? approval = null)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.TillOperators);
        if (request.Lines is not { Length: > 0 } || request.Tenders is null)
            throw Errors.Invalid("sale.empty", "La venta necesita al menos un artículo y un pago.");
        if (request.Lines.Select(l => l.LineNumber).Distinct().Count() != request.Lines.Length ||
            request.Tenders.Select(t => t.TenderNumber).Distinct().Count() != request.Tenders.Length)
            throw Errors.Invalid("sale.duplicate_line", "Números de línea o de pago repetidos.");
        foreach (var tender in request.Tenders)
        {
            ForeignCash.Validate(tender);
            Guard.Text(tender.TenderKind, "tenderKind", 20);
            if (tender.Reference?.Length > 120)
                throw Errors.Invalid("input.text", "La referencia admite hasta 120 caracteres.");
        }
        if (request.Tenders.Count(ForeignCash.HasFields) > 1)
            throw Errors.Invalid("sale.fx", "Solo se admite un pago en dólares.");
        if (approval is not null)
        {
            Guard.Role(approval, Roles.Approvers);
            Guard.Branch(approval, node);
        }
        await store.PostSaleAsync(request, branch, node.RequireLocation(), actor.StaffId, node.NodeId, approval?.StaffId, ct);
        return await store.GetSaleAsync(request.SaleId, branch, ct)
            ?? throw Errors.NotFound("sale.not_found", "La venta no quedó registrada.");
    }

    public async Task<SaleResponse> GetSaleAsync(Actor actor, Guid saleId, CancellationToken ct) =>
        await store.GetSaleAsync(saleId, Guard.Branch(actor, node), ct)
        ?? throw Errors.NotFound("sale.not_found", "La venta no existe en esta sucursal.");

    public Task<SalesPage> SearchAsync(Actor actor, DateOnly? from, DateOnly? to, string? q, int? page, int? pageSize, CancellationToken ct)
    {
        var branch = Guard.BranchRole(actor, node, Roles.TillOperators);
        if (q?.Length > 100) throw Errors.Invalid("input.text", "La busqueda admite hasta 100 caracteres.");
        if (page is < 1 or > 1000000 || pageSize is < 1 or > 100 || from > to || from?.Year == 9999 || to?.Year == 9999)
            throw Errors.Invalid("report.range", "Rango de fechas o pagina invalida.");
        return store.SearchAsync(branch, from, to, q?.Trim() ?? "", page ?? 1, pageSize ?? 25, ct);
    }

    public async Task<SaleDetailResponse> DetailAsync(Actor actor, Guid sale, CancellationToken ct) =>
        await store.DetailAsync(Guard.BranchRole(actor, node, Roles.TillOperators), sale, ct)
        ?? throw Errors.NotFound("sale.not_found", "La venta no existe en esta sucursal.");
}
