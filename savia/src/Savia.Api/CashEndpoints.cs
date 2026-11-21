using Savia.Application;
using Savia.Contracts;

namespace Savia.Api;

public static class CashEndpoints
{
    public static void Map(RouteGroupBuilder api)
    {
        api.MapGet("/cash/registers", async (HttpContext http, CashService cash, CancellationToken ct) =>
            await cash.ListRegistersAsync(http.Actor(), ct)).Produces<RegisterRow[]>().WithTags("cash");
        api.MapGet("/cash/tills/current", async (HttpContext http, CashService cash, CancellationToken ct) =>
            await cash.GetCurrentTillAsync(http.Actor(), ct)).Produces<TillSummary>().WithTags("cash");
        api.MapGet("/cash/tills/{tillId:guid}/summary", async (Guid tillId, HttpContext http, CashService cash, CancellationToken ct) =>
            await cash.GetTillSummaryAsync(http.Actor(), tillId, ct)).Produces<TillSummary>().WithTags("cash");
        api.MapPost("/cash/tills", async (OpenTillRequest request, HttpContext http, CashService cash, CancellationToken ct) =>
        {
            await cash.OpenTillAsync(http.Actor(), request, ct);
            return Results.NoContent();
        }).WithTags("cash");
        api.MapPost("/cash/tills/{tillId:guid}/counts",
            async (Guid tillId, RecordCashCountRequest request, HttpContext http, CashService cash, CancellationToken ct) =>
            {
                await cash.RecordCashCountAsync(http.Actor(), tillId, request, ct);
                return Results.NoContent();
            }).WithTags("cash");
        api.MapPost("/cash/tills/{tillId:guid}/close",
            async (Guid tillId, CloseTillRequest request, HttpContext http, CashService cash, CancellationToken ct) =>
                await cash.CloseTillAsync(http.Actor(), tillId, request, ct)).WithTags("cash");
        api.MapGet("/cash/denominations", async (HttpContext http, CashService cash, CancellationToken ct) =>
            await cash.DenominationsAsync(http.Actor(), ct)).WithTags("cash");
    }
}
