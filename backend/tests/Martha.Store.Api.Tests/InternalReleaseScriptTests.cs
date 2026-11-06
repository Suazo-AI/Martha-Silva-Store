using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using Martha.Store.Api.Internal;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Xunit;

namespace Martha.Store.Api.Tests;

// C4: the checked-in idempotent release script is the artifact an operator reviews and applies.
// It must equal what EF generates for EVERY Internal migration, and applying it must upgrade
// both an empty database and one that only has the first migration, without touching existing rows.
public sealed class InternalReleaseScriptTests
{
    internal const string ScriptPath = "backend/src/Martha.Store.Api/Internal/Migrations/InitialInternalSavia.idempotent.sql";
    private const string Regenerate = "Regenerate with: dotnet-ef migrations script 0 --idempotent --context Martha.Store.Api.Internal.InternalDbContext " +
        "--project backend/src/Martha.Store.Api/Martha.Store.Api.csproj --startup-project backend/src/Martha.Store.Api/Martha.Store.Api.csproj " +
        "--configuration Release --no-build --output " + ScriptPath + " (see docs/savia-internal/MIGRATION-PLAN.md).";

    internal static string RepositoryFile(string relative)
    {
        for (var directory = new DirectoryInfo(AppContext.BaseDirectory); directory is not null; directory = directory.Parent)
            if (File.Exists(Path.Combine(directory.FullName, "backend", "Martha.Store.slnx")))
                return Path.Combine(directory.FullName, relative);
        throw new InvalidOperationException("Repository root (backend/Martha.Store.slnx) not found above the test output.");
    }

    // Byte-order mark, line endings and trailing blank lines are the only tolerated differences.
    internal static string Normalize(string script) => script.TrimStart('﻿').Replace("\r\n", "\n").TrimEnd('\r', '\n');

    internal static string CheckedInScript() => File.ReadAllText(RepositoryFile(ScriptPath));

    internal static string[] Batches(string script) => Regex.Split(Normalize(script), @"^GO[ \t]*$", RegexOptions.Multiline)
        .Select(batch => batch.Trim()).Where(batch => batch.Length != 0).ToArray();

    [Fact]
    public void Checked_in_idempotent_release_script_equals_ef_generation_for_every_internal_migration()
    {
        using var db = new InternalDbContextFactory().CreateDbContext([]);
        var generated = db.GetService<IMigrator>().GenerateScript(options: MigrationsSqlGenerationOptions.Idempotent);
        var checkedIn = CheckedInScript();
        foreach (var migration in db.Database.GetMigrations())
            Assert.True(checkedIn.Contains($"VALUES (N'{migration}', N'", StringComparison.Ordinal),
                $"Release script does not record migration {migration}. {Regenerate}");
        Assert.True(Normalize(generated) == Normalize(checkedIn), "Checked-in release script differs from EF generation. " + Regenerate);
        Assert.DoesNotMatch(new Regex(@"\b(?:CREATE|ALTER|DROP)\s+DATABASE|\bUSE\s+\[|CREATE\s+LOGIN|CREATE\s+USER", RegexOptions.IgnoreCase), checkedIn);
    }

    [InternalSecuritySqlFact]
    public async Task Release_script_upgrades_empty_and_first_migration_databases_and_preserves_synthetic_rows()
    {
        const string first = "20261025085402_InitialInternalSavia";
        string[] all = ["20261025085402_InitialInternalSavia", "20261027224500_InternalBranchScope", InternalStockExceptionTests.Migration];
        var script = CheckedInScript();
        var empty = NewDatabase(); var upgraded = NewDatabase(); var migrated = NewDatabase();
        var created = new List<string>();
        try
        {
            foreach (var name in new[] { empty, upgraded, migrated })
            { await PrivatePilotReleaseTests.Master($"CREATE DATABASE [{name}]"); created.Add(name); }

            // (a) Empty database: the release script alone creates the whole schema and history.
            await Apply(empty, script);
            Assert.Equal(all, await PrivatePilotReleaseTests.Rows(empty, "SELECT MigrationId FROM dbo.__EFMigrationsHistory ORDER BY MigrationId"));
            var emptySchema = await PrivatePilotReleaseTests.Inspect(empty);
            AssertModelOracle(emptySchema);
            Assert.Equal(new[] { "0|0" }, await PrivatePilotReleaseTests.Rows(empty,
                "SELECT (SELECT COUNT(*) FROM savia_internal.Staff),(SELECT COUNT(*) FROM savia_internal.Branches)"));

            // Independent path: EF's own migrator on a third database must yield the same schema facts.
            await using (var db = PrivatePilotReleaseTests.Context(migrated)) await db.GetService<IMigrator>().MigrateAsync();
            Assert.Equal(JsonSerializer.Serialize(await PrivatePilotReleaseTests.Inspect(migrated)), JsonSerializer.Serialize(emptySchema));

            // (b) Database that already had ONLY the first migration and synthetic business rows.
            await using (var db = PrivatePilotReleaseTests.Context(upgraded)) await db.GetService<IMigrator>().MigrateAsync(first);
            Assert.Equal(new[] { first }, await PrivatePilotReleaseTests.Rows(upgraded, "SELECT MigrationId FROM dbo.__EFMigrationsHistory"));
            await PrivatePilotReleaseTests.Execute(upgraded, FirstMigrationRows);
            var tablesBefore = await PrivatePilotReleaseTests.Rows(upgraded, "SELECT name FROM sys.tables WHERE schema_id=SCHEMA_ID('savia_internal') ORDER BY name");
            Assert.DoesNotContain("Branches", tablesBefore);
            var columnsBefore = await Columns(upgraded, tablesBefore);
            var before = await Snapshot(upgraded, columnsBefore);
            Assert.Equal(9, before.Count(table => table.Value.Length > 0));

            await Apply(upgraded, script);
            Assert.Equal(all, await PrivatePilotReleaseTests.Rows(upgraded, "SELECT MigrationId FROM dbo.__EFMigrationsHistory ORDER BY MigrationId"));
            var after = await Snapshot(upgraded, columnsBefore);
            Assert.Equal(JsonSerializer.Serialize(before), JsonSerializer.Serialize(after));
            // No inferred branch assignment or backfill: new scope columns stay NULL, new tables stay empty.
            Assert.Equal(new[] { "0|0|0|0|0|0" }, await PrivatePilotReleaseTests.Rows(upgraded, """
                SELECT (SELECT COUNT(*) FROM savia_internal.Branches),(SELECT COUNT(*) FROM savia_internal.BranchAssignmentAudit),
                       (SELECT COUNT(*) FROM savia_internal.Staff WHERE BranchId IS NOT NULL),(SELECT COUNT(*) FROM savia_internal.Locations WHERE BranchId IS NOT NULL),
                       (SELECT COUNT(*) FROM savia_internal.Operations WHERE LocationId IS NOT NULL),(SELECT COUNT(*) FROM savia_internal.Operations WHERE OriginalBranchId IS NOT NULL)
                """));
            var upgradedSchema = await PrivatePilotReleaseTests.Inspect(upgraded);
            Assert.Equal(JsonSerializer.Serialize(emptySchema), JsonSerializer.Serialize(upgradedSchema));

            // Re-applying the same script is a no-op for history, schema and rows.
            await Apply(upgraded, script);
            Assert.Equal(all, await PrivatePilotReleaseTests.Rows(upgraded, "SELECT MigrationId FROM dbo.__EFMigrationsHistory ORDER BY MigrationId"));
            Assert.Equal(JsonSerializer.Serialize(upgradedSchema), JsonSerializer.Serialize(await PrivatePilotReleaseTests.Inspect(upgraded)));
            Assert.Equal(JsonSerializer.Serialize(before), JsonSerializer.Serialize(await Snapshot(upgraded, columnsBefore)));
        }
        finally
        {
            foreach (var name in created)
                await PrivatePilotReleaseTests.Master($"IF DB_ID(N'{name}') IS NOT NULL BEGIN ALTER DATABASE [{name}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{name}]; END");
        }
    }

    private static string NewDatabase() => "SaviaInternalTest_Release_" + Guid.NewGuid().ToString("N");

    private static async Task Apply(string database, string script)
    {
        await using var connection = new SqlConnection(PrivatePilotReleaseTests.Connection(database));
        await connection.OpenAsync();
        foreach (var batch in Batches(script))
        {
            await using var command = connection.CreateCommand();
            command.CommandText = batch; command.CommandTimeout = 90;
            await command.ExecuteNonQueryAsync();
        }
    }

    // Name oracle derived from the EF model independently of the migrations (see backend/tests/fixtures).
    private static void AssertModelOracle(SortedDictionary<string, string[]> facts)
    {
        using var expected = JsonDocument.Parse(File.ReadAllText(RepositoryFile("backend/tests/fixtures/expected-invariants.model-derived.json")));
        foreach (var key in new[] { "history", "tables", "checks", "foreign_keys", "indexes", "primary_keys" })
            Assert.Equal(InternalStockExceptionTests.Expected(expected.RootElement.GetProperty(key).EnumerateArray().Select(x => x.GetString()), key).OrderBy(x => x, StringComparer.Ordinal).ToArray(),
                facts[key].OrderBy(x => x, StringComparer.Ordinal).ToArray());
        Assert.All(facts["constraint_state"], x => Assert.EndsWith("|False|False", x));
    }

    // Column sets of the tables as they existed before the upgrade.
    private static async Task<SortedDictionary<string, string[]>> Columns(string database, string[] tables)
    {
        var columns = new SortedDictionary<string, string[]>(StringComparer.Ordinal);
        foreach (var table in tables)
            columns[table] = await PrivatePilotReleaseTests.Rows(database,
                $"SELECT c.name FROM sys.columns c JOIN sys.tables t ON t.object_id=c.object_id WHERE t.schema_id=SCHEMA_ID('savia_internal') AND t.name=N'{table}' ORDER BY c.column_id");
        return columns;
    }

    // Every row of those tables, restricted to those columns, independent of EF.
    private static async Task<SortedDictionary<string, string[]>> Snapshot(string database, SortedDictionary<string, string[]> columns)
    {
        var result = new SortedDictionary<string, string[]>(StringComparer.Ordinal);
        await using var connection = new SqlConnection(PrivatePilotReleaseTests.Connection(database));
        await connection.OpenAsync();
        foreach (var (table, selected) in columns)
        {
            await using var command = connection.CreateCommand();
            command.CommandText = $"SELECT {string.Join(",", selected.Select(c => "[" + c + "]"))} FROM [savia_internal].[{table}]";
            await using var reader = await command.ExecuteReaderAsync();
            var rows = new List<string>();
            while (await reader.ReadAsync())
                rows.Add(string.Join("|", Enumerable.Range(0, reader.FieldCount).Select(i => reader.GetName(i) + "=" + Format(reader.GetValue(i)))));
            result[table] = rows.OrderBy(x => x, StringComparer.Ordinal).ToArray();
        }
        return result;
    }

    private static string Format(object value) => value switch
    {
        DBNull => "NULL",
        byte[] bytes => "0x" + Convert.ToHexString(bytes),
        DateTimeOffset at => at.ToString("O", CultureInfo.InvariantCulture),
        _ => Convert.ToString(value, CultureInfo.InvariantCulture) ?? ""
    };

    // Synthetic rows only, valid for the FIRST migration's schema (no branch columns exist yet).
    private const string FirstMigrationRows = """
        INSERT savia_internal.Items(Id,Sku,Name,UnitPriceMinor,Currency,Active) VALUES('a1000000-0000-0000-0000-000000000001','REL-SYN-01',N'Release synthetic item',1250,'USD',1);
        INSERT savia_internal.Locations(Id,Name,Active) VALUES('a2000000-0000-0000-0000-000000000002',N'Release synthetic location',1);
        INSERT savia_internal.Staff(Id,LoginName,NormalizedLoginName,DisplayName,PasswordHash,Role,Enabled,SecurityVersion,FailedSignIns,CreatedAt,UpdatedAt)
          VALUES('a3000000-0000-0000-0000-000000000003','release-synthetic','RELEASE-SYNTHETIC',N'Release fixture only','not-a-real-password-hash','Cashier',1,'a3000000-0000-0000-0000-0000000000ff',0,'2026-10-26T00:00:00+00:00','2026-10-26T00:00:00+00:00');
        INSERT savia_internal.Sessions(Id,StaffId,SecurityVersion,CreatedAt,ExpiresAt)
          VALUES('a4000000-0000-0000-0000-000000000004','a3000000-0000-0000-0000-000000000003','a3000000-0000-0000-0000-0000000000ff','2026-10-26T00:00:00+00:00','2026-10-26T08:00:00+00:00');
        INSERT savia_internal.StockBalances(ItemId,LocationId,OnHand,Reserved,UpdatedAt)
          VALUES('a1000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000002',15,0,'2026-10-26T01:00:00+00:00');
        INSERT savia_internal.Sales(Id,LocationId,CustomerId,ActorId,Currency,TotalMinor,State,CreatedAt)
          VALUES('a5000000-0000-0000-0000-000000000005','a2000000-0000-0000-0000-000000000002',NULL,'a3000000-0000-0000-0000-000000000003','USD',2500,'recorded','2026-10-26T01:00:00+00:00');
        INSERT savia_internal.SaleLines(Id,SaleId,ItemId,Sku,Name,Quantity,ReturnedQuantity,UnitPriceMinor,TotalMinor)
          VALUES('a6000000-0000-0000-0000-000000000006','a5000000-0000-0000-0000-000000000005','a1000000-0000-0000-0000-000000000001','REL-SYN-01',N'Release synthetic item',2,0,1250,2500);
        INSERT savia_internal.StockMovements(Id,ItemId,LocationId,ActorId,OperationId,Kind,OnHandDelta,ReservedDelta,OnHandAfter,ReservedAfter,CreatedAt)
          VALUES('a7000000-0000-0000-0000-000000000007','a1000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000002','a3000000-0000-0000-0000-000000000003','a5000000-0000-0000-0000-000000000005','sale',-2,0,15,0,'2026-10-26T01:00:00+00:00');
        INSERT savia_internal.Operations(Id,ActorId,Scope,[Key],Fingerprint,ResultJson,CreatedAt)
          VALUES('a8000000-0000-0000-0000-000000000008','a3000000-0000-0000-0000-000000000003','commerce.sale.record','release-synthetic-key-01',REPLICATE('A',64),N'{"value":{"saleId":"a5000000-0000-0000-0000-000000000005"},"error":null}','2026-10-26T01:00:00+00:00');
        """;
}
