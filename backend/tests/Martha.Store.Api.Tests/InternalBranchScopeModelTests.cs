using System.Data;
using Martha.Store.Api.Internal;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Xunit;

namespace Martha.Store.Api.Tests;

public sealed class InternalBranchScopeModelTests
{
    [Fact]
    public void Branch_associations_are_nullable_restricted_and_not_seeded_or_inferred()
    {
        using var db = new InternalDbContext(new DbContextOptionsBuilder<InternalDbContext>()
            .UseSqlServer("Server=127.0.0.1,1;Database=SaviaInternalTest_BranchModel;Integrated Security=true;Connect Timeout=1").Options);
        var model = db.GetService<IDesignTimeModel>().Model;
        foreach (var type in new[] { typeof(InternalStaff), typeof(InternalLocation) })
        {
            var entity = model.FindEntityType(type)!;
            Assert.True(entity.FindProperty("BranchId")!.IsNullable);
            var fk = Assert.Single(entity.GetForeignKeys(), x => x.PrincipalEntityType.ClrType == typeof(InternalBranch));
            Assert.Equal(DeleteBehavior.Restrict, fk.DeleteBehavior);
            Assert.Equal("BranchId", Assert.Single(fk.Properties).Name);
        }
        var operation = model.FindEntityType(typeof(InternalOperation))!;
        Assert.True(operation.FindProperty("OriginalBranchId")!.IsNullable);
        Assert.True(operation.FindProperty("LocationId")!.IsNullable);
        Assert.Empty(model.FindEntityType(typeof(InternalBranch))!.GetSeedData());
        Assert.Equal(ConnectionState.Closed, db.Database.GetDbConnection().State);
    }

    [Fact]
    public async Task Legacy_runner_cannot_silently_execute_scoped_action_without_authorization()
    {
        IInternalCommandRunner runner = new LegacyRunner();
        var called = false;
        var result = await runner.RunScoped(Guid.NewGuid(), "commerce.sale.record", "bs-default-runner01", new string('A', 64),
            new InternalCommandResource("location", Guid.NewGuid()), _ => { called = true; return Task.FromResult(InternalResult<int>.Ok(1)); }, default);
        Assert.False(called);
        Assert.False(result.Success);
        Assert.Equal("storage_unavailable", result.Error);
    }

    private sealed class LegacyRunner : IInternalCommandRunner
    {
        public Task<InternalResult<T>> Run<T>(Guid actorId, string scope, string key, string fingerprint,
            Func<CancellationToken, Task<InternalResult<T>>> action, CancellationToken ct) => action(ct);
    }
}
