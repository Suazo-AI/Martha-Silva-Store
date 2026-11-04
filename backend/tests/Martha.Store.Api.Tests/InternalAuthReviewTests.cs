using System.Text.Json;
using Martha.Store.Api.Internal;
using Xunit;

namespace Martha.Store.Api.Tests;

public sealed class InternalAuthReviewTests
{
    private static readonly JsonSerializerOptions WebJson = new(JsonSerializerDefaults.Web);
    private const string Version = "98b8a67f-efb0-4622-85ef-2c85eae07c80";

    [Fact]
    public void Staff_update_rejects_omitted_enabled_instead_of_silently_disabling_staff()
    {
        var json = $$"""{"displayName":"Synthetic staff","role":"Manager","version":"{{Version}}"}""";

        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<InternalStaffUpdateRequest>(json, WebJson));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Staff_update_accepts_explicit_enabled_state(bool enabled)
    {
        var json = $$"""{"displayName":"Synthetic staff","role":"Manager","enabled":{{(enabled ? "true" : "false")}},"version":"{{Version}}"}""";

        var request = JsonSerializer.Deserialize<InternalStaffUpdateRequest>(json, WebJson);

        Assert.NotNull(request);
        Assert.Equal("Synthetic staff", request.DisplayName);
        Assert.Equal("Manager", request.Role);
        Assert.Equal(enabled, request.Enabled);
        Assert.Equal(Guid.Parse(Version), request.Version);
    }

    [Fact]
    public void Staff_update_keeps_existing_json_field_names_and_boolean_shape()
    {
        var request = new InternalStaffUpdateRequest("Synthetic staff", "Manager", false, Guid.Parse(Version));

        var json = JsonSerializer.SerializeToElement(request, WebJson);

        Assert.Equal(new[] { "displayName", "role", "enabled", "version" }, json.EnumerateObject().Select(property => property.Name));
        Assert.Equal(JsonValueKind.False, json.GetProperty("enabled").ValueKind);
        Assert.Equal(request, JsonSerializer.Deserialize<InternalStaffUpdateRequest>(json, WebJson));
    }
}
