using Savia.Application;
using Savia.Contracts;

namespace Savia.Api;

public static class ReportsEndpoints
{
    public static void Map(RouteGroupBuilder api)
    {
        api.MapGet("/reports/day", async (DateOnly date, HttpContext http, ReportsService reports, CancellationToken ct) =>
            await reports.DayAsync(http.Actor(), date, ct)).Produces<DayReport>().WithTags("reports");
        api.MapGet("/reports/summary", async (string period, DateOnly date, HttpContext http, ReportsService reports, CancellationToken ct) =>
            await reports.SummaryAsync(http.Actor(), period, date, ct)).WithTags("reports");
        api.MapGet("/reports/summary.csv", async (string period, DateOnly date, HttpContext http, ReportsService reports, CancellationToken ct) =>
            Results.File(ReportCsv.From(await reports.SummaryAsync(http.Actor(), period, date, ct)),
                "text/csv; charset=utf-8", $"reporte-{period}-{date:yyyy-MM-dd}.csv")).WithTags("reports");
        api.MapGet("/reports/kpi/business", async (string period, DateOnly date, HttpContext http, ReportsService reports, CancellationToken ct) =>
            await reports.KpiBusinessAsync(http.Actor(), period, date, ct)).WithTags("reports");
        api.MapGet("/reports/kpi/business.csv",
            async (string period, DateOnly date, HttpContext http, ReportsService reports, CancellationToken ct) =>
                Results.File(ReportCsv.From(await reports.KpiBusinessAsync(http.Actor(), period, date, ct)),
                    "text/csv; charset=utf-8", $"negocio-{period}-{date}.csv")).WithTags("reports");
        api.MapGet("/reports/kpi/team", async (string period, DateOnly date, HttpContext http, ReportsService reports, CancellationToken ct) =>
            await reports.KpiTeamAsync(http.Actor(), period, date, ct)).WithTags("reports");
        api.MapGet("/reports/kpi/team.csv", async (string period, DateOnly date, HttpContext http, ReportsService reports, CancellationToken ct) =>
            Results.File(ReportCsv.From(await reports.KpiTeamAsync(http.Actor(), period, date, ct)),
                "text/csv; charset=utf-8", $"equipo-{period}-{date}.csv")).WithTags("reports");
        api.MapGet("/reports/receiving-quality",
            async (DateOnly from, DateOnly to, HttpContext http, ReportsService reports, CancellationToken ct) =>
                await reports.QualityReportAsync(http.Actor(), from, to, ct)).WithTags("reports");
        api.MapGet("/approvals", async (HttpContext http, ReportsService reports, CancellationToken ct) =>
            await reports.ApprovalsAsync(http.Actor(), ct)).WithTags("reports");
    }
}
