using System.Net;
using Savia.Infrastructure;

namespace Savia.Api;

/// <summary>Is the public order request from a person? Checked before any stock is reserved.</summary>
public interface IBotCheck
{
    Task<bool> PassesAsync(string? token, IPAddress? client, CancellationToken ct);
}

/// <summary>
/// Cloudflare Turnstile, checked server-side with siteverify. The secret comes from <c>Savia:Public:Turnstile:Secret</c>
/// (never the repository). A missing secret or an unreachable siteverify fails closed: no order is taken.
/// </summary>
public sealed class TurnstileBotCheck(IHttpClientFactory clients, IConfiguration config, ILogger<TurnstileBotCheck> log) : IBotCheck
{
    public const string ClientName = "turnstile";
    private static readonly Uri SiteVerify = new("https://challenges.cloudflare.com/turnstile/v0/siteverify");

    public async Task<bool> PassesAsync(string? token, IPAddress? client, CancellationToken ct)
    {
        var secret = config["Savia:Public:Turnstile:Secret"];
        if (string.IsNullOrWhiteSpace(secret))
        {
            log.LogError("Savia:Public:Turnstile:Secret is missing; public orders are refused.");
            return false;
        }
        if (string.IsNullOrWhiteSpace(token)) return false;
        var form = new Dictionary<string, string> { ["secret"] = secret, ["response"] = token };
        if (client is not null) form["remoteip"] = client.ToString();
        try
        {
            using var response = await clients.CreateClient(ClientName).PostAsync(SiteVerify, new FormUrlEncodedContent(form), ct);
            if (!response.IsSuccessStatusCode) return false;
            var reply = await response.Content.ReadFromJsonAsync<SiteVerifyReply>(ct);
            return reply?.Success == true;
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException && !ct.IsCancellationRequested)
        {
            log.LogWarning("Turnstile siteverify did not answer: {Error}", SafeLog.Describe(ex));
            return false;
        }
    }

    private sealed record SiteVerifyReply(bool Success);
}

/// <summary>For local runs and tests only: <c>Savia:Public:BotCheck=disabled</c>.</summary>
public sealed class DisabledBotCheck : IBotCheck
{
    public Task<bool> PassesAsync(string? token, IPAddress? client, CancellationToken ct) => Task.FromResult(true);
}
