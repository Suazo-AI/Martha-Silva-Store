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
    /// <summary>
    /// Maps every module, in a fixed order. A cloud node serves auth, site, catalog, stock and tags;
    /// the rest runs only on a branch node, against the local database of that branch.
    /// </summary>
    public static void MapSaviaEndpoints(this WebApplication app)
    {
        var node = app.Services.GetRequiredService<NodeContext>();
        var open = app.MapGroup("/api/v1");
        var api = app.MapGroup("/api/v1").AddEndpointFilter<ActorFilter>();

        AuthEndpoints.Map(open, api);
        SiteEndpoints.Map(api);
        CatalogEndpoints.Map(open, api, node);
        InventoryEndpoints.Map(api, node);
        TagsEndpoints.Map(api, app);
        if (node.Kind != NodeKind.Branch) return;

        ReceivingEndpoints.Map(api);
        CashEndpoints.Map(api);
        ExchangeRateEndpoints.Map(api);
        ExchangeRateEndpoints.Map(app.MapGroup("/api").AddEndpointFilter<ActorFilter>());
        SalesEndpoints.Map(api);
        ReturnsEndpoints.Map(api);
        CustomersEndpoints.Map(api);
        ReportsEndpoints.Map(api);
        CommissionsEndpoints.Map(api);
    }
}
