using System.Text.Json;
using Savia.Application;
using Savia.Contracts;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

public sealed class ReportsStore(SqlGateway sql) : IReportsStore
{
    public Task<JsonElement> SummaryAsync(Guid branch, string period, DateOnly date, CancellationToken ct) =>
        sql.ReadElement("sales.usp_GetPeriodSummary", ct, P("@BranchId", branch), P("@Period", period), P("@Date", date.ToDateTime(TimeOnly.MinValue)));

    public async Task<DayReport> DayAsync(Guid branch, DateOnly date, CancellationToken ct)
    {
        var report = (await sql.ReadJson<DayReport>("sales.usp_GetDayReport", ct, P("@BranchId", branch), P("@Date", date.ToDateTime(TimeOnly.MinValue))))!;
        var kinds = await sql.ReadJson<DayRefundKind[]>("sales.usp_GetReturnsByKind", ct,
            P("@BranchId", branch), P("@Date", date.ToDateTime(TimeOnly.MinValue)));
        return report with { RefundsByKind = kinds ?? [] };
    }

    public Task<JsonElement> KpiBusinessAsync(Guid branch, Guid actor, string period, DateOnly date, CancellationToken ct) =>
        sql.ReadElement("sales.usp_KpiBusiness", ct, P("@BranchId", branch), P("@ActorId", actor),
            P("@Period", period), P("@Date", date.ToDateTime(TimeOnly.MinValue)));

    public Task<JsonElement> KpiTeamAsync(Guid branch, Guid actor, string period, DateOnly date, CancellationToken ct) =>
        sql.ReadElement("sales.usp_KpiTeam", ct, P("@BranchId", branch), P("@ActorId", actor),
            P("@Period", period), P("@Date", date.ToDateTime(TimeOnly.MinValue)));

    public Task<JsonElement> QualityReportAsync(Guid branch, DateOnly from, DateOnly to, CancellationToken ct) =>
        sql.ReadElement("receiving.usp_QualityReport", ct, P("@BranchId", branch), P("@From", from.ToDateTime(TimeOnly.MinValue)),
            P("@To", to.ToDateTime(TimeOnly.MinValue)));

    public Task<JsonElement> ApprovalsAsync(Guid branch, Guid actor, CancellationToken ct) =>
        sql.ReadElement("security.usp_ListApprovals", ct, P("@BranchId", branch), P("@ActorId", actor));
}
