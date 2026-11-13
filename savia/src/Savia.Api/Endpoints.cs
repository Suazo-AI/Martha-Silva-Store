using Savia.Application;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Api;

/// <summary>Reads the bearer token and loads the signed-in staff member, or answers 401.</summary>
public sealed class ActorFilter(AuthService auth) : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var http = context.HttpContext;
        http.Items[typeof(Actor)] = await auth.AuthenticateAsync(Http.BearerToken(http), http.RequestAborted);
        return await next(context);
    }
}

public static class Http
{
    public static Actor Actor(this HttpContext http) => (Actor)http.Items[typeof(Actor)]!;

    public static string BearerToken(HttpContext http)
    {
        var header = http.Request.Headers.Authorization.ToString();
        return header.StartsWith("Bearer ", StringComparison.Ordinal) ? header[7..].Trim() : throw new SaviaException(Errors.Unauthorized);
    }

    /// <summary>One place that turns a <see cref="SaviaException"/> into an HTTP status and a <see cref="ProblemResponse"/>.</summary>
    public static void UseSaviaErrors(this WebApplication app) => app.Use(async (http, next) =>
    {
        try
        {
            await next(http);
        }
        catch (SaviaException ex) when (!http.Response.HasStarted)
        {
            http.Response.StatusCode = ex.Error.Kind switch
            {
                ErrorKind.Validation => StatusCodes.Status422UnprocessableEntity,
                ErrorKind.Unauthorized => StatusCodes.Status401Unauthorized,
                ErrorKind.Forbidden => StatusCodes.Status403Forbidden,
                ErrorKind.NotFound => StatusCodes.Status404NotFound,
                ErrorKind.Conflict => StatusCodes.Status409Conflict,
                ErrorKind.Unavailable => StatusCodes.Status503ServiceUnavailable,
                _ => StatusCodes.Status500InternalServerError,
            };
            if (ex.Error.Kind == ErrorKind.Internal)
                app.Logger.LogError(ex, "Unhandled database error on {Path}", http.Request.Path);
            await http.Response.WriteAsJsonAsync(new ProblemResponse(ex.Error.Code, ex.Error.Message, http.TraceIdentifier));
        }
    });
}

public static class SaviaEndpoints
{
    public static void MapSaviaEndpoints(this WebApplication app)
    {
        var node = app.Services.GetRequiredService<NodeContext>();
        var open = app.MapGroup("/api/v1");
        var api = app.MapGroup("/api/v1").AddEndpointFilter<ActorFilter>();

        // ---- auth (both modes)
        open.MapPost("/auth/login", async (LoginRequest request, AuthService auth, CancellationToken ct) =>
            Results.Ok(await auth.LoginAsync(request, ct))).Produces<LoginResponse>().WithTags("auth");
        api.MapPost("/auth/logout", async (HttpContext http, AuthService auth, CancellationToken ct) =>
        {
            await auth.LogoutAsync(Http.BearerToken(http), ct);
            return Results.NoContent();
        }).WithTags("auth");
        api.MapGet("/me", async (HttpContext http, SiteService site, CancellationToken ct) =>
            await site.GetMeAsync(http.Actor(), ct)).Produces<MeResponse>().WithTags("auth");

        // ---- catalog: cloud writer, with an explicit single-branch pilot exception
        api.MapGet("/catalog/lookup", async (string code, Guid? supplierId, HttpContext http, CatalogService catalog, CancellationToken ct) =>
            await catalog.LookupAsync(http.Actor(), code, supplierId, ct)).Produces<ItemLookup[]>().WithTags("catalog");
        api.MapGet("/catalog/items", async (HttpContext http, CatalogService catalog, CancellationToken ct) =>
            await catalog.ListAsync(http.Actor(), ct)).Produces<CatalogProduct[]>().WithTags("catalog");
        api.MapGet("/catalog/search", async (string q, int? limit, HttpContext http, CatalogService catalog, CancellationToken ct) =>
            await catalog.SearchAsync(http.Actor(), q, limit, ct)).Produces<ProductSearchRow[]>().WithTags("catalog");
        if (node.Kind == NodeKind.Cloud || node.LocalCatalog)
        {
            api.MapPost("/catalog/products", async (RegisterProductRequest request, HttpContext http, CatalogService catalog, CancellationToken ct) =>
            {
                await catalog.RegisterProductAsync(http.Actor(), request, ct);
                return Results.NoContent();
            }).WithTags("catalog");
            api.MapPost("/catalog/items", async (RegisterItemRequest request, HttpContext http, CatalogService catalog, CancellationToken ct) =>
            {
                await catalog.RegisterItemAsync(http.Actor(), request, ct);
                return Results.NoContent();
            }).WithTags("catalog");
        }

        else
        {
            // GET shares this path; preserve the disabled write contract (404 rather than 405).
            open.MapPost("/catalog/items", () => Results.NotFound()).ExcludeFromDescription();
        }

        api.MapGet("/stock", async (Guid? itemId, HttpContext http, InventoryService inventory, CancellationToken ct) =>
            await inventory.GetStockAsync(http.Actor(), itemId, ct)).Produces<StockRow[]>().WithTags("inventory");

        if (node.Kind != NodeKind.Branch) return;

        api.MapGet("/approvals", async (HttpContext http, PilotSalesService pilot, CancellationToken ct) =>
            await pilot.ApprovalsAsync(http.Actor(), ct)).WithTags("pilot");
        OwnerPilotEndpoints.Map(api);

        // ---- everything below runs only on a branch node, against the local database of that branch
        api.MapPost("/receiving/sessions", async (OpenScanSessionRequest request, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
        {
            await receiving.OpenSessionAsync(http.Actor(), request, ct);
            return Results.NoContent();
        }).WithTags("receiving");
        api.MapPost("/receiving/sessions/{sessionId:guid}/scans", async (Guid sessionId, RecordScanRequest request, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
            await receiving.RecordScanAsync(http.Actor(), sessionId, request, ct)).WithTags("receiving");
        api.MapGet("/receiving/sessions", async (bool? open, int? limit, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
            await receiving.ListSessionsAsync(http.Actor(), open ?? true, limit, ct)).Produces<ScanSessionSummary[]>().WithTags("receiving");
        api.MapGet("/receiving/sessions/{sessionId:guid}/lines", async (Guid sessionId, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
            await receiving.GetLinesAsync(http.Actor(), sessionId, ct)).Produces<ScanSessionLine[]>().WithTags("receiving");
        api.MapPost("/receiving/sessions/{sessionId:guid}/scans/{scanId:guid}/resolve", async (Guid sessionId, Guid scanId, ResolveScanRequest request, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
        {
            await receiving.ResolveScanAsync(http.Actor(), sessionId, scanId, request, ct);
            return Results.NoContent();
        }).WithTags("receiving");
        api.MapPost("/receiving/sessions/{sessionId:guid}/scans/{scanId:guid}/reject", async (Guid sessionId, Guid scanId, RejectScanRequest request, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
        {
            await receiving.RejectScanAsync(http.Actor(), sessionId, scanId, request, ct);
            return Results.NoContent();
        }).WithTags("receiving");
        api.MapGet("/suppliers", async (HttpContext http, ReceivingService receiving, CancellationToken ct) =>
            await receiving.ListSuppliersAsync(http.Actor(), ct)).Produces<SupplierRow[]>().WithTags("receiving");
        api.MapGet("/receiving/sessions/{sessionId:guid}", async (Guid sessionId, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
            await receiving.GetProgressAsync(http.Actor(), sessionId, ct)).WithTags("receiving");
        api.MapPost("/receiving/sessions/{sessionId:guid}/approve", async (Guid sessionId, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
        {
            await receiving.ApproveAsync(http.Actor(), sessionId, ct);
            return Results.NoContent();
        }).WithTags("receiving");
        api.MapPost("/receiving/sessions/{sessionId:guid}/post", async (Guid sessionId, string? currency, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
            await receiving.PostAsync(http.Actor(), sessionId, currency ?? "NIO", ct)).WithTags("receiving");

        api.MapGet("/labels/jobs", async (string? status, HttpContext http, InventoryService inventory, CancellationToken ct) =>
            await inventory.GetLabelJobsAsync(http.Actor(), status, ct)).Produces<LabelJob[]>().WithTags("labels");
        api.MapPost("/labels/jobs/{jobId:guid}/attempts", async (Guid jobId, AckPrintRequest request, HttpContext http, InventoryService inventory, CancellationToken ct) =>
        {
            await inventory.AcknowledgePrintAsync(http.Actor(), jobId, request, ct);
            return Results.NoContent();
        }).WithTags("labels");

        api.MapGet("/cash/registers", async (HttpContext http, SalesService sales, CancellationToken ct) =>
            await sales.ListRegistersAsync(http.Actor(), ct)).Produces<RegisterRow[]>().WithTags("cash");
        api.MapGet("/cash/tills/current", async (HttpContext http, SalesService sales, CancellationToken ct) =>
            await sales.GetCurrentTillAsync(http.Actor(), ct)).Produces<TillSummary>().WithTags("cash");
        api.MapGet("/cash/tills/{tillId:guid}/summary", async (Guid tillId, HttpContext http, SalesService sales, CancellationToken ct) =>
            await sales.GetTillSummaryAsync(http.Actor(), tillId, ct)).Produces<TillSummary>().WithTags("cash");
        api.MapPost("/cash/tills", async (OpenTillRequest request, HttpContext http, SalesService sales, CancellationToken ct) =>
        {
            await sales.OpenTillAsync(http.Actor(), request, ct);
            return Results.NoContent();
        }).WithTags("cash");
        api.MapPost("/cash/tills/{tillId:guid}/counts", async (Guid tillId, RecordCashCountRequest request, HttpContext http, SalesService sales, CancellationToken ct) =>
        {
            await sales.RecordCashCountAsync(http.Actor(), tillId, request, ct);
            return Results.NoContent();
        }).WithTags("cash");
        api.MapPost("/cash/tills/{tillId:guid}/close", async (Guid tillId, CloseTillRequest request, HttpContext http, SalesService sales, CancellationToken ct) =>
            await sales.CloseTillAsync(http.Actor(), tillId, request, ct)).WithTags("cash");

        api.MapPost("/sales", async (PostSaleRequest request, HttpContext http, SalesService sales, AuthService auth, CancellationToken ct) =>
        {
            var token = http.Request.Headers["X-Savia-Approval"].ToString();
            var approval = string.IsNullOrEmpty(token) ? null : await auth.AuthenticateAsync(token, ct);
            return await sales.PostSaleAsync(http.Actor(), request, ct, approval);
        }).WithTags("sales");
        api.MapGet("/sales/{saleId:guid}", async (Guid saleId, HttpContext http, PilotSalesService sales, CancellationToken ct) =>
            await sales.DetailAsync(http.Actor(), saleId, ct)).Produces<SaleDetailResponse>().WithTags("sales");
        api.MapGet("/sales", async (DateOnly? from, DateOnly? to, string? q, int? page, int? pageSize, HttpContext http, PilotSalesService sales, CancellationToken ct) =>
            await sales.SearchAsync(http.Actor(), from, to, q, page, pageSize, ct)).Produces<SalesPage>().WithTags("sales");
        api.MapPost("/sales/{saleId:guid}/returns/credit", async (Guid saleId, PostCreditReturnRequest request, HttpContext http, PilotSalesService sales, CancellationToken ct) =>
            await sales.ReturnAsync(http.Actor(), saleId, request, ct)).Produces<SaleReversal>().WithTags("sales");
        api.MapGet("/customers", async (string q, HttpContext http, PilotSalesService sales, CancellationToken ct) =>
            await sales.CustomersAsync(http.Actor(), q, ct)).Produces<CustomerRow[]>().WithTags("sales");
        api.MapGet("/credits/search", async (string q, HttpContext http, PilotSalesService sales, CancellationToken ct) =>
            await sales.CreditsAsync(http.Actor(), q, ct)).Produces<CustomerCreditRow[]>().WithTags("sales");
        api.MapGet("/reports/day", async (DateOnly date, HttpContext http, PilotSalesService sales, CancellationToken ct) =>
            await sales.DayAsync(http.Actor(), date, ct)).Produces<DayReport>().WithTags("sales");
        api.MapGet("/cash/denominations", async (HttpContext http, PilotSalesService sales, CancellationToken ct) =>
            await sales.DenominationsAsync(http.Actor(), ct)).WithTags("cash");
        api.MapGet("/reports/summary", async (string period, DateOnly date, HttpContext http, PilotSalesService sales, CancellationToken ct) =>
            await sales.SummaryAsync(http.Actor(), period, date, ct)).WithTags("sales");
        api.MapGet("/reports/summary.csv", async (string period, DateOnly date, HttpContext http, PilotSalesService sales, CancellationToken ct) =>
            Results.File(PilotSalesService.SummaryCsv(await sales.SummaryAsync(http.Actor(), period, date, ct)), "text/csv; charset=utf-8", $"reporte-{period}-{date:yyyy-MM-dd}.csv")).WithTags("sales");
        api.MapGet("/stock/exceptions", async (HttpContext http, PilotSalesService sales, CancellationToken ct) =>
            await sales.ExceptionsAsync(http.Actor(), ct)).WithTags("sales");
        api.MapPost("/stock/exceptions/{exceptionId:guid}/review", async (Guid exceptionId, ResolveExceptionRequest request, HttpContext http, PilotSalesService sales, CancellationToken ct) =>
        {
            await sales.ReviewExceptionAsync(http.Actor(), exceptionId, request, ct);
            return Results.NoContent();
        }).WithTags("sales");
    }
}
