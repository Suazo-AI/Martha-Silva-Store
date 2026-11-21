using Savia.Application;
using Savia.Contracts;

namespace Savia.Api;

public static class CommissionsEndpoints
{
    public static void Map(RouteGroupBuilder api)
    {
        api.MapGet("/sellers", async (HttpContext http, CommissionsService commissions, CancellationToken ct) =>
            await commissions.SellersAsync(http.Actor(), ct)).WithTags("commissions");
        api.MapGet("/reports/commissions",
            async (string period, DateOnly date, HttpContext http, CommissionsService commissions, CancellationToken ct) =>
                await commissions.CommissionsAsync(http.Actor(), period, date, ct)).WithTags("commissions");
        api.MapGet("/reports/commissions.csv",
            async (string period, DateOnly date, HttpContext http, CommissionsService commissions, CancellationToken ct) =>
                Results.File(ReportCsv.From(await commissions.CommissionsAsync(http.Actor(), period, date, ct)),
                    "text/csv; charset=utf-8", $"comisiones-{period}-{date}.csv")).WithTags("commissions");
        api.MapPost("/sellers/{sellerId:guid}/rate",
            async (Guid sellerId, SellerRateRequest request, HttpContext http, CommissionsService commissions, CancellationToken ct) =>
            {
                await commissions.SetSellerRateAsync(http.Actor(), sellerId, request, ct);
                return Results.NoContent();
            }).WithTags("commissions");
    }
}
