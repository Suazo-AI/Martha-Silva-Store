using System.Data;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using Savia.Application;
using Savia.Contracts;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

public sealed class PilotSalesStore(SqlGateway sql) : IPilotSalesStore
{
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
