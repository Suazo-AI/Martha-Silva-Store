using System.Data.Common;
using Martha.Store.Api;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);
var syntheticEnabled = builder.Environment.IsDevelopment()
    && builder.Configuration.GetValue<bool>("Synthetic:Enabled");
builder.Services.AddProblemDetails(options => options.CustomizeProblemDetails = context =>
{
    context.ProblemDetails.Extensions["traceId"] = context.HttpContext.TraceIdentifier;
    context.ProblemDetails.Extensions.TryAdd("code", "invalid_request");
});
builder.Services.AddDbContext<StoreDbContext>(options =>
{
    var connection = builder.Configuration.GetConnectionString("Store");
    if (string.IsNullOrWhiteSpace(connection)) throw new StorageUnavailableException();
    StoreDatabaseGuard.Validate(connection);
    options.UseSqlServer(connection, sql => sql.CommandTimeout(30));
});
builder.Services.AddScoped<SyntheticOrders>();
var app = builder.Build();
// Do not expose developer exception pages, database details, or input bodies in responses.
app.UseExceptionHandler(errorApp => errorApp.Run(async context =>
{
    var error = context.Features.Get<IExceptionHandlerFeature>()?.Error;
    var storage = error is DbException or DbUpdateException or StorageUnavailableException;
    var badRequest = error is BadHttpRequestException;
    await ApiError.Result(context, storage ? 503 : badRequest ? 400 : 500,
        storage ? "storage_unavailable" : badRequest ? "invalid_request" : "internal_error").ExecuteAsync(context);
}));
app.UseStatusCodePages(async context =>
{
    var response = context.HttpContext.Response;
    await ApiError.Result(context.HttpContext, response.StatusCode,
        response.StatusCode == 404 ? "not_found" : "invalid_request").ExecuteAsync(context.HttpContext);
});

if (args.Contains("--migrate") || args.Contains("--seed-synthetic"))
{
    if (!syntheticEnabled) throw new InvalidOperationException("Maintenance requires Development and Synthetic:Enabled=true. Production migrations require a separately reviewed release procedure.");
    await using var scope = app.Services.CreateAsyncScope();
    var db = scope.ServiceProvider.GetRequiredService<StoreDbContext>();
    if (args.Contains("--migrate")) await db.Database.MigrateAsync();
    if (args.Contains("--seed-synthetic")) await SyntheticSeed.Apply(db);
    return;
}

app.MapGet("/health/live", () => Results.Ok(new { status = "live" }));
app.MapGet("/health/ready", async (IServiceProvider services, HttpContext context, CancellationToken ct) =>
{
    try
    {
        var db = services.GetRequiredService<StoreDbContext>();
        if (!await db.Database.CanConnectAsync(ct) || (await db.Database.GetPendingMigrationsAsync(ct)).Any())
            return ApiError.Result(context, 503, "storage_unavailable");
        // A history table alone is insufficient: probe actual application schema.
        await db.Variants.AsNoTracking().Take(1).ToListAsync(ct);
        await db.Products.AsNoTracking().Take(1).ToListAsync(ct);
        await db.SyntheticOrders.AsNoTracking().Take(1).ToListAsync(ct);
        return Results.Ok(new { status = "ready" });
    }
    catch (Exception ex) when (ex is DbException or InvalidOperationException or StorageUnavailableException)
    { return ApiError.Result(context, 503, "storage_unavailable"); }
});
app.MapGet("/api/v1/catalog", async (IServiceProvider services, HttpContext context, CancellationToken ct) =>
{
    // Until business-approved catalog and production gates exist, this fixture catalog is closed in production.
    if (!syntheticEnabled) return ApiError.Result(context, 503, "catalog_not_enabled");
    var db = services.GetRequiredService<StoreDbContext>();
    var products = await db.Products.AsNoTracking().OrderBy(p => p.Id).ToListAsync(ct);
    var variants = await db.Variants.AsNoTracking().OrderBy(v => v.Id).ToListAsync(ct);
    return Results.Ok(new { synthetic = true, items = products.Select(p => new
    {
        productId = p.Id, name = p.Name, variants = variants.Where(v => v.ProductId == p.Id).Select(v => new
        { variantId = v.Id, sku = v.Sku, unitPriceMinor = v.UnitPriceMinor, currency = v.Currency, availableQuantity = v.AvailableQuantity })
    }) });
});
if (syntheticEnabled)
{
    app.MapPost("/api/v1/synthetic/orders", async (CreateSyntheticOrder request, HttpContext context, SyntheticOrders orders, CancellationToken ct) =>
    {
        var keys = context.Request.Headers["Idempotency-Key"];
        if (keys.Count != 1 || !SyntheticOrders.ValidKey(keys[0]) || !SyntheticOrders.ValidRequest(request))
            return ApiError.Result(context, 400, "invalid_request");
        var result = await orders.Reserve(request, keys[0]!, ct);
        if (result.Error is not null) return ApiError.Result(context, result.Error == "unknown_variant" ? 404 : result.Error == "invalid_request" ? 400 : 409, result.Error);
        return Results.Created($"/api/v1/synthetic/orders/{result.Order!.OrderId}", result.Order);
    });
    app.MapGet("/api/v1/synthetic/orders/{orderId:guid}", async (Guid orderId, StoreDbContext db, HttpContext context, CancellationToken ct) =>
    {
        var order = await db.SyntheticOrders.AsNoTracking().SingleOrDefaultAsync(o => o.Id == orderId && o.Actor == SyntheticOrders.Actor, ct);
        return order is null ? ApiError.Result(context, 404, "order_not_found") : Results.Ok(OrderResponse.From(order));
    });
}
app.Run();
public partial class Program;

public static class ApiError
{
    public static IResult Result(HttpContext context, int status, string code) => Results.Problem(statusCode: status,
        title: code, extensions: new Dictionary<string, object?> { ["code"] = code, ["traceId"] = context.TraceIdentifier });
}
