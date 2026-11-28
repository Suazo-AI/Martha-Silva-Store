using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Cors.Infrastructure;
using Microsoft.AspNetCore.RateLimiting;
using Savia.Application;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Api;

/// <summary>
/// Services and middleware of the public order path. Settings (none hold a secret except the Turnstile one, which
/// comes from the environment):
/// <c>Savia:Public:AllowedOrigins</c> comma-separated storefront origins for CORS (none by default);
/// <c>Savia:Public:PerMinute</c> requests per client address per minute on public routes (60; 0 turns the limit off);
/// <c>Savia:Public:BotCheck</c> <c>disabled</c> for local runs only, otherwise Turnstile;
/// <c>Savia:Public:Turnstile:Secret</c>; <c>Savia:Public:OrderPageUrl</c> where a payment return sends the buyer;
/// <c>Savia:WebStore:SweepSeconds</c> how often expiry and web-stock moves run (60; 0 turns them off).
/// </summary>
public static class WebStoreHosting
{
    public const string RatePolicy = "public";
    public const string CorsPolicy = "public";

    public static void AddSaviaWebStore(this IServiceCollection services)
    {
        services.AddHttpClient(TurnstileBotCheck.ClientName, c => c.Timeout = TimeSpan.FromSeconds(10));
        services.AddSingleton<IBotCheck>(sp =>
        {
            if (sp.GetRequiredService<IConfiguration>()["Savia:Public:BotCheck"] != "disabled")
                return ActivatorUtilities.CreateInstance<TurnstileBotCheck>(sp);
            // SEC-38: the switch is for local runs and tests; a Production host refuses to start with it.
            if (sp.GetRequiredService<IHostEnvironment>().IsProduction())
                throw new InvalidOperationException("Savia:Public:BotCheck=disabled is not allowed in Production.");
            return new DisabledBotCheck();
        });
        services.AddSingleton<IPaymentProvider, ManualPaymentProvider>();
        services.AddSingleton<PaymentProviders>();
        services.AddSingleton<WebStoreSweep>();
        services.AddHostedService<WebStoreWorker>();

        services.AddCors();
        services.AddOptions<CorsOptions>().Configure<IConfiguration>((o, config) =>
        {
            var origins = (config["Savia:Public:AllowedOrigins"] ?? "")
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            // No AllowCredentials: the order token travels in a header the page sets, never in a cookie.
            o.AddPolicy(CorsPolicy, p => p.WithOrigins(origins).WithMethods("GET", "POST")
                .WithHeaders("Content-Type", "Idempotency-Key", "X-Order-Token"));
        });
        services.AddOptions<RateLimiterOptions>().Configure<IConfiguration>((o, config) =>
        {
            var perMinute = config.GetValue("Savia:Public:PerMinute", 60);
            o.AddPolicy(RatePolicy, http => perMinute <= 0
                ? RateLimitPartition.GetNoLimiter("off")
                : RateLimitPartition.GetFixedWindowLimiter(
                    http.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                    _ => new FixedWindowRateLimiterOptions { PermitLimit = perMinute, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
            o.OnRejected = async (context, ct) =>
            {
                var http = context.HttpContext;
                if (!http.Request.Path.StartsWithSegments(PublicEndpoints.Prefix)) return;
                await http.Response.WriteAsJsonAsync(new PublicProblem("rate_limited", "Demasiadas solicitudes. Espere un minuto.",
                    http.TraceIdentifier), ct);
            };
        });
    }

    /// <summary>CORS for the public routes only; staff routes stay same-origin.</summary>
    public static void UseSaviaPublicCors(this WebApplication app) =>
        app.UseWhen(http => http.Request.Path.StartsWithSegments(PublicEndpoints.Prefix), branch => branch.UseCors(CorsPolicy));
}

public sealed record SweepResult(int Paid, int Expired, int Skipped, int Review);

/// <summary>
/// One pass of the web-order jobs. The hub credits arrived consignments, then settles each reservation past its expiry:
/// it asks the provider first, because the buyer may have paid and closed the tab. A branch applies arrived releases.
/// Every step is idempotent in SQL, so two hosts or a retry cannot release twice.
/// </summary>
public sealed class WebStoreSweep(WebStoreService web, PaymentProviders providers, NodeContext node, ILogger<WebStoreSweep> log)
{
    public async Task<SweepResult> RunOnceAsync(CancellationToken ct)
    {
        if (node.Kind == NodeKind.Branch)
        {
            await web.ApplyReleasesAsync(ct);
            return new SweepResult(0, 0, 0, 0);
        }
        try
        {
            await web.ApplyConsignmentsAsync(ct);
        }
        catch (Exception ex) when (!ct.IsCancellationRequested)
        {
            // A bad consignment must not hold back expiry: reserved stock would stay locked behind it.
            log.LogWarning("Web consignments not applied this pass: {Error}", SafeLog.Describe(ex));
        }
        int paid = 0, expired = 0, skipped = 0, review = 0;
        foreach (var due in await web.DueOrdersAsync(ct))
        {
            try
            {
                switch (await SettleAsync(due, ct))
                {
                    case Outcome.Paid: paid++; break;
                    case Outcome.Expired: expired++; break;
                    case Outcome.Kept: skipped++; break;
                    case Outcome.Review: review++; break;
                }
            }
            catch (Exception ex) when (!ct.IsCancellationRequested)
            {
                // One order that cannot be settled (a provider or database error, say) stays reserved for the next pass;
                // the orders behind it must still expire and free their stock.
                log.LogWarning("Due web order {Order} not settled: {Error}", due.OrderId, SafeLog.Describe(ex));
                skipped++;
            }
        }
        return new SweepResult(paid, expired, skipped, review);
    }

    private enum Outcome { None, Paid, Expired, Kept, Review }

    private async Task<Outcome> SettleAsync(DueWebOrder due, CancellationToken ct)
    {
        var provider = providers.ByCode(due.Provider);
        var result = provider is null ? null : await provider.QueryAsync(due.OrderId, null, ct);
        if (provider is not null && result is not null && PaymentProviders.Verified(provider, result, due.OrderId) is { } payment)
        {
            return await web.RecordVerifiedPaymentAsync(payment, ct) switch
            {
                CaptureOutcome.Paid => Outcome.Paid,
                CaptureOutcome.Review => Outcome.Review,
                _ => Outcome.None,
            };
        }
        if (result?.Status == PaymentStatus.Unknown)
        {
            // The provider did not answer: keep the reservation and ask again next pass. Staff can still cancel it.
            log.LogWarning("Provider {Provider} gave no answer for due order {Order}; kept reserved.", due.Provider, due.OrderId);
            return Outcome.Kept;
        }
        return await web.ExpireAsync(due.OrderId, ct) ? Outcome.Expired : Outcome.None;
    }
}

/// <summary>Runs <see cref="WebStoreSweep"/> every <c>Savia:WebStore:SweepSeconds</c>. A failed pass is logged and retried.</summary>
public sealed class WebStoreWorker(WebStoreSweep sweep, IConfiguration config, ILogger<WebStoreWorker> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var seconds = config.GetValue("Savia:WebStore:SweepSeconds", 60);
        if (seconds <= 0) return;
        // The first pass waits one interval, so a host that starts and stops at once (a test, a provisioning run) never sweeps.
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(Math.Max(5, seconds)));
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            try
            {
                var result = await sweep.RunOnceAsync(stoppingToken);
                if (result != new SweepResult(0, 0, 0, 0))
                    log.LogInformation("Web orders: {Paid} paid, {Expired} expired, {Skipped} kept, {Review} to review.",
                        result.Paid, result.Expired, result.Skipped, result.Review);
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                log.LogWarning("Web-order sweep failed: {Error}", SafeLog.Describe(ex));
            }
        }
    }
}
