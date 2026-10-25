using System.Data;
using Martha.Store.Api.Internal;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore.Migrations.Operations;
using Xunit;

namespace Martha.Store.Api.Tests;

// Source/model/SQL-generation checks only. No server is contacted or SQL executed.
public sealed class InternalMigrationTests
{
    private static InternalDbContext Database() => new InternalDbContextFactory().CreateDbContext([]);

    [Fact]
    public void Design_time_factory_has_only_dummy_connection_and_ignores_arguments()
    {
        using var db = new InternalDbContextFactory().CreateDbContext(
            ["--connection", "Server=not-a-target.invalid;Database=NotAuthorized"]);
        var connection = new SqlConnectionStringBuilder(db.Database.GetConnectionString());
        Assert.Equal("design-time.invalid", connection.DataSource);
        Assert.Equal("SaviaInternalTest_DesignTime", connection.InitialCatalog);
        Assert.True(connection.IntegratedSecurity);
        Assert.Empty(connection.Password);
        Assert.Empty(connection.UserID);
        Assert.False(connection.MultipleActiveResultSets);
        InternalDatabaseGuard.Validate(connection.ConnectionString);
        Assert.Equal(ConnectionState.Closed, db.Database.GetDbConnection().State);
    }

    [Fact]
    public void Internal_and_store_contexts_discover_disjoint_migrations_and_snapshots()
    {
        using var db = Database();
        using var store = new StoreDbContext(new DbContextOptionsBuilder<StoreDbContext>()
            .UseSqlServer("Server=design-time.invalid;Database=MarthaSynthetic_DesignOnly;Integrated Security=true").Options);
        var internalMigrations = db.GetService<IMigrationsAssembly>();
        var storeMigrations = store.GetService<IMigrationsAssembly>();
        Assert.NotEmpty(internalMigrations.Migrations);
        Assert.NotEmpty(storeMigrations.Migrations);
        Assert.Empty(internalMigrations.Migrations.Keys.Intersect(storeMigrations.Migrations.Keys));
        Assert.Equal("Martha.Store.Api.Internal.Migrations", internalMigrations.ModelSnapshot!.GetType().Namespace);
        Assert.Equal("Martha.Store.Api.Migrations", storeMigrations.ModelSnapshot!.GetType().Namespace);
        Assert.All(internalMigrations.Migrations.Values, migration =>
            Assert.Equal(typeof(InternalDbContext), migration.GetCustomAttributes(typeof(DbContextAttribute), false)
                .Cast<DbContextAttribute>().Single().ContextType));
        Assert.Equal(ConnectionState.Closed, db.Database.GetDbConnection().State);
        Assert.Equal(ConnectionState.Closed, store.Database.GetDbConnection().State);
    }

    [Fact]
    public void Internal_snapshot_matches_the_current_design_time_model_without_a_server()
    {
        using var db = Database();
        Assert.False(db.Database.HasPendingModelChanges());
        Assert.Equal(ConnectionState.Closed, db.Database.GetDbConnection().State);
    }

    [Fact]
    public void Initial_migration_creates_only_internal_tables_without_seed_or_custom_sql()
    {
        using var db = Database();
        var assembly = db.GetService<IMigrationsAssembly>();
        var migration = assembly.CreateMigration(assembly.Migrations.First().Value, db.Database.ProviderName!);
        var tables = migration.UpOperations.OfType<CreateTableOperation>().ToArray();
        var expected = db.GetService<IDesignTimeModel>().Model.GetRelationalModel().Tables
            .Select(table => (table.Schema, table.Name)).OrderBy(table => table.Name).ToArray();
        Assert.Equal(expected, tables.Select(table => (table.Schema, table.Name)).OrderBy(table => table.Name).ToArray());
        Assert.All(tables, table => Assert.Equal("savia_internal", table.Schema));
        Assert.All(migration.UpOperations, operation =>
            Assert.True(operation is EnsureSchemaOperation or CreateTableOperation or CreateIndexOperation,
                $"Unexpected initial migration operation: {operation.GetType().Name}"));
        Assert.All(tables.SelectMany(table => table.ForeignKeys), key =>
        {
            Assert.Equal("savia_internal", key.PrincipalSchema);
            Assert.Equal(ReferentialAction.Restrict, key.OnDelete);
        });
        Assert.Equal(ConnectionState.Closed, db.Database.GetDbConnection().State);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void Offline_script_targets_an_existing_database_and_not_synthetic_tables(bool idempotent)
    {
        using var db = Database();
        var options = idempotent ? MigrationsSqlGenerationOptions.Idempotent : MigrationsSqlGenerationOptions.Default;
        var script = db.GetService<IMigrator>().GenerateScript(options: options);
        Assert.Contains("CREATE TABLE [savia_internal].[Staff]", script);
        Assert.Contains("CREATE TABLE [savia_internal].[StockBalances]", script);
        Assert.Contains("CREATE TABLE [savia_internal].[PurchaseReceipts]", script);
        Assert.Contains("[__EFMigrationsHistory]", script);
        Assert.DoesNotContain("CREATE DATABASE", script, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("ALTER DATABASE", script, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("DROP DATABASE", script, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("USE [", script, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("MarthaSynthetic", script, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("[SaviaBalances]", script);
        Assert.DoesNotContain("[Orders]", script);
        Assert.DoesNotContain("INSERT INTO [savia_internal]", script, StringComparison.OrdinalIgnoreCase);
        Assert.Equal(ConnectionState.Closed, db.Database.GetDbConnection().State);
    }
}
