using System.Data;
using System.Text.Json;
using Savia.Application;
using Savia.Contracts;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

public sealed class SalesStore(SqlGateway sql) : ISalesStore
{
    public Task PostSaleAsync(PostSaleRequest request, Guid branchId, Guid locationId, Guid cashierId, Guid nodeId,
        Guid? discountApproverId, CancellationToken ct)
    {
        var lines = new DataTable();
        lines.Columns.Add("LineNumber", typeof(int)); lines.Columns.Add("ItemId", typeof(Guid));
        lines.Columns.Add("Quantity", typeof(int)); lines.Columns.Add("UnitPriceMinor", typeof(long));
        lines.Columns.Add("DiscountMinor", typeof(long));
        foreach (var l in request.Lines.OrderBy(l => l.LineNumber))
            lines.Rows.Add(l.LineNumber, l.ItemId, l.Quantity, l.UnitPriceMinor, l.DiscountMinor);

        var tenders = new DataTable();
        tenders.Columns.Add("TenderNumber", typeof(int)); tenders.Columns.Add("TenderKind", typeof(string));
        tenders.Columns.Add("AmountMinor", typeof(long)); tenders.Columns.Add("CreditId", typeof(Guid));
        tenders.Columns.Add("ReceivedMinor", typeof(long)); tenders.Columns.Add("ChangeMinor", typeof(long));
        tenders.Columns.Add("Reference", typeof(string));
        foreach (var t in request.Tenders.OrderBy(t => t.TenderNumber))
            tenders.Rows.Add(t.TenderNumber, t.TenderKind, t.AmountMinor, (object?)t.CreditId ?? DBNull.Value,
                (object?)t.ReceivedMinor ?? DBNull.Value, (object?)t.ChangeMinor ?? DBNull.Value, (object?)t.Reference ?? DBNull.Value);

        return sql.ExecProcAsync("sales.usp_PostSale", ct, P("@SaleId", request.SaleId), P("@BranchId", branchId),
            P("@LocationId", locationId), P("@CashierId", cashierId), P("@CurrencyCode", request.CurrencyCode),
            P("@OriginNodeId", nodeId), Table("@Lines", "sales.SaleLineRequest", lines),
            Table("@Tenders", "sales.SaleTenderRequest", tenders), P("@CustomerId", request.CustomerId), P("@TillId", request.TillId),
            P("@DiscountApproverId", discountApproverId), P("@DiscountReason", request.DiscountReason),
            P("@StockExceptionNote", request.StockExceptionNote),
            P("@FxJson", request.Tenders.Any(ForeignCash.HasFields)
                ? JsonSerializer.Serialize(request.Tenders.Where(ForeignCash.HasFields), SqlJson.Web) : null),
            P("@SellersJson", request.Lines.Any(l => l.SellerId is not null)
                ? JsonSerializer.Serialize(request.Lines.OrderBy(l => l.LineNumber).Select(l => new { l.LineNumber, l.SellerId }), SqlJson.Web) : null));
    }

    public Task<SaleResponse?> GetSaleAsync(Guid saleId, Guid branchId, CancellationToken ct) => sql.FirstAsync(
        "SELECT Id,SubtotalMinor,DiscountMinor,TaxMinor,TotalMinor,Status FROM sales.Sales WHERE Id=@id AND BranchId=@branch",
        r => new SaleResponse(r.GetGuid(0), r.GetInt64(1), r.GetInt64(2), r.GetInt64(3), r.GetInt64(4), r.GetString(5)),
        ct, P("@id", saleId), P("@branch", branchId));

    public async Task<SalesPage> SearchAsync(Guid branch, DateOnly? from, DateOnly? to, string query, int page, int pageSize, CancellationToken ct) =>
        (await sql.ReadJson<SalesPage>("sales.usp_SearchSales", ct, P("@BranchId", branch), P("@From", from?.ToDateTime(TimeOnly.MinValue)),
            P("@To", to?.ToDateTime(TimeOnly.MinValue)), P("@Query", query), P("@Page", page), P("@PageSize", pageSize)))!;

    public Task<SaleDetailResponse?> DetailAsync(Guid branch, Guid sale, CancellationToken ct) =>
        sql.ReadJson<SaleDetailResponse>("sales.usp_GetSaleDetail", ct, P("@BranchId", branch), P("@SaleId", sale));
}
