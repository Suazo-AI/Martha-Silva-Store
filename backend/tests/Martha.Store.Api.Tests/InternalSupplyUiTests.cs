using System.Net;
using System.Security.Claims;
using System.Text.Encodings.Web;
using Martha.Store.Api.Internal;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Xunit;

namespace Martha.Store.Api.Tests;

public sealed class InternalSupplyUiTests
{
    [Fact]
    public async Task Supply_resource_is_embedded_protected_and_serves_the_source_bytes()
    {
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions { EnvironmentName = "Test" });
        builder.WebHost.UseTestServer();
        builder.Logging.ClearProviders();
        builder.Services.AddAuthentication("SupplyUiTest")
            .AddScheme<AuthenticationSchemeOptions, SupplyUiAuthentication>("SupplyUiTest", _ => { });
        builder.Services.AddAuthorization(options => options.AddPolicy("internal.read", p =>
            p.RequireAuthenticatedUser().RequireRole("Owner", "Manager", "Cashier", "Inventory")));
        await using var app = builder.Build();
        app.UseAuthentication();
        app.UseAuthorization();
        app.MapInternalUi();
        await app.StartAsync();
        using var client = app.GetTestClient();

        using var anonymous = await client.GetAsync("/internal/supply.mjs");
        Assert.Equal(HttpStatusCode.Unauthorized, anonymous.StatusCode);
        client.DefaultRequestHeaders.Add("X-Test-Authenticated", "yes");
        using var response = await client.GetAsync("/internal/supply.mjs");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("text/javascript", response.Content.Headers.ContentType?.MediaType);
        var actual = await response.Content.ReadAsByteArrayAsync();
        Assert.NotEmpty(actual);
        await using var resource = typeof(InternalUiHosting).Assembly.GetManifestResourceStream("SaviaStaff.supply.mjs");
        Assert.NotNull(resource);
        using var embedded = new MemoryStream();
        await resource.CopyToAsync(embedded);
        Assert.Equal(embedded.ToArray(), actual);

        // Compare the compiled resource with this checkout's source, including its BOM/line endings.
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "dev/savia-staff-ui/supply.mjs")))
            directory = directory.Parent;
        Assert.NotNull(directory);
        Assert.Equal(await File.ReadAllBytesAsync(Path.Combine(directory.FullName, "dev/savia-staff-ui/supply.mjs")), actual);
    }

    // This test-only handler proves route authorization wiring, not real cookie/session validation.
    private sealed class SupplyUiAuthentication(IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger, UrlEncoder encoder) : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            if (Request.Headers["X-Test-Authenticated"] != "yes") return Task.FromResult(AuthenticateResult.NoResult());
            var principal = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.Role, "Owner")], Scheme.Name));
            return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(principal, Scheme.Name)));
        }
    }
}
