using System.Reflection;
namespace Martha.Store.Api.Internal;

public static class InternalUiHosting
{
    public static IEndpointRouteBuilder MapInternalUi(this IEndpointRouteBuilder routes)
    {
        routes.MapGet("/internal/login", () => Resource("login.html", "text/html; charset=utf-8")).AllowAnonymous();
        routes.MapGet("/internal/login.mjs", () => Resource("login.mjs", "text/javascript; charset=utf-8")).AllowAnonymous();
        routes.MapGet("/internal/styles.css", () => Resource("styles.css", "text/css; charset=utf-8")).AllowAnonymous();
        routes.MapGet("/internal/", () => Resource("index.html", "text/html; charset=utf-8")).RequireAuthorization("internal.read");
        routes.MapGet("/internal/app.mjs", () => Resource("app.mjs", "text/javascript; charset=utf-8")).RequireAuthorization("internal.read");
        routes.MapGet("/internal/client.mjs", () => Resource("client.mjs", "text/javascript; charset=utf-8")).RequireAuthorization("internal.read");
        return routes;
    }
    private static IResult Resource(string file, string contentType)
    {
        var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("SaviaStaff." + file);
        return stream is null ? Results.Problem(statusCode: 503, title: "internal_ui_unavailable")
            : Results.Stream(stream, contentType, enableRangeProcessing: false);
    }
}
