using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Xunit;

namespace Martha.Store.Api.Tests;

public sealed class SaviaContractTests
{
    internal const string Prefix = "/api/v2/synthetic";
    internal static readonly Guid VariantId = Guid.Parse("33333333-3333-3333-3333-333333333333");
    internal static readonly Guid LocationId = Guid.Parse("44444444-4444-4444-4444-444444444444");
    internal static object Authority => new { mode = "savia", instanceId = "savia-synthetic-v2", epoch = 1 };
    internal static object ReserveBody(Guid attemptId, int quantity = 1) => new
    { variantId = VariantId, locationId = LocationId, quantity, attemptId, authority = Authority };

    internal static async Task<HttpResponseMessage> Send(HttpClient client, string path, object body, string key)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, Prefix + path) { Content = JsonContent.Create(body) };
        request.Headers.TryAddWithoutValidation("Idempotency-Key", key);
        return await client.SendAsync(request);
    }

    internal static async Task AssertError(HttpResponseMessage response, HttpStatusCode status, string code)
    {
        Assert.Equal(status, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        var error = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal((int)status, error.GetProperty("status").GetInt32());
        Assert.Equal(code, error.GetProperty("code").GetString());
        Assert.False(string.IsNullOrWhiteSpace(error.GetProperty("traceId").GetString()));
    }

    [Theory]
    [InlineData("Production", true)]
    [InlineData("Production", false)]
    [InlineData("Staging", true)]
    [InlineData("Test", false)]
    [InlineData("Test", true)]
    [InlineData("Development", false)]
    public async Task All_v2_routes_are_absent_when_the_synthetic_gate_is_closed(string environment, bool enabled)
    {
        await using var factory = new TestApiFactory(environment, enabled);
        using var client = factory.CreateClient();
        foreach (var path in new[] { "/catalog", "/capabilities", "/movements", $"/reservations/{Guid.NewGuid()}", $"/attempts/reserve/{Guid.NewGuid()}" })
        {
            using var response = await client.GetAsync(Prefix + path);
            Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        }
        using var reserve = await Send(client, "/reservations", ReserveBody(Guid.NewGuid()), "gate-reserve-001");
        using var cancel = await Send(client, $"/reservations/{Guid.NewGuid()}/cancel", new { attemptId = Guid.NewGuid(), authority = Authority }, "gate-cancel-001");
        Assert.Equal(HttpStatusCode.NotFound, reserve.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, cancel.StatusCode);
    }

    [Fact]
    public async Task Capabilities_identify_synthetic_authority_without_database_access()
    {
        await using var factory = new TestApiFactory();
        using var client = factory.CreateClient();
        using var response = await client.GetAsync(Prefix + "/capabilities");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(body.GetProperty("synthetic").GetBoolean());
        AssertAuthority(body.GetProperty("authority"));
        Assert.NotEmpty(body.GetProperty("providers").EnumerateArray());
    }

    internal static void AssertAuthority(JsonElement authority)
    {
        Assert.Equal("savia", authority.GetProperty("mode").GetString());
        Assert.Equal("savia-synthetic-v2", authority.GetProperty("instanceId").GetString());
        Assert.Equal(1, authority.GetProperty("epoch").GetInt32());
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(101)]
    [InlineData(int.MaxValue)]
    public async Task Invalid_reservation_quantity_is_rejected_before_database_access(int quantity)
    {
        await using var factory = new TestApiFactory();
        using var client = factory.CreateClient();
        using var response = await Send(client, "/reservations", ReserveBody(Guid.NewGuid(), quantity), "bad-quantity-001");
        await AssertError(response, HttpStatusCode.BadRequest, "invalid_request");
    }

    [Theory]
    [InlineData("")]
    [InlineData("short")]
    [InlineData("has space 001")]
    [InlineData("nonascii-é-001")]
    public async Task Invalid_idempotency_key_is_rejected_before_database_access(string key)
    {
        await using var factory = new TestApiFactory();
        using var client = factory.CreateClient();
        using var response = await Send(client, "/reservations", ReserveBody(Guid.NewGuid()), key);
        await AssertError(response, HttpStatusCode.BadRequest, "invalid_request");
    }

    [Theory]
    [InlineData("mode", "cga")]
    [InlineData("instanceId", "another-synthetic-instance")]
    [InlineData("epoch", "2")]
    public async Task Authority_mismatch_is_rejected_before_database_access_for_both_commands(string field, string value)
    {
        await using var factory = new TestApiFactory();
        using var client = factory.CreateClient();
        var authority = new Dictionary<string, object> { ["mode"] = "savia", ["instanceId"] = "savia-synthetic-v2", ["epoch"] = 1 };
        authority[field] = field == "epoch" ? int.Parse(value) : value;
        using var reserve = await Send(client, "/reservations", new { variantId = VariantId, locationId = LocationId, quantity = 1, attemptId = Guid.NewGuid(), authority }, "authority-reserve-001");
        using var cancel = await Send(client, $"/reservations/{Guid.NewGuid()}/cancel", new { attemptId = Guid.NewGuid(), authority }, "authority-cancel-001");
        await AssertError(reserve, HttpStatusCode.Conflict, "authority_mismatch");
        await AssertError(cancel, HttpStatusCode.Conflict, "authority_mismatch");
    }

    [Theory]
    [InlineData("unitPriceMinor")]
    [InlineData("totalMinor")]
    [InlineData("customer")]
    [InlineData("onHand")]
    public async Task Server_owned_fields_are_rejected_before_database_access(string field)
    {
        await using var factory = new TestApiFactory();
        using var client = factory.CreateClient();
        var body = new Dictionary<string, object>
        { ["variantId"] = VariantId, ["locationId"] = LocationId, ["quantity"] = 1, ["attemptId"] = Guid.NewGuid(), ["authority"] = Authority, [field] = 0 };
        using var response = await Send(client, "/reservations", body, "reject-owned-field-001");
        await AssertError(response, HttpStatusCode.BadRequest, "invalid_request");
    }

    [Fact]
    public async Task Empty_attempt_and_multiple_keys_are_invalid_without_database_access()
    {
        await using var factory = new TestApiFactory();
        using var client = factory.CreateClient();
        using var emptyAttempt = await Send(client, "/reservations", ReserveBody(Guid.Empty), "empty-attempt-001");
        await AssertError(emptyAttempt, HttpStatusCode.BadRequest, "invalid_request");
        using var request = new HttpRequestMessage(HttpMethod.Post, Prefix + "/reservations") { Content = JsonContent.Create(ReserveBody(Guid.NewGuid())) };
        request.Headers.TryAddWithoutValidation("Idempotency-Key", new[] { "first-valid-key-001", "second-valid-key-002" });
        using var multipleKeys = await client.SendAsync(request);
        await AssertError(multipleKeys, HttpStatusCode.BadRequest, "invalid_request");
    }
}
