using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;

namespace Martha.Store.Api.Tests;

public sealed class TestApiFactory(string environment = "Development", bool enabled = true, string? connection = null)
    : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment(environment);
        builder.UseSetting("Synthetic:Enabled", enabled.ToString());
        builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Synthetic:Enabled"] = enabled.ToString(),
            ["ConnectionStrings:Store"] = connection ?? ""
        }));
    }
}
