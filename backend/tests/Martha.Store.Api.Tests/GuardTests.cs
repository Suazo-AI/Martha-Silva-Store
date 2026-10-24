using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Xunit;
using Martha.Store.Api;

namespace Martha.Store.Api.Tests;

public sealed class GuardTests
{
    [Theory]
    [InlineData("Production", true)]
    [InlineData("Production", false)]
    [InlineData("Staging", true)]
    [InlineData("Test", false)]
    [InlineData("Test", true)]
    [InlineData("Development", false)]
    public async Task Synthetic_writes_are_not_mapped_outside_explicit_test_gate(string environment, bool enabled)
    {
        await using var factory = new TestApiFactory(environment, enabled);
        using var client = factory.CreateClient();
        using var response = await client.PostAsJsonAsync("/api/v1/synthetic/orders", new { variantId = Guid.NewGuid(), quantity = 1 });
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        using var catalog = await client.GetAsync("/api/v1/catalog");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, catalog.StatusCode);
        var body = await catalog.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("catalog_not_enabled", body.GetProperty("code").GetString());
    }

    [Theory]
    [InlineData("")]
    [InlineData("Server=127.0.0.1,1;Database=master;Integrated Security=true;Connect Timeout=1")]
    [InlineData("Server=127.0.0.1,1;Database=StoreProduction;Integrated Security=true;Connect Timeout=1")]
    public async Task Unapproved_database_catalog_fails_closed(string connection)
    {
        await using var factory = new TestApiFactory(connection: connection);
        using var client = factory.CreateClient();
        using var response = await client.GetAsync("/health/ready");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal("storage_unavailable", (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString());
    }

    [Theory]
    [InlineData("")]
    [InlineData("Server=127.0.0.1;Database=master;Integrated Security=true")]
    [InlineData("Server=127.0.0.1;Database=StoreProduction;Integrated Security=true")]
    [InlineData("Server=127.0.0.1;Database=MarthaSynthetic_;Integrated Security=true")]
    [InlineData("not a connection string")]
    public void Database_guard_rejects_before_any_connection_is_opened(string connection)
    {
        Assert.Throws<StorageUnavailableException>(() => StoreDatabaseGuard.Validate(connection));
    }

    [Fact]
    public void Database_guard_accepts_only_named_synthetic_catalog()
    {
        StoreDatabaseGuard.Validate("Server=127.0.0.1;Database=MarthaSynthetic_Test_123;Integrated Security=true");
    }

    [Fact]
    public async Task Liveness_does_not_claim_database_readiness()
    {
        await using var factory = new TestApiFactory();
        using var client = factory.CreateClient();
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/health/live")).StatusCode);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, (await client.GetAsync("/health/ready")).StatusCode);
    }
}
