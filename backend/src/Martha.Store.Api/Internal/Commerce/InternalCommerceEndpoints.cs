namespace Martha.Store.Api.Internal;

public static class InternalCommerceEndpoints
{
    public static IServiceCollection AddInternalCommerce(this IServiceCollection services) => services
        .AddScoped<IInternalStockLedger, InternalStockLedger>().AddScoped<InternalCommerceService>();

    public static IEndpointRouteBuilder MapInternalCommerce(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/internal/api/commerce").RequireAuthorization("internal.read");
        group.MapGet("/inventory", async (Guid? locationId, int? skip, int? take, InternalCommerceService service, HttpContext http, CancellationToken ct) =>
            InternalCommerceService.ValidPage(skip ?? 0, take ?? 100, 1000) ? Results.Ok(await service.Stock(locationId, skip ?? 0, take ?? 100, ct, InternalActor.Id(http.User))) : Error("invalid_request"));
        group.MapGet("/movements", async (Guid? itemId, Guid? locationId, int? skip, int? take, InternalCommerceService service, HttpContext http, CancellationToken ct) =>
            InternalCommerceService.ValidPage(skip ?? 0, take ?? 100, 200) ? Results.Ok(await service.Movements(itemId, locationId, skip ?? 0, take ?? 100, ct, InternalActor.Id(http.User))) : Error("invalid_request"));
        group.MapGet("/sales", async (int? skip, int? take, InternalCommerceService service, HttpContext http, CancellationToken ct) =>
            InternalCommerceService.ValidPage(skip ?? 0, take ?? 100, 100) ? Results.Ok(await service.Sales(skip ?? 0, take ?? 100, ct, InternalActor.Id(http.User))) : Error("invalid_request"));
        group.MapGet("/sales/{id:guid}", async (Guid id, InternalCommerceService service, HttpContext http, CancellationToken ct) =>
            await service.Sale(id, ct, InternalActor.Id(http.User)) is { } sale ? Results.Ok(sale) : Error("sale_not_found"));
        group.MapGet("/sales/{id:guid}/reversals", async (Guid id, InternalCommerceService service, HttpContext http, CancellationToken ct) =>
            await service.Reversals(id, ct, InternalActor.Id(http.User)) is { } records ? Results.Ok(records) : Error("sale_not_found"));
        group.MapPost("/adjustments", async (InternalStockAdjustmentRequest request, HttpContext context, InternalCommerceService service, CancellationToken ct) =>
            Result(await service.Adjust(request, InternalActor.Id(context.User), Key(context), ct)))
            .RequireAuthorization("internal.inventory").RequireInternalCsrf();
        group.MapPost("/sales", async (InternalSaleRequest request, HttpContext context, InternalCommerceService service, CancellationToken ct) =>
            Result(await service.RecordSale(request, InternalActor.Id(context.User), Key(context), ct)))
            .RequireAuthorization("internal.sell").RequireInternalCsrf();
        group.MapPost("/sales/{id:guid}/cancel", async (Guid id, InternalSaleCancelRequest request, HttpContext context, InternalCommerceService service, CancellationToken ct) =>
            Result(await service.CancelSale(id, request, InternalActor.Id(context.User), Key(context), ct)))
            .RequireAuthorization("internal.manage").RequireInternalCsrf();
        group.MapPost("/sales/{id:guid}/returns", async (Guid id, InternalSaleReturnRequest request, HttpContext context, InternalCommerceService service, CancellationToken ct) =>
            Result(await service.ReturnSale(id, request, InternalActor.Id(context.User), Key(context), ct)))
            .RequireAuthorization("internal.manage").RequireInternalCsrf();
        return endpoints;
    }

    private static string Key(HttpContext context) => context.Request.Headers["Idempotency-Key"] is { Count: 1 } values ? values[0] ?? "" : "";
    private static IResult Result<T>(InternalResult<T> result) => result.Success ? Results.Ok(result.Value) : Error(result.Error!);
    private static IResult Error(string code) => Results.Problem(statusCode: code switch
    {
        "invalid_request" or "amount_out_of_range" => StatusCodes.Status400BadRequest,
        "unauthenticated" => StatusCodes.Status401Unauthorized,
        "forbidden" => StatusCodes.Status403Forbidden,
        "sale_not_found" or "item_not_found" or "location_not_found" or "customer_not_found" => StatusCodes.Status404NotFound,
        "storage_unavailable" or "unknown_outcome" => StatusCodes.Status503ServiceUnavailable,
        _ => StatusCodes.Status409Conflict
    }, title: code, extensions: new Dictionary<string, object?> { ["code"] = code });
}
