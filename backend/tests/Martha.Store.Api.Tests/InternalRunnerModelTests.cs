using System.Data;
using Martha.Store.Api;
using Martha.Store.Api.Internal;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Martha.Store.Api.Tests;

// Model/configuration and tracked-write checks only: no connection is opened here.
public sealed class InternalRunnerModelTests
{
    [Fact]
    public void Replay_identity_is_unique_per_actor_scope_and_exact_binary_key()
    {
        using var db = Database();
        var operation = db.GetService<IDesignTimeModel>().Model.FindEntityType(typeof(InternalOperation))!;
        Assert.Equal("savia_internal", operation.GetSchema());
        Assert.Equal("Operations", operation.GetTableName());
        Assert.Equal(nameof(InternalOperation.Id), Assert.Single(operation.FindPrimaryKey()!.Properties).Name);
        var unique = Assert.Single(operation.GetIndexes(), index => index.IsUnique);
        Assert.Equal(new[] { "ActorId", "Scope", "Key" }, unique.Properties.Select(property => property.Name));
        foreach (var (name, length) in new[] { ("Scope", 80), ("Key", 128), ("Fingerprint", 64) })
        {
            var property = operation.FindProperty(name)!;
            Assert.Equal("Latin1_General_100_BIN2", property.GetCollation());
            Assert.Equal(length, property.GetMaxLength());
            Assert.Equal(false, property.IsUnicode());
            Assert.False(property.IsNullable);
        }
        Assert.False(operation.FindProperty(nameof(InternalOperation.ResultJson))!.IsNullable);
        var actorForeignKey = Assert.Single(operation.GetForeignKeys());
        Assert.Equal(typeof(InternalStaff), actorForeignKey.PrincipalEntityType.ClrType);
        Assert.Equal("ActorId", Assert.Single(actorForeignKey.Properties).Name);
        Assert.Equal(DeleteBehavior.Restrict, actorForeignKey.DeleteBehavior);
        Assert.Empty(operation.GetSeedData());
        Assert.Empty(operation.GetDeclaredQueryFilters());
    }

    [Theory]
    [InlineData(false, false)]
    [InlineData(false, true)]
    [InlineData(true, false)]
    [InlineData(true, true)]
    public async Task Replay_records_refuse_tracked_update_and_delete_on_both_save_overloads(bool delete, bool acceptAllChanges)
    {
        await using var db = Database();
        var operation = new InternalOperation { Id = Guid.NewGuid(), ActorId = Guid.NewGuid(),
            Scope = "directory.items.create", Key = "immutable-key-0001", Fingerprint = new string('A', 64), ResultJson = "{}" };
        db.Attach(operation);
        db.Entry(operation).State = delete ? EntityState.Deleted : EntityState.Modified;
        var sync = Assert.Throws<InvalidOperationException>(() => db.SaveChanges(acceptAllChanges));
        var asyncError = await Assert.ThrowsAsync<InvalidOperationException>(() => db.SaveChangesAsync(acceptAllChanges));
        Assert.Equal("Internal operation and inventory audit records are append-only.", sync.Message);
        Assert.Equal(sync.Message, asyncError.Message);
        Assert.Equal(ConnectionState.Closed, db.Database.GetDbConnection().State);
    }

    [Theory]
    [InlineData("")]
    [InlineData("Database=SaviaInternalTest_Valid;Unsupported=true")]
    [InlineData("Database=SaviaInternalTest_")]
    [InlineData("Database=SaviaInternalTest_safe;MultipleActiveResultSets=true")]
    [InlineData("Database=saviainternaltest_lower")]
    [InlineData("Database=SaviaInternal_Production")]
    [InlineData("Database=MarthaSynthetic_Test_other")]
    [InlineData("Database=master")]
    public void Database_guard_rejects_wrong_catalog_or_MARS_without_connecting(string connection) =>
        Assert.Throws<StorageUnavailableException>(() => InternalDatabaseGuard.Validate(connection));

    [Theory]
    [InlineData("SaviaInternalTest_ends\n")]
    [InlineData("SaviaInternalTest_ends ")]
    [InlineData(" SaviaInternalTest_starts")]
    [InlineData("SaviaInternalTest_é")]
    [InlineData("SaviaInternalTest_a-b")]
    public void Database_guard_rejects_noncanonical_catalog_even_when_quoted(string catalog)
    {
        // Explicit quotes preserve whitespace; the builder may otherwise normalize it away.
        var connection = $"Server=127.0.0.1,1;Initial Catalog=\"{catalog}\";Integrated Security=true";
        Assert.Equal(catalog, new SqlConnectionStringBuilder(connection).InitialCatalog);
        Assert.Throws<StorageUnavailableException>(() => InternalDatabaseGuard.Validate(connection));
    }

    [Theory]
    [InlineData(1)]
    [InlineData(64)]
    public void Database_guard_accepts_only_documented_catalog_boundaries_without_claiming_server_authority(int length) =>
        InternalDatabaseGuard.Validate("Server=127.0.0.1,1;Database=SaviaInternalTest_" + new string('a', length) + ";Integrated Security=true");

    [Fact]
    public void Database_guard_rejects_overlength_catalog() => Assert.Throws<StorageUnavailableException>(() =>
        InternalDatabaseGuard.Validate("Database=SaviaInternalTest_" + new string('a', 65)));

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData(" ")]
    [InlineData("Database=master")]
    [InlineData("Database=SaviaInternalTest_config;MultipleActiveResultSets=true")]
    public void Hosting_resolves_no_internal_context_from_missing_or_unguarded_configuration(string? connection)
    {
        var services = new ServiceCollection();
        services.AddPrivateSavia(Configuration(connection));
        using var provider = services.BuildServiceProvider();
        using var scope = provider.CreateScope();
        Assert.Throws<StorageUnavailableException>(() => scope.ServiceProvider.GetRequiredService<InternalDbContext>());
    }

    [Fact]
    public void Hosting_registers_real_scoped_runner_and_SQL_context_without_opening_connection()
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddPrivateSavia(Configuration("Server=127.0.0.1,1;Database=SaviaInternalTest_config;Integrated Security=true;Connect Timeout=1"));
        var registration = Assert.Single(services, service => service.ServiceType == typeof(IInternalCommandRunner));
        Assert.Equal(ServiceLifetime.Scoped, registration.Lifetime);
        Assert.Equal(typeof(InternalCommandRunner), registration.ImplementationType);
        using var provider = services.BuildServiceProvider();
        using var scope = provider.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<InternalDbContext>();
        Assert.True(db.Database.IsSqlServer());
        Assert.Equal(30, db.Database.GetCommandTimeout());
        Assert.Equal(ConnectionState.Closed, db.Database.GetDbConnection().State);
        Assert.IsType<InternalCommandRunner>(scope.ServiceProvider.GetRequiredService<IInternalCommandRunner>());
    }

    private static IConfiguration Configuration(string? connection) => new ConfigurationBuilder().AddInMemoryCollection(
        new Dictionary<string, string?> { ["ConnectionStrings:InternalSavia"] = connection }).Build();
    private static InternalDbContext Database() => new(new DbContextOptionsBuilder<InternalDbContext>()
        .UseSqlServer("Server=127.0.0.1,1;Database=SaviaInternalTest_RunnerMetadata;Integrated Security=true;Connect Timeout=1").Options);
}
