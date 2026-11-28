using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Http.Features;
using Savia.Application;
using Savia.Contracts;
using Savia.Domain;
using Savia.Infrastructure;

namespace Savia.Api;

/// <summary>
/// Routes the storefront calls without signing in (ORDER-PATH-SPEC 4.2). They exist only on the hub. Every route is
/// rate-limited per client address, takes at most 16 KB, and answers <see cref="PublicProblem"/> with public codes.
/// </summary>
public static class PublicEndpoints
{
    public const string Prefix = "/api/v1/public";
    public const int MaxBodyBytes = 16 * 1024;

    private static readonly JsonSerializerOptions Strict = new(JsonSerializerDefaults.Web)
    {
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow,
    };

    public static void Map(RouteGroupBuilder open, NodeContext node)
    {
        if (node.Kind != NodeKind.Cloud) return;
        var pub = open.MapGroup("/public").RequireRateLimiting(WebStoreHosting.RatePolicy).AddEndpointFilter<PublicFilter>()
            .WithTags("public");
        pub.MapGet("/catalog", async (HttpContext http, WebStoreService web, CancellationToken ct) =>
        {
            http.Response.Headers.CacheControl = "public, max-age=30";
            return await web.CatalogAsync(ct);
        }).Produces<PublicCatalogResponse>();
        pub.MapPost("/orders", CreateOrderAsync).Produces<PublicOrderCreated>(StatusCodes.Status201Created);
        pub.MapGet("/orders/{orderId:guid}", GetOrderAsync).Produces<PublicOrderStatus>();
        pub.MapMethods("/payments/{provider}/return", ["GET", "POST"], ReturnAsync);
        pub.MapPost("/payments/{provider}/webhook", WebhookAsync);
    }

    /// <summary>
    /// The key fixes the order id and token, so a retry finds its order before Turnstile is asked again: the bot token is
    /// single-use, and the request hash leaves it out.
    /// </summary>
    private static async Task<IResult> CreateOrderAsync(HttpContext http, WebStoreService web, PaymentProviders providers,
        IBotCheck bot, CancellationToken ct)
    {
        if (!Guid.TryParse(http.Request.Headers["Idempotency-Key"], out var key))
            throw Errors.Invalid("web.validation", "Idempotency-Key debe ser un UUID.");
        var request = WebStoreService.Normalize(await ReadStrictAsync<PublicOrderRequest>(http, ct));
        var provider = providers.ForBuyer(request.Provider)
            ?? throw new SaviaException(new SaviaError("web.provider_unavailable", ErrorKind.Conflict, "Esa forma de pago no está disponible."));
        var orderId = WebOrderKeys.OrderId(key);
        var token = WebOrderKeys.AccessToken(key);
        var requestHash = WebOrderKeys.RequestHash(request);

        if (await web.FindOrderAsync(orderId, token, ct) is { } existing)
        {
            if (!existing.RequestHash.AsSpan().SequenceEqual(requestHash))
                throw new SaviaException(new SaviaError("web.idempotency_conflict", ErrorKind.Conflict, "La clave ya se usó con otro pedido."));
            var again = new WebOrderPlaced(existing.OrderId, existing.Code, existing.Status, existing.TotalMinor, existing.ShippingMinor,
                existing.Currency, existing.ExpiresAt, true);
            return Results.Ok(await CreatedAsync(http, providers.ByCode(existing.Provider) ?? provider, again, token, request.Locale!, ct));
        }

        if (!await bot.PassesAsync(request.TurnstileToken, http.Connection.RemoteIpAddress, ct))
            return Problem(http, StatusCodes.Status403Forbidden, "turnstile_failed", "No pudimos verificar que es una persona. Reintente.");

        WebOrderPlaced placed;
        try
        {
            placed = await web.CreateOrderAsync(new NewWebOrder(orderId, requestHash, WebOrderKeys.Hash(token), ClientHash(http), request,
                provider.Code), ct);
        }
        catch (SaviaException ex) when (ex.Error.Code == "stock.insufficient")
        {
            return Problem(http, StatusCodes.Status409Conflict, "out_of_stock", "Ya no hay suficiente existencia.",
                await web.ShortSkuAsync(request.Lines, ct));
        }
        var body = await CreatedAsync(http, provider, placed, token, request.Locale!, ct);
        return placed.Replayed ? Results.Ok(body) : Results.Created($"{Prefix}/orders/{placed.OrderId}", body);
    }

    private static async Task<PublicOrderCreated> CreatedAsync(HttpContext http, IPaymentProvider provider, WebOrderPlaced order,
        string token, string locale, CancellationToken ct)
    {
        PaymentStartResponse? payment = null;
        if (order.Status == "reserved")
        {
            var returnUrl = new Uri($"{http.Request.Scheme}://{http.Request.Host}{Prefix}/payments/{provider.Code}/return");
            var start = await provider.StartAsync(
                new PaymentStartRequest(order.OrderId, order.Code, order.TotalMinor, order.Currency, locale, returnUrl), ct);
            payment = new PaymentStartResponse(provider.Code, provider.Label, start.Kind, start.Url, start.Method, start.Instructions);
        }
        return new PublicOrderCreated(order.OrderId, order.Code, token, order.Status, order.TotalMinor, order.ShippingMinor,
            order.Currency, order.ExpiresAt, payment);
    }

    private static async Task<PublicOrderStatus> GetOrderAsync(Guid orderId, HttpContext http, WebStoreService web, CancellationToken ct)
    {
        http.Response.Headers.CacheControl = "no-store";
        var order = await web.FindOrderAsync(orderId, http.Request.Headers["X-Order-Token"], ct)
            ?? throw Errors.NotFound("web.not_found", "Pedido no encontrado.");
        return new PublicOrderStatus(order.Code, order.Status, order.TotalMinor, order.Currency, order.ExpiresAt, order.Lines);
    }

    /// <summary>
    /// The buyer's browser comes back from the hosted page. Only the provider's server-side confirmation can record a
    /// payment; whatever happens, the buyer goes on to the order page, which shows the status the hub holds.
    /// </summary>
    private static async Task<IResult> ReturnAsync(string provider, HttpContext http, PaymentProviders providers, WebStoreService web,
        IConfiguration config, ILogger<PaymentProviders> log, CancellationToken ct)
    {
        var gateway = providers.ByCode(provider) ?? throw Errors.NotFound("web.not_found", "Proveedor desconocido.");
        var result = await gateway.ConfirmReturnAsync(http.Request, ct);
        try
        {
            if (PaymentProviders.Verified(gateway, result) is { } paid) await web.RecordVerifiedPaymentAsync(paid, ct);
        }
        catch (SaviaException ex)
        {
            log.LogWarning("Confirmed payment for order {Order} not recorded: {Code}", result.OrderId, ex.Error.Code);
        }
        var page = config["Savia:Public:OrderPageUrl"] is { Length: > 0 } url ? url : "/";
        http.Response.Headers.Location = result.OrderId is Guid order ? $"{page}?order={order}" : page;
        return Results.StatusCode(StatusCodes.Status303SeeOther);
    }

    /// <summary>The provider checks the signature before it reads the body; a repeat delivery records nothing new.</summary>
    private static async Task<IResult> WebhookAsync(string provider, HttpContext http, PaymentProviders providers, WebStoreService web,
        CancellationToken ct)
    {
        var gateway = providers.ByCode(provider) ?? throw Errors.NotFound("web.not_found", "Proveedor desconocido.");
        var result = await gateway.HandleWebhookAsync(http.Request, ct) ?? throw Errors.NotFound("web.not_found", "Sin webhook.");
        if (PaymentProviders.Verified(gateway, result) is { } paid) await web.RecordVerifiedPaymentAsync(paid, ct);
        return Results.Ok();
    }

    private static async Task<T> ReadStrictAsync<T>(HttpContext http, CancellationToken ct) where T : class
    {
        if (!http.Request.HasJsonContentType()) throw Errors.Invalid("web.validation", "Content-Type debe ser application/json.");
        using var buffer = new MemoryStream();
        var chunk = new byte[4096];
        int read;
        while ((read = await http.Request.Body.ReadAsync(chunk, ct)) > 0)
        {
            if (buffer.Length + read > MaxBodyBytes) throw new BodyTooLargeException();
            buffer.Write(chunk, 0, read);
        }
        try
        {
            return JsonSerializer.Deserialize<T>(buffer.GetBuffer().AsSpan(0, (int)buffer.Length), Strict)
                ?? throw Errors.Invalid("web.validation", "Cuerpo vacío.");
        }
        catch (JsonException)
        {
            throw Errors.Invalid("web.validation", "JSON inválido o con campos desconocidos.");
        }
    }

    // The address itself is never stored; its hash limits unpaid orders per client.
    private static byte[]? ClientHash(HttpContext http) =>
        http.Connection.RemoteIpAddress is { } address ? SHA256.HashData(Encoding.UTF8.GetBytes("client:" + address)) : null;

    internal static IResult Problem(HttpContext http, int status, string code, string message, string? sku = null) =>
        Results.Json(new PublicProblem(code, message, http.TraceIdentifier, sku), statusCode: status);

    internal sealed class BodyTooLargeException : Exception;
}

/// <summary>Caps the body at 16 KB and turns errors into public codes, so internal codes never reach the storefront.</summary>
public sealed class PublicFilter(ILogger<PublicFilter> log) : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var http = context.HttpContext;
        if (http.Features.Get<IHttpMaxRequestBodySizeFeature>() is { IsReadOnly: false } limit) limit.MaxRequestBodySize = PublicEndpoints.MaxBodyBytes;
        if (http.Request.ContentLength > PublicEndpoints.MaxBodyBytes) return TooLarge(http);
        try
        {
            return await next(context);
        }
        catch (PublicEndpoints.BodyTooLargeException)
        {
            return TooLarge(http);
        }
        catch (BadHttpRequestException ex) when (ex.StatusCode == StatusCodes.Status413PayloadTooLarge)
        {
            return TooLarge(http);
        }
        catch (SaviaException ex)
        {
            var (status, code) = Translate(ex.Error);
            if (status == StatusCodes.Status500InternalServerError) log.Failure(ex, $"Public route failed on {http.Request.Path}");
            return PublicEndpoints.Problem(http, status, code, status == StatusCodes.Status500InternalServerError ? "Error interno." : ex.Error.Message);
        }
    }

    private static IResult TooLarge(HttpContext http) =>
        PublicEndpoints.Problem(http, StatusCodes.Status413PayloadTooLarge, "payload_too_large", "El pedido supera 16 KB.");

    private static (int Status, string Code) Translate(SaviaError error) => error.Code switch
    {
        "web.idempotency_conflict" => (StatusCodes.Status409Conflict, "idempotency_conflict"),
        "stock.insufficient" => (StatusCodes.Status409Conflict, "out_of_stock"),
        "web.too_many_unpaid" => (StatusCodes.Status409Conflict, "too_many_unpaid"),
        "web.provider_unavailable" => (StatusCodes.Status409Conflict, "provider_unavailable"),
        "payment.signature" => (StatusCodes.Status401Unauthorized, "signature_invalid"),
        _ => error.Kind switch
        {
            ErrorKind.Validation => (StatusCodes.Status400BadRequest, "validation"),
            ErrorKind.NotFound => (StatusCodes.Status404NotFound, "not_found"),
            ErrorKind.Conflict => (StatusCodes.Status409Conflict, "conflict"),
            ErrorKind.Unavailable => (StatusCodes.Status503ServiceUnavailable, "unavailable"),
            ErrorKind.Unauthorized => (StatusCodes.Status401Unauthorized, "unauthorized"),
            ErrorKind.Forbidden => (StatusCodes.Status403Forbidden, "forbidden"),
            _ => (StatusCodes.Status500InternalServerError, "internal"),
        },
    };
}
