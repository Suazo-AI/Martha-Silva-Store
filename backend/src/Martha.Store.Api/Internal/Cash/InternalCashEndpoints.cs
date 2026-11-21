using System.Globalization;
namespace Martha.Store.Api.Internal;

public static class InternalCashEndpoints
{
    public static IServiceCollection AddInternalCash(this IServiceCollection services, IConfiguration configuration)
    {
        // Explicit synthetic configuration; absence fails cash admission, never guesses real money.
        var currency = configuration["InternalSavia:Cash:Currency"] ?? "";
        var exponent = int.TryParse(configuration["InternalSavia:Cash:Exponent"], out var value) ? value : -1;
        return services.AddSingleton(new InternalCashOptions(currency, exponent)).AddScoped<InternalCashService>().AddScoped<InternalCashReadService>();
    }
    public static IEndpointRouteBuilder MapInternalCash(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/internal/api/cash").RequireAuthorization("internal.sell");
        group.MapGet("/context", async (InternalCashReadService service, HttpContext http, CancellationToken ct) => {
            http.Response.Headers.CacheControl = "no-store";
            return Result(await service.Context(http.User, ct));
        });
        group.MapGet("/sales/{saleId:guid}/refund-context", async (Guid saleId, int? skip, int? take, InternalCashReadService service, HttpContext http, CancellationToken ct) => {
            http.Response.Headers.CacheControl = "no-store";
            return Result(await service.RefundContext(saleId, skip ?? 0, take ?? 50, http.User, ct));
        }).RequireAuthorization("internal.manage");
        group.MapPost("/tills", async (InternalCashOpenRequest request, InternalCashService service, HttpContext http, CancellationToken ct) =>
            Result(await service.Open(request, InternalActor.Id(http.User), Key(http), ct))).RequireInternalCsrf();
        group.MapPost("/sales", async (InternalCashSaleRequest request, InternalCashService service, HttpContext http, CancellationToken ct) =>
            Result(await service.Sell(request, InternalActor.Id(http.User), Key(http), ct))).RequireInternalCsrf();
        group.MapPost("/sales/{saleId:guid}/refunds", async (Guid saleId, InternalCashRefundRequest request, InternalCashService service, HttpContext http, CancellationToken ct) =>
            Result(await service.Refund(saleId, request, InternalActor.Id(http.User), Key(http), ct))).RequireAuthorization("internal.manage").RequireInternalCsrf();
        group.MapPost("/tills/{tillId:guid}/close", async (Guid tillId, InternalCashCloseRequest request, InternalCashService service, HttpContext http, CancellationToken ct) =>
            Result(await service.Close(tillId, request, InternalActor.Id(http.User), Key(http), ct))).RequireInternalCsrf();
        group.MapGet("/closing-report.csv", async (string? from, string? to, InternalCashService service, HttpContext http, CancellationToken ct) =>
        {
            var today = DateOnly.FromDateTime(DateTime.UtcNow);
            if (!TryDay(from, today.AddDays(-30), out var start) || !TryDay(to, today, out var end) || start > end)
                return Results.BadRequest(new { error = "invalid_range" });
            http.Response.Headers.CacheControl = "no-store";
            return Results.Text(await service.ClosingReport(start, end, ct, InternalActor.Id(http.User)), "text/csv; charset=utf-8");
        }).RequireAuthorization("internal.manage");
        return endpoints;
    }

    private static bool TryDay(string? value, DateOnly fallback, out DateOnly day)
    {
        if (string.IsNullOrWhiteSpace(value)) { day = fallback; return true; }
        return DateOnly.TryParse(value, CultureInfo.InvariantCulture, DateTimeStyles.None, out day);
    }
    private static string Key(HttpContext http) => http.Request.Headers["Idempotency-Key"] is { Count: 1 } values ? values[0] ?? "" : "";
    private static IResult Result<T>(InternalResult<T> result) => result.Success ? Results.Ok(result.Value) : Results.Problem(
        statusCode: result.Error switch {
            "invalid_request" => 400, "unauthenticated" => 401, "forbidden" => 403,
            "sale_not_found" or "location_not_found" => 404, "storage_unavailable" or "unknown_outcome" => 503, _ => 409 },
        title: result.Error, extensions: new Dictionary<string, object?> { ["code"] = result.Error });
}
