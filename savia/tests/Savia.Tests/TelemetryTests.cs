using System.Net;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using OpenTelemetry.Trace;
using Savia.Api;
using Savia.Domain;

namespace Savia.Tests;

/// <summary>
/// Application Insights export (savia/docs/deploy/AZURE.md P2) is on only when a connection string is configured.
/// The fake connection string points every endpoint at a closed loopback port, so nothing leaves the machine.
/// </summary>
public sealed class TelemetryTests
{
    private const string LoopbackConnectionString =
        "InstrumentationKey=00000000-0000-0000-0000-000000000000;" +
        "IngestionEndpoint=https://127.0.0.1:9/;LiveEndpoint=https://127.0.0.1:9/";

    private sealed class Host(string? connectionString) : WebApplicationFactory<Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment("Testing");
            builder.UseSetting("Savia:Node:Kind", nameof(NodeKind.Cloud));
            builder.UseSetting("Savia:Node:NodeId", Ids.NodeCloud.ToString());
            builder.UseSetting("Savia:Sql:ConnectionString",
                "Server=tcp:127.0.0.1,1;Database=savia_none;Integrated Security=false;User ID=none;Password=none;Connect Timeout=1;Encrypt=false");
            if (connectionString is not null) builder.UseSetting(SaviaHosting.TelemetrySetting, connectionString);
        }
    }

    [Fact]
    public async Task Host_starts_without_telemetry_when_no_connection_string_is_set()
    {
        using var host = new Host(null);

        Assert.Equal(HttpStatusCode.OK, (await host.CreateClient().GetAsync("/health")).StatusCode);
        Assert.Null(host.Services.GetService<TracerProvider>());
    }

    [Fact]
    public async Task Host_starts_with_telemetry_when_a_connection_string_is_set()
    {
        using var host = new Host(LoopbackConnectionString);

        Assert.Equal(HttpStatusCode.OK, (await host.CreateClient().GetAsync("/health")).StatusCode);
        Assert.NotNull(host.Services.GetService<TracerProvider>());
    }
}
