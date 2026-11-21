using System.Text.Json;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

public interface IReportsStore
{
    Task<JsonElement> SummaryAsync(Guid branch, string period, DateOnly date, CancellationToken ct);
    Task<DayReport> DayAsync(Guid branch, DateOnly date, CancellationToken ct);
    Task<JsonElement> KpiBusinessAsync(Guid branch, Guid actor, string period, DateOnly date, CancellationToken ct);
    Task<JsonElement> KpiTeamAsync(Guid branch, Guid actor, string period, DateOnly date, CancellationToken ct);
    Task<JsonElement> QualityReportAsync(Guid branch, DateOnly from, DateOnly to, CancellationToken ct);
    Task<JsonElement> ApprovalsAsync(Guid branch, Guid actor, CancellationToken ct);
}

public sealed class ReportsService(IReportsStore store, NodeContext node)
{
    public Task<JsonElement> SummaryAsync(Actor actor, string period, DateOnly date, CancellationToken ct) =>
        store.SummaryAsync(Guard.BranchRole(actor, node, Roles.Approvers), Guard.Text(period, "period", 8), date, ct);

    public Task<DayReport> DayAsync(Actor actor, DateOnly date, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Approvers);
        if (date.Year == 9999) throw Errors.Invalid("report.range", "Fecha invalida.");
        return store.DayAsync(branch, date, ct);
    }

    private static string Period(string period) =>
        period is "day" or "week" or "month" or "year" ? period : throw Errors.Invalid("report.range", "Periodo invalido.");

    public Task<JsonElement> KpiBusinessAsync(Actor actor, string period, DateOnly date, CancellationToken ct) =>
        store.KpiBusinessAsync(Guard.BranchRole(actor, node, Roles.Approvers), actor.StaffId, Period(period), date, ct);

    public Task<JsonElement> KpiTeamAsync(Actor actor, string period, DateOnly date, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.CommissionReaders);
        return store.KpiTeamAsync(branch, actor.StaffId, Period(period), date, ct);
    }

    public Task<JsonElement> QualityReportAsync(Actor actor, DateOnly from, DateOnly to, CancellationToken ct) =>
        store.QualityReportAsync(Guard.BranchRole(actor, node, Roles.StockWorkers), from, to, ct);

    public Task<JsonElement> ApprovalsAsync(Actor actor, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.OwnerOnly);
        return store.ApprovalsAsync(branch, actor.StaffId, ct);
    }
}
