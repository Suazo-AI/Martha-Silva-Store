using Savia.Application;
using Savia.Contracts;

namespace Savia.Api;

public static class AuthEndpoints
{
    public static void Map(RouteGroupBuilder open, RouteGroupBuilder api)
    {
        open.MapPost("/auth/login", async (LoginRequest request, AuthService auth, CancellationToken ct) =>
            Results.Ok(await auth.LoginAsync(request, ct))).Produces<LoginResponse>().WithTags("auth");
        api.MapPost("/auth/logout", async (HttpContext http, AuthService auth, CancellationToken ct) =>
        {
            await auth.LogoutAsync(Http.BearerToken(http), ct);
            return Results.NoContent();
        }).WithTags("auth");
    }
}
