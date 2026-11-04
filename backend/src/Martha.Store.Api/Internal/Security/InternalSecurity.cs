using System.Security.Claims;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace Martha.Store.Api.Internal;

public static class InternalSecurity
{
    public const string CsrfHeader = "X-CSRF-TOKEN";

    public static IServiceCollection AddInternalSecurity(this IServiceCollection services)
    {
        services.TryAddSingleton(TimeProvider.System);
        services.AddScoped<InternalSecurityService>();
        services.AddScoped<InternalOwnerBootstrap>();
        services.AddScoped<InternalCookieEvents>();
        services.AddScoped<IPasswordHasher<InternalStaff>, PasswordHasher<InternalStaff>>();
        services.Configure<PasswordHasherOptions>(options => options.IterationCount = 210_000);
        services.AddSingleton<InternalLoginLimiter>();
        services.AddAuthentication(options =>
        {
            options.DefaultAuthenticateScheme = InternalSecurityRules.Scheme;
            options.DefaultChallengeScheme = InternalSecurityRules.Scheme;
            options.DefaultSignInScheme = InternalSecurityRules.Scheme;
        }).AddCookie(InternalSecurityRules.Scheme, options =>
        {
            options.Cookie.Name = "__Host-Savia.Session";
            options.Cookie.Path = "/";
            options.Cookie.HttpOnly = true;
            options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
            options.Cookie.SameSite = SameSiteMode.Strict;
            options.Cookie.IsEssential = true;
            options.ExpireTimeSpan = InternalSecurityRules.SessionLifetime;
            options.SlidingExpiration = false;
            options.EventsType = typeof(InternalCookieEvents);
        });
        services.AddAuthorization(options =>
        {
            AddPolicy("internal.owner", "Owner");
            AddPolicy("internal.manage", "Owner", "Manager");
            AddPolicy("internal.sell", "Owner", "Manager", "Cashier");
            AddPolicy("internal.inventory", "Owner", "Manager", "Inventory");
            AddPolicy("internal.read", "Owner", "Manager", "Cashier", "Inventory");
            void AddPolicy(string name, params string[] roles) => options.AddPolicy(name, policy =>
                policy.AddAuthenticationSchemes(InternalSecurityRules.Scheme).RequireAuthenticatedUser().RequireRole(roles));
        });
        services.AddAntiforgery(options =>
        {
            options.HeaderName = CsrfHeader;
            options.Cookie.Name = "__Host-Savia.Csrf";
            options.Cookie.Path = "/";
            options.Cookie.HttpOnly = true;
            options.Cookie.SecurePolicy = CookieSecurePolicy.Always;
            options.Cookie.SameSite = SameSiteMode.Strict;
            options.Cookie.IsEssential = true;
        });
        return services;
    }

    // Works on either a RouteHandlerBuilder or RouteGroupBuilder. Explicit token validation covers JSON mutations and login.
    public static TBuilder RequireInternalCsrf<TBuilder>(this TBuilder builder) where TBuilder : IEndpointConventionBuilder =>
        builder.AddEndpointFilter(async (context, next) =>
        {
            var http = context.HttpContext;
            if (HttpMethods.IsGet(http.Request.Method) || HttpMethods.IsHead(http.Request.Method) || HttpMethods.IsOptions(http.Request.Method))
                return await next(context);
            if (!http.Request.IsHttps) return ApiError.Result(http, 400, "https_required");
            var header = http.Request.Headers[CsrfHeader];
            if (header.Count != 1 || string.IsNullOrWhiteSpace(header[0])
                || !await http.RequestServices.GetRequiredService<IAntiforgery>().IsRequestValidAsync(http))
                return ApiError.Result(http, 400, "csrf_invalid");
            return await next(context);
        });

    public static IEndpointRouteBuilder MapInternalSecurity(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/internal/api/security").RequireInternalCsrf();
        group.AddEndpointFilter(async (context, next) =>
        {
            context.HttpContext.Response.Headers.CacheControl = "no-store";
            context.HttpContext.Response.Headers.Pragma = "no-cache";
            if (!context.HttpContext.Request.IsHttps) return ApiError.Result(context.HttpContext, 400, "https_required");
            return await next(context);
        });
        group.MapGet("/csrf", (HttpContext context, IAntiforgery antiforgery) =>
        {
            var tokens = antiforgery.GetAndStoreTokens(context);
            return Results.Ok(new { token = tokens.RequestToken, headerName = CsrfHeader });
        }).AllowAnonymous();
        group.MapPost("/login", async (InternalLoginRequest request, HttpContext context,
            InternalLoginLimiter limiter, CancellationToken ct) =>
        {
            using var admission = limiter.TryEnter(context.Connection.RemoteIpAddress?.ToString() ?? "unknown");
            if (admission is null)
            {
                context.Response.Headers.RetryAfter = "60";
                return ApiError.Result(context, 429, "login_rate_limited");
            }
            // Resolve storage only after the CSRF filter has admitted this public credential endpoint.
            var security = context.RequestServices.GetRequiredService<InternalSecurityService>();
            var result = await security.Login(request, ct);
            if (!result.Success) return ApiError.Result(context, 401, "invalid_credentials");
            var login = result.Value!;
            await context.SignInAsync(InternalSecurityRules.Scheme, InternalSecurityRules.Principal(login.Staff, login.Session),
                new AuthenticationProperties { IssuedUtc = login.Session.CreatedAt, ExpiresUtc = login.Session.ExpiresAt,
                    IsPersistent = false, AllowRefresh = false });
            // A new authenticated CSRF token must be fetched after this identity transition.
            return Results.Ok(new { staff = InternalStaffView.From(login.Staff), expiresAt = login.Session.ExpiresAt });
        }).AllowAnonymous();
        group.MapPost("/logout", async (HttpContext context, InternalSecurityService security, CancellationToken ct) =>
        {
            await security.Logout(context.User, ct);
            await context.SignOutAsync(InternalSecurityRules.Scheme);
            return Results.NoContent();
        }).RequireAuthorization("internal.read");
        group.MapGet("/me", async (HttpContext context, InternalDbContext db, CancellationToken ct) =>
        {
            var id = InternalActor.Id(context.User);
            var staff = await db.InternalStaff.AsNoTracking().SingleAsync(x => x.Id == id, ct);
            return Results.Ok(InternalStaffView.From(staff));
        }).RequireAuthorization("internal.read");
        group.MapGet("/staff", async (InternalDbContext db, CancellationToken ct) =>
        {
            var staff = await db.InternalStaff.AsNoTracking().OrderBy(x => x.NormalizedLoginName).Take(201).ToListAsync(ct);
            return Results.Ok(new { items = staff.Take(200).Select(InternalStaffView.From), truncated = staff.Count > 200 });
        }).RequireAuthorization("internal.owner");
        group.MapPost("/staff", async (InternalStaffCreateRequest request, HttpContext context, InternalSecurityService security, CancellationToken ct) =>
            Result(context, await security.CreateStaff(context.User, request, ct))).RequireAuthorization("internal.owner");
        group.MapPut("/staff/{staffId:guid}", async (Guid staffId, InternalStaffUpdateRequest request,
            HttpContext context, InternalSecurityService security, CancellationToken ct) =>
            Result(context, await security.UpdateStaff(context.User, staffId, request, ct))).RequireAuthorization("internal.owner");
        group.MapPost("/staff/{staffId:guid}/password", async (Guid staffId, InternalStaffPasswordRequest request,
            HttpContext context, InternalSecurityService security, CancellationToken ct) =>
            Result(context, await security.ResetPassword(context.User, staffId, request, ct))).RequireAuthorization("internal.owner");
        return endpoints;
    }

    private static IResult Result(HttpContext context, InternalResult<InternalStaffView> result) => result.Success
        ? Results.Ok(result.Value) : ApiError.Result(context, result.Error switch
        {
            "forbidden" => 403, "staff_not_found" => 404,
            "version_conflict" or "login_unavailable" or "last_owner_required" => 409, _ => 400
        }, result.Error!);
}

public sealed class InternalCookieEvents : CookieAuthenticationEvents
{
    public override async Task ValidatePrincipal(CookieValidatePrincipalContext context)
    {
        // Cookie handlers initialize EventsType even without a cookie. Do not require database configuration
        // merely to challenge an anonymous request or issue its login-CSRF token. Valid tickets still fail closed on storage errors.
        var current = context.Principal is null ? null : await context.HttpContext.RequestServices
            .GetRequiredService<InternalSecurityService>().ValidateSession(context.Principal, context.HttpContext.RequestAborted);
        if (current is null)
        {
            context.RejectPrincipal();
            await context.HttpContext.SignOutAsync(InternalSecurityRules.Scheme);
        }
        else context.ReplacePrincipal(current); // Rebuild identity only from authoritative persisted state, never request fields.
    }
    public override Task RedirectToLogin(RedirectContext<CookieAuthenticationOptions> context) =>
        ApiError.Result(context.HttpContext, 401, "authentication_required").ExecuteAsync(context.HttpContext);
    public override Task RedirectToAccessDenied(RedirectContext<CookieAuthenticationOptions> context) =>
        ApiError.Result(context.HttpContext, 403, "forbidden").ExecuteAsync(context.HttpContext);
}
