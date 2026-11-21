using Savia.Application;
using Savia.Domain;
using Savia.Infrastructure;

namespace Savia.Api;

/// <summary>Reads the <c>SaviaNode</c> credential and stores the caller's node id, or answers 401.</summary>
public sealed class SyncNodeFilter(SyncHubService sync) : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var http = context.HttpContext;
        http.Items[typeof(SyncNodeFilter)] = await sync.AuthenticateAsync(http.Request.Headers.Authorization.ToString(), http.RequestAborted);
        return await next(context);
    }
}

/// <summary>Hub side of the P9 transport (docs/sync/P9-SPEC.md). Mapped on the cloud node only.</summary>
public static class SyncEndpoints
{
    public static void Map(WebApplication app, NodeContext node)
    {
        if (node.Kind != NodeKind.Cloud) return;
        var sync = app.MapGroup("/sync/v1").AddEndpointFilter<SyncNodeFilter>().ExcludeFromDescription();
        sync.MapGet("/state", async (SyncHubService hub, CancellationToken ct) => Json(await hub.StateAsync(ct)));
        sync.MapPost("/push/plan", async (HttpContext http, SyncHubService hub, CancellationToken ct) =>
            Json(await hub.PushPlanAsync(Peer(http), await BodyAsync(http, ct), ct)));
        sync.MapPost("/push", async (HttpContext http, SyncHubService hub, CancellationToken ct) =>
            Json(await hub.PushAsync(Peer(http), await BodyAsync(http, ct), ct)));
        sync.MapPost("/pull", async (HttpContext http, SyncHubService hub, CancellationToken ct) =>
            Json(await hub.PullAsync(Peer(http), await BodyAsync(http, ct), ct)));
    }

    private static Guid Peer(HttpContext http) => (Guid)http.Items[typeof(SyncNodeFilter)]!;

    private static IResult Json(string json) => Results.Text(json, "application/json");

    private static async Task<string> BodyAsync(HttpContext http, CancellationToken ct)
    {
        using var reader = new StreamReader(http.Request.Body);
        return await reader.ReadToEndAsync(ct);
    }
}

/// <summary>
/// Branch worker: one <see cref="BranchSync"/> round every <c>Savia:Sync:IntervalSeconds</c> (default 60).
/// Off unless the node is a branch and <c>Savia:Sync:HubUrl</c> is set. <c>Savia:Sync:NodeSecret</c> comes from an
/// environment variable or a secret store, never from Git. A failed round is logged and repeated from a fresh plan.
/// </summary>
public sealed class SyncWorker(IServiceProvider services, IConfiguration config, ILogger<SyncWorker> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var node = services.GetRequiredService<NodeContext>();
        var hubUrl = config["Savia:Sync:HubUrl"];
        if (node.Kind != NodeKind.Branch || string.IsNullOrWhiteSpace(hubUrl)) return;
        var secret = config["Savia:Sync:NodeSecret"];
        if (string.IsNullOrWhiteSpace(secret))
        {
            log.LogError("Savia:Sync:HubUrl is set but Savia:Sync:NodeSecret is missing; sync is off.");
            return;
        }
        // A bad URL must not stop the branch host: an exception here would end ExecuteAsync and, by default, the host.
        if (!Uri.TryCreate(hubUrl.TrimEnd('/') + "/", UriKind.Absolute, out var hubUri) || hubUri.Scheme is not ("https" or "http"))
        {
            log.LogError("Savia:Sync:HubUrl is not an absolute http(s) URL; sync is off.");
            return;
        }
        var seconds = 60;
        if (config["Savia:Sync:IntervalSeconds"] is { } text && !int.TryParse(text, out seconds))
        {
            log.LogError("Savia:Sync:IntervalSeconds is not a whole number; using 60.");
            seconds = 60;
        }
        var interval = TimeSpan.FromSeconds(Math.Max(5, seconds));
        using var http = new HttpClient { BaseAddress = hubUri, Timeout = TimeSpan.FromMinutes(5) };
        var round = new BranchSync(services.GetRequiredService<ISyncStore>(), new HttpSyncHub(http, node.NodeId, secret), node);
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var result = await round.RunOnceAsync(stoppingToken);
                log.LogInformation("Sync round: pulled {Pulled}, pushed {Pushed}, rebuilt {Rebuilt}.", result.Pulled, result.Pushed, result.Rebuilt);
            }
            catch (SaviaException ex)
            {
                log.LogWarning("Sync round refused: {Code} {Message}", ex.Error.Code, ex.Error.Message);
            }
            catch (HttpRequestException ex)
            {
                log.LogWarning("Sync round could not reach the hub: {Message}", ex.Message);
            }
            catch (TaskCanceledException) when (!stoppingToken.IsCancellationRequested)
            {
                log.LogWarning("Sync round timed out.");
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                // A failed round must never stop the branch host; the next round starts from a fresh plan.
                log.LogError(ex, "Sync round failed.");
            }
            await Task.Delay(interval, stoppingToken).ContinueWith(_ => { }, CancellationToken.None);
        }
    }
}
