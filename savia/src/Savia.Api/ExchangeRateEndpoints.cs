using Savia.Application;
using Savia.Contracts;

namespace Savia.Api;

public static class ExchangeRateEndpoints
{
    public static void Map(RouteGroupBuilder api)
    {
        api.MapGet("/exchange-rate", async (HttpContext http, ExchangeRateService rates, CancellationToken ct) =>
            await rates.CurrentAsync(http.Actor(), ct));
        api.MapPost("/exchange-rates", async (ExchangeRateRequest request, HttpContext http, ExchangeRateService rates, CancellationToken ct) =>
        {
            await rates.SetAsync(http.Actor(), request, ct);
            return Results.NoContent();
        });
    }
}
