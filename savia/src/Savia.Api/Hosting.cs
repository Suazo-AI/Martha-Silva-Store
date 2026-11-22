using System.Threading.RateLimiting;
using Azure.Identity;
using Azure.Monitor.OpenTelemetry.AspNetCore;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using Savia.Infrastructure;

namespace Savia.Api;

/// <summary>
/// Settings for a host that faces the internet behind a TLS proxy (Azure Container Apps).
/// Every switch is off by default, so a branch host and the tests behave as before.
/// </summary>
public static class SaviaHosting
{
    public const string LoginPolicy = "login";

    /// <summary>Set by Azure (infra/main.bicep); absent on branch hosts and in tests.</summary>
    public const string TelemetrySetting = "APPLICATIONINSIGHTS_CONNECTION_STRING";

    /// <summary>
    /// The page may load its own files and blob: photo previews; nothing else.
    /// </summary>
    public const string ContentSecurityPolicy =
        "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' blob: data:; " +
        "media-src 'self' blob:; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'";

    public static void AddSaviaHosting(this IServiceCollection services)
    {
        // Options bind from the final configuration, so values added after the builder was created still apply.
        // Savia:Proxy:TrustForwardedHeaders: only for a host whose sole ingress is a proxy that appends the client
        // address (Container Apps). ForwardLimit 1 reads the last hop, the one the proxy added, so a forged
        // X-Forwarded-For sent by the client is ignored.
        services.AddOptions<ForwardedHeadersOptions>().Configure<IConfiguration>((o, config) =>
        {
            if (!config.GetValue<bool>("Savia:Proxy:TrustForwardedHeaders")) return;
            o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
            o.ForwardLimit = 1;
            o.KnownIPNetworks.Clear();
            o.KnownProxies.Clear();
        });

        // Savia:Auth:LoginPerMinute: sign-in attempts per client address per minute; 0 (default) means no limit.
        // The per-account lockout still applies either way.
        services.AddRateLimiter(_ => { });
        services.AddOptions<RateLimiterOptions>().Configure<IConfiguration>((o, config) =>
        {
            var perMinute = config.GetValue<int>("Savia:Auth:LoginPerMinute");
            o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
            o.AddPolicy(LoginPolicy, http => perMinute <= 0
                ? RateLimitPartition.GetNoLimiter("off")
                : RateLimitPartition.GetFixedWindowLimiter(
                    http.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                    _ => new FixedWindowRateLimiterOptions { PermitLimit = perMinute, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
        });
    }

    /// <summary>
    /// Sends traces, metrics and logs to Application Insights only when <see cref="TelemetrySetting"/> is set.
    /// The connection string names the resource and holds no secret; with <c>AZURE_CLIENT_ID</c> set, export signs in
    /// as that managed identity, so the resource can refuse key-only ingestion.
    /// </summary>
    public static void AddSaviaTelemetry(this WebApplicationBuilder builder)
    {
        var connectionString = builder.Configuration[TelemetrySetting];
        if (string.IsNullOrWhiteSpace(connectionString)) return;
        var clientId = builder.Configuration["AZURE_CLIENT_ID"];
        builder.Services.AddOpenTelemetry().UseAzureMonitor(o =>
        {
            o.ConnectionString = connectionString;
            if (!string.IsNullOrWhiteSpace(clientId))
                o.Credential = new ManagedIdentityCredential(ManagedIdentityId.FromUserAssignedClientId(clientId));
        });
    }

    public static void UseSaviaHosting(this WebApplication app)
    {
        if (app.Configuration.GetValue<bool>("Savia:Proxy:TrustForwardedHeaders")) app.UseForwardedHeaders();
        if (!app.Environment.IsDevelopment()) app.UseHsts();
        app.Use(async (http, next) =>
        {
            var headers = http.Response.Headers;
            headers.ContentSecurityPolicy = ContentSecurityPolicy;
            headers.XContentTypeOptions = "nosniff";
            headers["Referrer-Policy"] = "no-referrer";
            await next();
        });
        app.UseRateLimiter();
    }

    /// <summary><c>/health</c> says the process is up; <c>/health/ready</c> also proves SQL answers.</summary>
    public static void MapSaviaHealth(this WebApplication app)
    {
        app.MapGet("/health", () => Results.Ok(new { status = "ok" })).ExcludeFromDescription();
        app.MapGet("/health/ready", async (SqlGateway sql, CancellationToken ct) => await sql.CanConnectAsync(ct)
            ? Results.Ok(new { status = "ready" })
            : Results.Json(new { status = "database unavailable" }, statusCode: StatusCodes.Status503ServiceUnavailable))
            .ExcludeFromDescription();
    }
}
