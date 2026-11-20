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
    private sealed class Host(Dictionary<string, string?> extra) : WebApplicationFactory<Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment("Testing");
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
}
