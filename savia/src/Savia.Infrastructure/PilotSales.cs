using System.Data;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using Savia.Application;
using Savia.Contracts;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

public sealed class PilotSalesStore(SqlGateway sql) : IPilotSalesStore
{
    public Task RecordQualityAsync(Guid session, QualityRequest request, Guid actor, Guid location, CancellationToken ct) =>
        sql.ExecProcAsync("receiving.usp_RecordQuality",ct,P("@CheckId",request.CheckId),P("@ScanSessionId",session),P("@ItemId",request.ItemId),P("@Good",request.Buena),P("@Damaged",request.Danada),P("@Stained",request.Manchada),P("@Odor",request.MalOlor),P("@Missing",request.Faltante),P("@Reason",request.Reason),P("@ActorId",actor),P("@LocationId",location));
    public Task<JsonElement> QualityAsync(Guid session, Guid location, CancellationToken ct)=>
        ReadElement("receiving.usp_GetQuality",ct,P("@ScanSessionId",session),P("@LocationId",location));
    public Task<JsonElement> QualityReportAsync(Guid branch, DateOnly from, DateOnly to, CancellationToken ct)=>
        ReadElement("receiving.usp_QualityReport",ct,P("@BranchId",branch),P("@From",from.ToDateTime(TimeOnly.MinValue)),P("@To",to.ToDateTime(TimeOnly.MinValue)));
    public Task<JsonElement> ItemValuesAsync(Guid branch, Guid actor, string query, CancellationToken ct) =>
        ReadElement("catalog.usp_GetItemValues",ct,P("@BranchId",branch),P("@ActorId",actor),P("@Query",query));
    public Task SetItemValuesAsync(Guid item, ItemValuesRequest request, Guid actor, Guid node, CancellationToken ct) =>
        sql.ExecProcAsync("catalog.usp_SetItemValues",ct,P("@ChangeId",request.ChangeId),P("@ItemId",item),P("@NewPriceMinor",request.PriceMinor),P("@NewCostMinor",request.CostMinor),P("@ActorId",actor),P("@OriginNodeId",node),P("@Reason",request.Reason));
    public Task<JsonElement> SellersAsync(Guid branch, CancellationToken ct) =>
        ReadElement("sales.usp_ListSellers", ct, P("@BranchId", branch));
    public Task<JsonElement> CommissionsAsync(Guid branch, Guid actor, string period, DateOnly date, CancellationToken ct) =>
        ReadElement("sales.usp_GetCommissions", ct, P("@BranchId", branch),P("@ActorId",actor),P("@Period",period),P("@Date",date.ToDateTime(TimeOnly.MinValue)));
    public Task SetSellerRateAsync(Guid seller, SellerRateRequest request, Guid actor, CancellationToken ct) =>
        sql.ExecProcAsync("sales.usp_SetSellerRate", ct,P("@SellerId",seller),P("@ChangeId",request.ChangeId),P("@RateBps",request.RateBps),P("@Reason",request.Reason),P("@ActorId",actor));
    public Task<JsonElement> ApprovalsAsync(Guid branch, Guid actor, CancellationToken ct) =>
        ReadElement("security.usp_ListApprovals", ct, P("@BranchId", branch), P("@ActorId", actor));
    private async Task<JsonElement> ReadElement(string proc, CancellationToken ct, params SqlParameter[] args)
    {
        var rows = await sql.QueryProcAsync(proc, r => r.IsDBNull(0) ? "[]" : r.GetString(0), ct, args);
        using var document = JsonDocument.Parse(rows.Single());
        return document.RootElement.Clone();
    }
    public Task<JsonElement> SummaryAsync(Guid branch, string period, DateOnly date, CancellationToken ct) =>
        ReadElement("sales.usp_GetPeriodSummary", ct, P("@BranchId", branch), P("@Period", period), P("@Date", date.ToDateTime(TimeOnly.MinValue)));
    public Task<JsonElement> ExceptionsAsync(Guid branch, CancellationToken ct) =>
        ReadElement("sales.usp_ListStockExceptions", ct, P("@BranchId", branch));
    public Task ReviewExceptionAsync(Guid branch, Guid exceptionId, Guid actor, string reason, CancellationToken ct) =>
        sql.ExecProcAsync("sales.usp_ReviewStockException", ct, P("@BranchId", branch), P("@ExceptionId", exceptionId), P("@ActorId", actor), P("@Reason", reason));
    public async Task<IReadOnlyList<long>> DenominationsAsync(CancellationToken ct) =>
        await sql.QueryAsync("SELECT DenominationMinor FROM sales.CashDenominations ORDER BY DenominationMinor DESC", r => r.GetInt64(0), ct);
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private async Task<T?> ReadJson<T>(string proc, CancellationToken ct, params SqlParameter[] args) where T : class
    {
        var rows = await sql.QueryProcAsync(proc, r => r.IsDBNull(0) ? null : r.GetString(0), ct, args);
        return rows.FirstOrDefault() is { Length: > 0 } text ? JsonSerializer.Deserialize<T>(text, Json) : null;
    }
    public async Task<SalesPage> SearchAsync(Guid branch, DateOnly? from, DateOnly? to, string query, int page, int pageSize, CancellationToken ct) =>
        (await ReadJson<SalesPage>("sales.usp_SearchSales", ct, P("@BranchId", branch), P("@From", from?.ToDateTime(TimeOnly.MinValue)),
            P("@To", to?.ToDateTime(TimeOnly.MinValue)), P("@Query", query), P("@Page", page), P("@PageSize", pageSize)))!;
    public Task<SaleDetailResponse?> DetailAsync(Guid branch, Guid sale, CancellationToken ct) =>
        ReadJson<SaleDetailResponse>("sales.usp_GetSaleDetail", ct, P("@BranchId", branch), P("@SaleId", sale));
    public Task ReturnAsync(Guid branch, Guid location, Guid sale, PostCreditReturnRequest request, Guid actor, Guid node, CancellationToken ct)
    {
        var lines = new DataTable();
        lines.Columns.Add("SaleLineId", typeof(Guid)); lines.Columns.Add("Quantity", typeof(int)); lines.Columns.Add("RestockPool", typeof(string));
        foreach (var line in request.Lines) lines.Rows.Add(line.SaleLineId, line.Quantity, line.RestockPool);
        return sql.ExecProcAsync("sales.usp_PostCreditReturn", ct, P("@ReversalId", request.ReversalId), P("@CreditId", request.CreditId),
            P("@SaleId", sale), P("@BranchId", branch), P("@ReturnLocationId", location), P("@TillId", request.TillId),
            P("@ActorId", actor), P("@ApprovedBy", actor), P("@CustomerId", request.CustomerId), P("@Reason", request.Reason),
            P("@OriginNodeId", node), Table("@Lines", "sales.ReturnLineRequest", lines));
    }
    public async Task<IReadOnlyList<CustomerRow>> CustomersAsync(string query, CancellationToken ct) =>
        await sql.QueryProcAsync("crm.usp_SearchCustomers", r => new CustomerRow(r.GetGuid(0), r.StringOrNull(1), r.GetString(2), r.StringOrNull(3), r.StringOrNull(4)), ct, P("@Query", query));
    public async Task<IReadOnlyList<CustomerCreditRow>> CreditsAsync(string query, Guid actor, CancellationToken ct) =>
        await sql.QueryProcAsync("credits.usp_FindCustomerCredits", r => new CustomerCreditRow(r.GetGuid(0), r.GetString(1), r.StringOrNull(2), r.StringOrNull(3),
            r.GetGuid(4), r.GetString(5), r.GetGuid(6), r.GetString(7), r.GetInt64(8)), ct, P("@Query", query), P("@ActorId", actor));
    public async Task<DayReport> DayAsync(Guid branch, DateOnly date, CancellationToken ct) =>
        (await ReadJson<DayReport>("sales.usp_GetDayReport", ct, P("@BranchId", branch), P("@Date", date.ToDateTime(TimeOnly.MinValue))))!;
}
