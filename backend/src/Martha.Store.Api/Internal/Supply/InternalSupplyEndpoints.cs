using System.Data.Common;

namespace Martha.Store.Api.Internal;

public static class InternalSupplyEndpoints
{
    public static IServiceCollection AddInternalSupply(this IServiceCollection services) =>
        services.AddScoped<InternalSupplyService>();

    public static IEndpointRouteBuilder MapInternalSupply(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/internal/api/supply").RequireAuthorization("internal.read");
        group.AddEndpointFilter(async (context, next) =>
        {
            context.HttpContext.Response.Headers.CacheControl = "no-store";
            context.HttpContext.Response.Headers.Pragma = "no-cache";
            return await next(context);
        });
        group.MapGet("/purchase-orders", async (int? skip, int? take, InternalSupplyService service, CancellationToken ct) =>
            !ValidPage(skip, take) ? Results.BadRequest(new { error = "invalid_pagination" }) :
            await Read(async () => Results.Ok(await service.List(skip ?? 0, take ?? 50, ct))));
        group.MapGet("/purchase-orders/{id:guid}", async (Guid id, InternalSupplyService service, CancellationToken ct) =>
            await Read(async () => await service.Get(id, ct) is { } order ? Results.Ok(order) : Results.NotFound(new { error = "purchase_order_not_found" })));
        group.MapGet("/purchase-orders/{id:guid}/receipts", async (Guid id, int? skip, int? take, InternalSupplyService service, CancellationToken ct) =>
            !ValidPage(skip, take) ? Results.BadRequest(new { error = "invalid_pagination" }) :
            await Read(async () => await service.Receipts(id, skip ?? 0, take ?? 50, ct) is { } receipts ? Results.Ok(receipts) : Results.NotFound(new { error = "purchase_order_not_found" })));
        group.MapPost("/purchase-orders", async (InternalPurchaseOrderRequest request, HttpContext http, InternalSupplyService service, CancellationToken ct) =>
            Respond(await service.Create(InternalActor.Id(http.User), Key(http), request, ct)))
            .RequireAuthorization("internal.manage").RequireInternalCsrf();
        group.MapPost("/purchase-orders/{id:guid}/receipts", async (Guid id, InternalPurchaseReceiptRequest request, HttpContext http, InternalSupplyService service, CancellationToken ct) =>
            Respond(await service.Receive(InternalActor.Id(http.User), Key(http), id, request, ct)))
            .RequireAuthorization("internal.inventory").RequireInternalCsrf();
        group.MapPost("/purchase-orders/{id:guid}/cancel", async (Guid id, InternalPurchaseCancelRequest request, HttpContext http, InternalSupplyService service, CancellationToken ct) =>
            Respond(await service.Cancel(InternalActor.Id(http.User), Key(http), id, request, ct)))
            .RequireAuthorization("internal.manage").RequireInternalCsrf();
        return endpoints;
    }

    private static bool ValidPage(int? skip, int? take) => (skip ?? 0) >= 0 && (take ?? 50) is >= 1 and <= 100;

    private static string Key(HttpContext http) => http.Request.Headers["Idempotency-Key"] is { Count: 1 } values
        ? values[0] ?? "" : "";

    private static IResult Respond<T>(InternalResult<T> result)
    {
        if (result.Success) return Results.Ok(result.Value);
        var error = result.Error!;
        var status = error switch
        {
            "storage_unavailable" or "unknown_outcome" or "outcome_unknown" => StatusCodes.Status503ServiceUnavailable,
            "unauthenticated" => StatusCodes.Status401Unauthorized,
            "forbidden" => StatusCodes.Status403Forbidden,
            "purchase_order_not_found" or "purchase_line_not_found" => StatusCodes.Status404NotFound,
            _ when error.StartsWith("invalid_", StringComparison.Ordinal) || error == "purchase_total_too_large" => StatusCodes.Status400BadRequest,
            _ => StatusCodes.Status409Conflict
        };
        return Results.Json(new { error }, statusCode: status);
    }

    private static async Task<IResult> Read(Func<Task<IResult>> action)
    {
        try { return await action(); }
        catch (DbException) { return Results.Json(new { error = "storage_unavailable" }, statusCode: StatusCodes.Status503ServiceUnavailable); }
        catch (TimeoutException) { return Results.Json(new { error = "storage_unavailable" }, statusCode: StatusCodes.Status503ServiceUnavailable); }
    }
}
