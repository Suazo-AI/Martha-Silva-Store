using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Savia.Api;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Tests;

/// <summary>
/// Internet-facing host settings (savia/docs/deploy/AZURE.md P1, P3, P4). No SQL: the connection points at a closed
/// port, which is exactly what the readiness probe must report.
/// </summary>
public sealed class HostingTests
{
    private sealed class Host(Dictionary<string, string?> extra, string environment = "Testing") : WebApplicationFactory<Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment(environment);
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Savia:Node:Kind"] = nameof(NodeKind.Cloud),
                ["Savia:Node:NodeId"] = Ids.NodeCloud.ToString(),
                ["Savia:Sql:ConnectionString"] =
                    "Server=tcp:127.0.0.1,1;Database=savia_none;Integrated Security=false;User ID=none;Password=none;Connect Timeout=1;Encrypt=false",
            }).AddInMemoryCollection(extra));
        }
    }

    private static Task<HttpResponseMessage> Login(HttpClient client, string? forwardedFor = null)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, "/api/v1/auth/login")
        {
            Content = JsonContent.Create(new LoginRequest("nobody", "wrong-password")),
        };
        if (forwardedFor is not null) request.Headers.Add("X-Forwarded-For", forwardedFor);
        return client.SendAsync(request);
    }

    [Fact]
    public async Task Every_response_carries_the_security_headers()
    {
        using var host = new Host([]);
        var response = await host.CreateClient().GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(SaviaHosting.ContentSecurityPolicy, response.Headers.GetValues("Content-Security-Policy").Single());
        Assert.Equal("nosniff", response.Headers.GetValues("X-Content-Type-Options").Single());
        Assert.Equal("no-referrer", response.Headers.GetValues("Referrer-Policy").Single());
    }

    [Fact]
    public async Task Readiness_reports_503_when_sql_does_not_answer_while_liveness_stays_up()
    {
        using var host = new Host([]);
        var client = host.CreateClient();

        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/health")).StatusCode);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await client.GetAsync("/health/ready")).StatusCode);
    }

    [Fact]
    public async Task Login_is_not_rate_limited_unless_configured()
    {
        using var host = new Host([]);
        var client = host.CreateClient();

        for (var i = 0; i < 5; i++)
            Assert.NotEqual(HttpStatusCode.TooManyRequests, (await Login(client)).StatusCode);
    }

    [Fact]
    public async Task Login_limit_is_per_client_address_and_ignores_forged_earlier_hops()
    {
        using var host = new Host(new()
        {
            ["Savia:Auth:LoginPerMinute"] = "1",
            ["Savia:Proxy:TrustForwardedHeaders"] = "true",
        });
        var client = host.CreateClient();

        // The proxy appends the real address last; a client can only forge the entries before it.
        Assert.NotEqual(HttpStatusCode.TooManyRequests, (await Login(client, "198.51.100.1, 203.0.113.5")).StatusCode);
        Assert.Equal(HttpStatusCode.TooManyRequests, (await Login(client, "198.51.100.2, 203.0.113.5")).StatusCode);
        Assert.NotEqual(HttpStatusCode.TooManyRequests, (await Login(client, "203.0.113.6")).StatusCode);
    }

    [Fact]
    public async Task The_openapi_document_is_served_outside_production_only()
    {
        using var testing = new Host([]);
        Assert.Equal(HttpStatusCode.OK, (await testing.CreateClient().GetAsync("/openapi/v1.json")).StatusCode);

        using var production = new Host([], "Production");
        var client = production.CreateClient();
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/health")).StatusCode);
        Assert.NotEqual(HttpStatusCode.OK, (await client.GetAsync("/openapi/v1.json")).StatusCode);
    }

    [Fact]
    public void A_production_host_refuses_to_start_with_the_bot_check_off()
    {
        using var production = new Host(new() { ["Savia:Public:BotCheck"] = "disabled" }, "Production");
        var refused = Assert.ThrowsAny<Exception>(() => production.CreateClient());
        Assert.Contains("Savia:Public:BotCheck=disabled is not allowed in Production", refused.ToString());

        using var testing = new Host(new() { ["Savia:Public:BotCheck"] = "disabled" });
        testing.CreateClient();
    }

    [Fact]
    public async Task Staff_sync_and_readiness_routes_are_limited_per_client_address_only_when_configured()
    {
        using var open = new Host([]);
        var free = open.CreateClient();
        for (var i = 0; i < 5; i++)
        {
            Assert.NotEqual(HttpStatusCode.TooManyRequests, (await free.GetAsync("/api/v1/me")).StatusCode);
            Assert.NotEqual(HttpStatusCode.TooManyRequests, (await free.GetAsync("/health/ready")).StatusCode);
        }

        using var limited = new Host(new() { ["Savia:Hosting:PerMinute"] = "3" });
        var client = limited.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/v1/me")).StatusCode);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await client.GetAsync("/health/ready")).StatusCode);
        Assert.NotEqual(HttpStatusCode.TooManyRequests, (await client.GetAsync("/sync/v1/state")).StatusCode);
        foreach (var path in new[] { "/api/v1/me", "/health/ready", "/sync/v1/state" })
            Assert.Equal(HttpStatusCode.TooManyRequests, (await client.GetAsync(path)).StatusCode);
        // Liveness stays outside the limit, so the platform probe never restarts a busy host.
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/health")).StatusCode);
    }
}
