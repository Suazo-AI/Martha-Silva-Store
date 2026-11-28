using Savia.Application;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Api;

/// <summary>
/// Reads the bearer token and loads the signed-in staff member, or answers 401. A staff member who signed in with a
/// printed one-time password gets 403 auth.password_change_required everywhere except the routes marked with
/// <see cref="PasswordChangeOpen"/> (V064).
/// </summary>
public sealed class ActorFilter(AuthService auth) : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var http = context.HttpContext;
        var actor = await auth.AuthenticateAsync(Http.BearerToken(http), http.RequestAborted);
        if (actor.MustChangePassword && http.GetEndpoint()?.Metadata.GetMetadata<PasswordChangeOpen>() is null)
            throw new SaviaException(Errors.PasswordChangeRequired);
        http.Items[typeof(Actor)] = actor;
        return await next(context);
    }
}

/// <summary>Endpoint metadata: the route answers a staff member who must still change a one-time password.</summary>
public sealed class PasswordChangeOpen
{
    public static readonly PasswordChangeOpen Instance = new();

    private PasswordChangeOpen() { }
}

public static class Http
{
    public static Actor Actor(this HttpContext http) => (Actor)http.Items[typeof(Actor)]!;

    /// <summary>
    /// The body stays the plain array of earlier releases. The next page is in the standard Link header
    /// (RFC 8288): the same request with <c>after</c> set to the last row of this page.
    /// </summary>
    public static IReadOnlyList<T> Paged<T>(this HttpContext http, Page<T> page)
    {
        if (page.NextAfter is not null)
        {
            var query = QueryString.Create(http.Request.Query
                .Where(p => p.Key != "after")
                .Select(p => KeyValuePair.Create<string, string?>(p.Key, p.Value.ToString()))
                .Append(KeyValuePair.Create<string, string?>("after", page.NextAfter)));
            http.Response.Headers.Link = $"<{http.Request.PathBase}{http.Request.Path}{query}>; rel=\"next\"";
        }
        return page.Items;
    }

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
                app.Logger.Failure(ex, $"Unhandled database error on {http.Request.Path}");
            await http.Response.WriteAsJsonAsync(new ProblemResponse(ex.Error.Code, ex.Error.Message, http.TraceIdentifier));
        }
    });
}

public static class SaviaEndpoints
{
    /// <summary>
    /// Maps every module, in a fixed order. A cloud node serves auth, site, catalog, stock and tags;
    /// the rest runs only on a branch node, against the local database of that branch.
    /// </summary>
    public static void MapSaviaEndpoints(this WebApplication app)
    {
        var node = app.Services.GetRequiredService<NodeContext>();
        var open = app.MapGroup("/api/v1");
        var api = app.MapGroup("/api/v1").AddEndpointFilter<ActorFilter>().RequireRateLimiting(SaviaHosting.StaffPolicy);

        AuthEndpoints.Map(open, api);
        SiteEndpoints.Map(api);
        CatalogEndpoints.Map(open, api, node);
        InventoryEndpoints.Map(api, node);
        TagsEndpoints.Map(api, app);
        SyncEndpoints.Map(app, api, node);
        PublicEndpoints.Map(open, node);
        WebStoreEndpoints.Map(api, node);
        CreditTransferEndpoints.Map(api, node);
        if (node.Kind != NodeKind.Branch) return;

        ReceivingEndpoints.Map(api);
        CashEndpoints.Map(api);
        ExchangeRateEndpoints.Map(api);
        ExchangeRateEndpoints.Map(app.MapGroup("/api").AddEndpointFilter<ActorFilter>().RequireRateLimiting(SaviaHosting.StaffPolicy));
        SalesEndpoints.Map(api);
        ReturnsEndpoints.Map(api);
        CustomersEndpoints.Map(api);
        ReportsEndpoints.Map(api);
        CommissionsEndpoints.Map(api);
    }
}
