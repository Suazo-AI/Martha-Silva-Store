using Savia.Application;
using Savia.Contracts;

namespace Savia.Api;

public static class AuthEndpoints
{
    public static void Map(RouteGroupBuilder open, RouteGroupBuilder api)
    {
        open.MapPost("/auth/login", async (LoginRequest request, AuthService auth, CancellationToken ct) =>
            Results.Ok(await auth.LoginAsync(request, ct))).Produces<LoginResponse>().WithTags("auth")
            .RequireRateLimiting(SaviaHosting.LoginPolicy);
        api.MapPost("/auth/logout", async (HttpContext http, AuthService auth, CancellationToken ct) =>
        {
            await auth.LogoutAsync(Http.BearerToken(http), ct);
            return Results.NoContent();
        }).WithTags("auth").WithMetadata(PasswordChangeOpen.Instance);
        // DAY-ZERO.md gap 2: the signed-in staff member replaces their own password on this node; other sessions end.
        api.MapPost("/auth/password", async (ChangePasswordRequest request, HttpContext http, AuthService auth, CancellationToken ct) =>
        {
            await auth.ChangePasswordAsync(http.Actor(), Http.BearerToken(http), request, ct);
            return Results.NoContent();
        }).WithTags("auth").WithMetadata(PasswordChangeOpen.Instance).RequireRateLimiting(SaviaHosting.LoginPolicy);
    }
}
