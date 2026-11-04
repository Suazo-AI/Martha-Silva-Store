using System.Net.Http.Json;
using System.Text.Json;
using Martha.Store.Api.Internal;
using Xunit;

namespace Martha.Store.Api.Tests;

// Written contract tests, not evidence of compilation, HTTP, SQL or migration.
public sealed class InternalBranchCompatibilityTests
{
    private static readonly JsonSerializerOptions WebJson = new(JsonSerializerDefaults.Web);
    private static readonly Guid Branch = Guid.Parse("fc300e41-365e-4c4e-a6d3-a6cf28065128");
    private static readonly Guid Version = Guid.Parse("265bcae0-7e38-4a4f-8d1a-e260acc05eba");
    private static string StaffJson(string branch = "") =>
        "{\"displayName\":\"Synthetic staff\",\"role\":\"Manager\",\"enabled\":true,\"version\":\"" + Version + "\"" + branch + "}";

    [Fact]
    public void Location_omitted_null_and_guid_are_distinct_and_survive_normalization()
    {
        var omitted = JsonSerializer.Deserialize<InternalLocationWrite>("{\"name\":\" Location \"}", WebJson)!;
        var clear = JsonSerializer.Deserialize<InternalLocationWrite>("{\"name\":\"Location\",\"branchId\":null}", WebJson)!;
        var assign = JsonSerializer.Deserialize<InternalLocationWrite>("{\"name\":\"Location\",\"branchId\":\"" + Branch + "\"}", WebJson)!;
        Assert.False(omitted.BranchId.IsSpecified);
        Assert.True(clear.BranchId.IsSpecified);
        Assert.Null(clear.BranchId.Value);
        Assert.True(assign.BranchId.IsSpecified);
        Assert.Equal(Branch, assign.BranchId.Value);
        Assert.True(omitted.Active);
        Assert.False(InternalDirectoryValidation.Location(omitted).Value!.BranchId.IsSpecified);
        Assert.True(InternalDirectoryValidation.Location(clear).Value!.BranchId.IsSpecified);
        Assert.Equal(Branch, InternalDirectoryValidation.Location(assign).Value!.BranchId.Value);
    }

    [Fact]
    public void Staff_omitted_null_and_guid_are_distinct()
    {
        var omitted = JsonSerializer.Deserialize<InternalStaffUpdateRequest>(StaffJson(), WebJson)!;
        var clear = JsonSerializer.Deserialize<InternalStaffUpdateRequest>(StaffJson(",\"branchId\":null"), WebJson)!;
        var assign = JsonSerializer.Deserialize<InternalStaffUpdateRequest>(StaffJson(",\"branchId\":\"" + Branch + "\""), WebJson)!;
        Assert.False(omitted.BranchId.IsSpecified);
        Assert.True(clear.BranchId.IsSpecified);
        Assert.Null(clear.BranchId.Value);
        Assert.True(assign.BranchId.IsSpecified);
        Assert.Equal(Branch, assign.BranchId.Value);
        Assert.True(assign.Enabled);
        Assert.Equal(Version, assign.Version);
    }

    [Theory]
    [InlineData("true")]
    [InlineData("12")]
    [InlineData("[]")]
    [InlineData("{}")]
    [InlineData("{\"isSpecified\":true,\"value\":null}")]
    [InlineData("{\"isSpecified\":false,\"value\":\"fc300e41-365e-4c4e-a6d3-a6cf28065128\"}")]
    [InlineData("\"invalid\"")]
    [InlineData("\"00000000-0000-0000-0000-000000000000\"")]
    public void Invalid_branch_tokens_and_client_presence_objects_are_rejected(string token)
    {
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<InternalLocationWrite>(
            "{\"name\":\"Location\",\"branchId\":" + token + "}", WebJson));
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<InternalStaffUpdateRequest>(
            StaffJson(",\"branchId\":" + token), WebJson));
    }

    [Fact]
    public void Existing_required_fields_and_directory_unknown_property_rejection_remain()
    {
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<InternalLocationWrite>("{\"active\":true}", WebJson));
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<InternalLocationWrite>(
            "{\"name\":\"Location\",\"branchIdSpecified\":true}", WebJson));
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<InternalStaffUpdateRequest>(
            "{\"displayName\":\"Synthetic staff\",\"role\":\"Manager\",\"version\":\"" + Version + "\"}", WebJson));
        // Staff's existing general unmapped-member policy is unchanged. A top-level
        // ignored presence claim cannot specify the separate branchId wrapper.
        var staff = JsonSerializer.Deserialize<InternalStaffUpdateRequest>(StaffJson(",\"branchIdSpecified\":true"), WebJson)!;
        Assert.False(staff.BranchId.IsSpecified);
    }

    [Fact]
    public void Existing_constructor_shapes_distinguish_absent_and_explicit_null()
    {
        Assert.False(new InternalLocationWrite("Location").BranchId.IsSpecified);
        Assert.False(new InternalLocationWrite("Location", false).BranchId.IsSpecified);
        Assert.True(new InternalLocationWrite("Location", true, null).BranchId.IsSpecified);
        Assert.Equal(Branch, new InternalLocationWrite("Location", true, Branch).BranchId.Value);
        Assert.True(new InternalLocationWrite(Name: "Location", BranchId: null).BranchId.IsSpecified);
        Assert.False(new InternalStaffUpdateRequest("Staff", "Manager", true, Version).BranchId.IsSpecified);
        Assert.True(new InternalStaffUpdateRequest("Staff", "Manager", true, Version, null).BranchId.IsSpecified);
        Assert.Equal(Branch, new InternalStaffUpdateRequest("Staff", "Manager", true, Version, Branch).BranchId.Value);
    }

    [Fact]
    public async Task Typed_http_json_roundtrip_preserves_presence_for_both_update_dtos()
    {
        await AssertRoundTrip(new InternalLocationWrite("Location"), false, null, value => value.BranchId);
        await AssertRoundTrip(new InternalLocationWrite("Location", true, null), true, null, value => value.BranchId);
        await AssertRoundTrip(new InternalLocationWrite("Location", true, Branch), true, Branch, value => value.BranchId);
        await AssertRoundTrip(new InternalStaffUpdateRequest("Staff", "Manager", true, Version), false, null, value => value.BranchId);
        await AssertRoundTrip(new InternalStaffUpdateRequest("Staff", "Manager", true, Version, null), true, null, value => value.BranchId);
        await AssertRoundTrip(new InternalStaffUpdateRequest("Staff", "Manager", true, Version, Branch), true, Branch, value => value.BranchId);
    }

    [Fact]
    public async Task Location_fingerprint_keeps_request_presence_and_normalized_intent()
    {
        await using var db = InternalDirectoryModelTests.Database();
        var runner = new RecordingRunner();
        var service = new InternalDirectoryService(db, runner);
        var actor = Guid.NewGuid();
        var id = Guid.NewGuid();
        const string key = "branch-compat-key-0001";
        await service.SaveLocation(id, new("Location"), actor, key, default);
        var absent = runner.Fingerprint;
        Assert.NotNull(absent);
        // Golden structural shape from the local 4a9 pre-branch location request.
        // A legacy retry must retain the original actor/scope/key/fingerprint.
        Assert.Equal(InternalRules.Fingerprint(new { id = (Guid?)id,
            value = new { Name = "Location", Active = true } }), absent);
        await service.SaveLocation(id, new(" Location "), actor, key, default);
        Assert.Equal(absent, runner.Fingerprint);
        await service.SaveLocation(id, new("Location", true, null), actor, key, default);
        var clear = runner.Fingerprint;
        Assert.NotEqual(absent, clear);
        await service.SaveLocation(id, new("Location", true, Branch), actor, key, default);
        Assert.NotEqual(absent, runner.Fingerprint);
        Assert.NotEqual(clear, runner.Fingerprint);
        var assign = runner.Fingerprint;
        await service.SaveLocation(id, new(" Location ", true, Branch), actor, key, default);
        Assert.Equal(assign, runner.Fingerprint);
        Assert.Empty(db.ChangeTracker.Entries()); // This double never runs actions or opens SQL.
    }

    private static async Task AssertRoundTrip<T>(T request, bool specified, Guid? expected,
        Func<T, InternalBranchIdUpdate> branch)
    {
        using var content = JsonContent.Create(request, options: WebJson);
        var body = await content.ReadAsStringAsync();
        using var document = JsonDocument.Parse(body);
        Assert.Equal(specified, document.RootElement.TryGetProperty("branchId", out var token));
        if (specified && expected is null) Assert.Equal(JsonValueKind.Null, token.ValueKind);
        if (expected is { } id) Assert.Equal(id, token.GetGuid());
        var roundtrip = JsonSerializer.Deserialize<T>(body, WebJson)!;
        Assert.Equal(specified, branch(roundtrip).IsSpecified);
        Assert.Equal(expected, branch(roundtrip).Value);
    }

    // Captures the actual service fingerprint without SQL or a fake success.
    private sealed class RecordingRunner : IInternalCommandRunner
    {
        public string? Fingerprint { get; private set; }
        public Task<InternalResult<T>> Run<T>(Guid actorId, string scope, string key, string fingerprint,
            Func<CancellationToken, Task<InternalResult<T>>> action, CancellationToken ct)
        {
            Fingerprint = fingerprint;
            return Task.FromResult(InternalResult<T>.Fail("storage_unavailable"));
        }
    }
}
