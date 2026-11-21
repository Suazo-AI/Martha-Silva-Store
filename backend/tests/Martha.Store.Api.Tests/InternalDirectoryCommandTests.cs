using Martha.Store.Api.Internal;
using Xunit;

namespace Martha.Store.Api.Tests;

public sealed class InternalDirectoryCommandTests
{
    [Fact]
    public async Task Invalid_inputs_never_enter_runner_or_open_sql()
    {
        await using var db = InternalDirectoryModelTests.Database();
        var runner = new RecordingRunner();
        var service = new InternalDirectoryService(db, runner);
        var actor = Guid.NewGuid();
        Assert.False((await service.SaveItem(null, new("SKU", "Item", -1, "USD"), actor, "valid-key-123456789", default)).Success);
        Assert.False((await service.SaveLocation(null, new(""), actor, "valid-key-123456789", default)).Success);
        Assert.False((await service.SaveParty(null, new("staff", "Person"), actor, "valid-key-123456789", default)).Success);
        Assert.False((await service.SaveLocation(null, new("Location"), Guid.Empty, "valid-key-123456789", default)).Success);
        Assert.False((await service.SaveLocation(Guid.Empty, new("Location"), actor, "valid-key-123456789", default)).Success);
        Assert.False((await service.DeactivateItem(Guid.NewGuid(), actor, "short", default)).Success);
        Assert.Equal(0, runner.Calls);
        Assert.Empty(db.ChangeTracker.Entries());
    }

    [Fact]
    public async Task Update_resource_id_and_payload_are_part_of_replay_fingerprint()
    {
        await using var db = InternalDirectoryModelTests.Database();
        var runner = new RecordingRunner();
        var service = new InternalDirectoryService(db, runner);
        var actor = Guid.NewGuid();
        var id = Guid.NewGuid();
        var body = new InternalItemWrite("SKU", "Item", 100, "USD");
        await service.SaveItem(id, body, actor, "valid-key-123456789", default);
        var first = runner.Fingerprint;
        Assert.Equal(actor, runner.Actor);
        Assert.Equal("directory.items.update", runner.Scope);
        await service.SaveItem(Guid.NewGuid(), body, actor, "valid-key-123456789", default);
        Assert.NotEqual(first, runner.Fingerprint);
        await service.SaveItem(id, body with { UnitPriceMinor = 101 }, actor, "valid-key-123456789", default);
        Assert.NotEqual(first, runner.Fingerprint);
        await service.SaveItem(id, body with { Sku = " sku ", Currency = "usd" }, actor, "valid-key-123456789", default);
        Assert.Equal(first, runner.Fingerprint);
        Assert.Empty(db.ChangeTracker.Entries());
    }

    [Theory]
    [InlineData("items")] [InlineData("locations")] [InlineData("parties")]
    public async Task Deactivation_uses_runner_and_fingerprints_the_resource(string entity)
    {
        await using var db = InternalDirectoryModelTests.Database();
        var runner = new RecordingRunner();
        var service = new InternalDirectoryService(db, runner);
        var actor = Guid.NewGuid();
        var id = Guid.NewGuid();
        switch (entity)
        {
            case "items": await service.DeactivateItem(id, actor, "valid-key-123456789", default); break;
            case "locations": await service.DeactivateLocation(id, actor, "valid-key-123456789", default); break;
            default: await service.DeactivateParty(id, actor, "valid-key-123456789", default); break;
        }
        Assert.Equal($"directory.{entity}.deactivate", runner.Scope);
        Assert.Equal(InternalRules.Fingerprint(new { id }), runner.Fingerprint);
        Assert.Equal(actor, runner.Actor);
        Assert.Equal(1, runner.Calls);
    }

    // A recording test double only: it NEVER executes an action or pretends to persist.
    // Successful CRUD/replay/rollback remain gated on real SQL integration tests.
    internal sealed class RecordingRunner : IInternalCommandRunner
    {
        public string Error { get; init; } = "storage_unavailable";
        public int Calls { get; private set; }
        public Guid Actor { get; private set; }
        public string? Scope { get; private set; }
        public string? Fingerprint { get; private set; }
        public Task<InternalResult<T>> Run<T>(Guid actorId, string scope, string key, string fingerprint,
            Func<CancellationToken, Task<InternalResult<T>>> action, CancellationToken ct)
        {
            Calls++;
            Actor = actorId;
            Scope = scope;
            Fingerprint = fingerprint;
            return Task.FromResult(InternalResult<T>.Fail(Error));
        }
    }
}
