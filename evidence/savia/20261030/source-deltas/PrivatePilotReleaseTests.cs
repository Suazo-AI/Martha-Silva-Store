using System.Text.Json;
using System.Text.RegularExpressions;
using Martha.Store.Api.Internal;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Xunit;

namespace Martha.Store.Api.Tests;

// Worker-only release proof. No application startup, EnsureCreated, seed or Owner bootstrap.
public sealed class PrivatePilotReleaseTests
{
    private static string Evidence => Environment.GetEnvironmentVariable("SAVIA_PILOT_EVIDENCE")
        ?? throw new InvalidOperationException("Worker evidence path required");
    private static readonly string[] History = ["20261025085402_InitialInternalSavia", "20261027224500_InternalBranchScope"];
    private static string Connection(string database)
    {
        Assert.Matches("^SaviaInternalTest_Pilot_[a-f0-9]{32}$", database);
        var parsed = new SqlConnectionStringBuilder(Environment.GetEnvironmentVariable("MARTHA_INTERNAL_TEST_SQL_CONNECTION")) { InitialCatalog = database, Pooling = false };
        InternalDatabaseGuard.Validate(parsed.ConnectionString);
        return parsed.ConnectionString;
    }
    private static InternalDbContext Context(string database) => new(new DbContextOptionsBuilder<InternalDbContext>().UseSqlServer(Connection(database)).Options);
    private static async Task<string[]> Rows(string database, string sql)
    {
        await using var c = new SqlConnection(Connection(database)); await c.OpenAsync();
        await using var cmd = c.CreateCommand(); cmd.CommandText = sql; cmd.CommandTimeout = 90;
        await using var reader = await cmd.ExecuteReaderAsync(); var result = new List<string>();
        while (await reader.ReadAsync()) result.Add(string.Join("|", Enumerable.Range(0, reader.FieldCount).Select(i => reader.IsDBNull(i) ? "NULL" : Convert.ToString(reader.GetValue(i), System.Globalization.CultureInfo.InvariantCulture))));
        return result.ToArray();
    }
    private static async Task Execute(string database, string sql)
    {
        await using var c = new SqlConnection(Connection(database)); await c.OpenAsync();
        await using var cmd = c.CreateCommand(); cmd.CommandText = sql; cmd.CommandTimeout = 90; await cmd.ExecuteNonQueryAsync();
    }
    private static async Task Master(string sql)
    {
        var cs = new SqlConnectionStringBuilder(Environment.GetEnvironmentVariable("MARTHA_INTERNAL_TEST_SQL_CONNECTION")) { InitialCatalog = "master", Pooling = false };
        await using var c = new SqlConnection(cs.ConnectionString); await c.OpenAsync();
        await using var cmd = c.CreateCommand(); cmd.CommandText = sql; cmd.CommandTimeout = 90; await cmd.ExecuteNonQueryAsync();
    }
    private static string NewDatabase() => "SaviaInternalTest_Pilot_" + Guid.NewGuid().ToString("N");
    private static void Write(string name, object data) => File.WriteAllText(Path.Combine(Evidence, name), JsonSerializer.Serialize(data, new JsonSerializerOptions { WriteIndented = true }));
    private static async Task<SortedDictionary<string, string[]>> Inspect(string database)
    {
        var facts = new SortedDictionary<string, string[]>();
        facts["history"] = await Rows(database, "SELECT MigrationId FROM dbo.__EFMigrationsHistory ORDER BY MigrationId");
        facts["tables"] = await Rows(database, "SELECT name FROM sys.tables WHERE schema_id=SCHEMA_ID('savia_internal') ORDER BY name");
        facts["all_tables"] = await Rows(database, "SELECT SCHEMA_NAME(schema_id)+'.'+name FROM sys.tables ORDER BY 1");
        facts["checks"] = await Rows(database, "SELECT name FROM sys.check_constraints WHERE schema_id=SCHEMA_ID('savia_internal') ORDER BY name");
        facts["foreign_keys"] = await Rows(database, "SELECT name FROM sys.foreign_keys WHERE schema_id=SCHEMA_ID('savia_internal') ORDER BY name");
        facts["indexes"] = await Rows(database, "SELECT i.name FROM sys.indexes i JOIN sys.tables t ON t.object_id=i.object_id WHERE t.schema_id=SCHEMA_ID('savia_internal') AND i.is_primary_key=0 AND i.name IS NOT NULL ORDER BY i.name");
        facts["primary_keys"] = await Rows(database, "SELECT name FROM sys.key_constraints WHERE schema_id=SCHEMA_ID('savia_internal') AND type='PK' ORDER BY name");
        facts["constraint_state"] = await Rows(database, "SELECT name,is_disabled,is_not_trusted FROM sys.check_constraints WHERE schema_id=SCHEMA_ID('savia_internal') UNION ALL SELECT name,is_disabled,is_not_trusted FROM sys.foreign_keys WHERE schema_id=SCHEMA_ID('savia_internal') ORDER BY name");
        facts["foreign_key_delete"] = await Rows(database, "SELECT name,delete_referential_action FROM sys.foreign_keys WHERE schema_id=SCHEMA_ID('savia_internal') ORDER BY name");
        facts["columns"] = await Rows(database, "SELECT t.name,c.name,TYPE_NAME(c.user_type_id),c.max_length,c.is_nullable,c.is_identity FROM sys.columns c JOIN sys.tables t ON t.object_id=c.object_id WHERE t.schema_id=SCHEMA_ID('savia_internal') ORDER BY t.name,c.column_id");
        facts["check_definitions"] = await Rows(database, "SELECT name,definition FROM sys.check_constraints WHERE schema_id=SCHEMA_ID('savia_internal') ORDER BY name");
        facts["index_columns"] = await Rows(database, "SELECT t.name,i.name,i.is_unique,c.name,ic.key_ordinal,ic.is_descending_key FROM sys.indexes i JOIN sys.tables t ON t.object_id=i.object_id JOIN sys.index_columns ic ON i.object_id=ic.object_id AND i.index_id=ic.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE t.schema_id=SCHEMA_ID('savia_internal') ORDER BY t.name,i.name,ic.index_column_id");
        return facts;
    }
    private static void AssertSchema(SortedDictionary<string,string[]> facts)
    {
        using var expected = JsonDocument.Parse(File.ReadAllText(Path.Combine(Evidence,"expected-invariants.json")));
        foreach (var key in new[] {"history","tables","checks","foreign_keys","indexes","primary_keys"})
            Assert.Equal(expected.RootElement.GetProperty(key).EnumerateArray().Select(x=>x.GetString()).OrderBy(x=>x,StringComparer.Ordinal).ToArray(),facts[key].OrderBy(x=>x,StringComparer.Ordinal).ToArray());
        Assert.Equal(20,facts["all_tables"].Length);
        Assert.Contains("dbo.__EFMigrationsHistory",facts["all_tables"]);
        Assert.All(facts["all_tables"],x=>Assert.True(x=="dbo.__EFMigrationsHistory" || x.StartsWith("savia_internal.")));
        Assert.All(facts["constraint_state"],x=>Assert.EndsWith("|False|False",x));
        Assert.All(facts["foreign_key_delete"],x=>Assert.EndsWith("|0",x));
    }
    private static async Task<string[]> Business(string database)
    {
        // Independent selects preserve each business column's actual collation; no UNION coercion.
        var rows = new List<string>();
        foreach (var query in new[] {
            "SELECT 'item',Sku,Name,CONVERT(varchar(30),UnitPriceMinor),Currency FROM savia_internal.Items",
            "SELECT 'stock',CONVERT(varchar(36),ItemId),CONVERT(varchar(36),LocationId),CONVERT(varchar(30),OnHand),CONVERT(varchar(30),Reserved) FROM savia_internal.StockBalances",
            "SELECT 'staff',LoginName,DisplayName,Role,CONVERT(varchar(1),Enabled) FROM savia_internal.Staff",
            "SELECT 'branch',Name,CONVERT(varchar(1),Active),'','' FROM savia_internal.Branches"})
            rows.AddRange(await Rows(database,query));
        return rows.OrderBy(x=>x,StringComparer.Ordinal).ToArray();
    }
    [Fact]
    public void Offline_current_release_scripts_are_context_isolated_without_model_drift()
    {
        using var db=new InternalDbContextFactory().CreateDbContext([]);
        Assert.False(db.Database.HasPendingModelChanges());
        Assert.Equal(History,db.Database.GetMigrations());
        using var store = new StoreDbContext(new DbContextOptionsBuilder<StoreDbContext>().UseSqlServer("Server=design-time.invalid;Database=MarthaSynthetic_DesignOnly;Integrated Security=true").Options);
        Assert.Empty(store.Database.GetMigrations().Intersect(History));
        var migrator=db.GetService<IMigrator>();
        foreach(var idempotent in new[]{false,true})
        {
            var sql=migrator.GenerateScript(options:idempotent?MigrationsSqlGenerationOptions.Idempotent:MigrationsSqlGenerationOptions.Default);
            Assert.Contains("CREATE TABLE [savia_internal].[Branches]",sql);
            Assert.Contains("CREATE TABLE [savia_internal].[BranchAssignmentAudit]",sql);
            Assert.DoesNotMatch(new Regex(@"\b(?:CREATE|ALTER|DROP)\s+DATABASE|\bUSE\s+\[|CREATE\s+LOGIN|CREATE\s+USER",RegexOptions.IgnoreCase),sql);
            File.WriteAllText(Path.Combine(Evidence,idempotent?"current-release-idempotent.sql":"current-release.sql"),sql);
        }
        File.WriteAllText(Path.Combine(Evidence,"current-release-down.sql"),migrator.GenerateScript(History[^1],Migration.InitialDatabase));
    }
    [InternalSecuritySqlFact]
    public async Task Real_migration_reapply_throwaway_down_up_and_actual_backup_restore()
    {
        var source=NewDatabase(); var restored=NewDatabase(); var down=NewDatabase();
        await Master($"CREATE DATABASE [{source}]; CREATE DATABASE [{down}]");
        await using(var db=Context(source)) await db.GetService<IMigrator>().MigrateAsync();
        var initial=await Inspect(source); Write("schema-first-"+source+".json",initial); AssertSchema(initial);
        Assert.Equal(new[]{"0"},await Rows(source,"SELECT CONVERT(varchar(10),COUNT(*)) FROM savia_internal.Staff"));
        await using(var db=Context(source)) await db.GetService<IMigrator>().MigrateAsync();
        Assert.Equal(JsonSerializer.Serialize(initial),JsonSerializer.Serialize(await Inspect(source)));
        await using(var db=Context(down))
        {
            await db.GetService<IMigrator>().MigrateAsync(); AssertSchema(await Inspect(down));
            await Execute(down,"INSERT savia_internal.Branches(Id,Name,Active) VALUES(NEWID(),'Throwaway destroyed by Down',1)");
            await db.GetService<IMigrator>().MigrateAsync(Migration.InitialDatabase);
            Assert.Empty(await Rows(down,"SELECT name FROM sys.tables WHERE schema_id=SCHEMA_ID('savia_internal')"));
            Assert.Empty(await Rows(down,"SELECT MigrationId FROM dbo.__EFMigrationsHistory"));
            Write("down-"+down+".json",new{database=down,history_rows=0,internal_tables=0,fixture_destroyed=true,recovery=false});
            await db.GetService<IMigrator>().MigrateAsync(); AssertSchema(await Inspect(down));
            Assert.Equal(new[]{"0"},await Rows(down,"SELECT CONVERT(varchar(10),COUNT(*)) FROM savia_internal.Branches"));
        }
        await Execute(source,"""
          INSERT savia_internal.Branches(Id,Name,Active) VALUES('11111111-1111-1111-1111-111111111111',N'QA pilot branch',1);
          INSERT savia_internal.Items(Id,Sku,Name,UnitPriceMinor,Currency,Active) VALUES('22222222-2222-2222-2222-222222222222','QA-PILOT-01',N'QA pilot item',1250,'USD',1);
          INSERT savia_internal.Locations(Id,Name,Active,BranchId) VALUES('33333333-3333-3333-3333-333333333333',N'QA pilot location',1,'11111111-1111-1111-1111-111111111111');
          INSERT savia_internal.StockBalances(ItemId,LocationId,OnHand,Reserved,UpdatedAt) VALUES('22222222-2222-2222-2222-222222222222','33333333-3333-3333-3333-333333333333',17,3,'2026-10-28T00:00:00+00:00');
          INSERT savia_internal.Staff(Id,LoginName,NormalizedLoginName,DisplayName,PasswordHash,Role,Enabled,SecurityVersion,FailedSignIns,CreatedAt,UpdatedAt,BranchId) VALUES('44444444-4444-4444-4444-444444444444','qa-pilot-disabled','QA-PILOT-DISABLED',N'QA fixture only','not-a-real-password-hash','Inventory',0,NEWID(),0,'2026-10-28T00:00:00+00:00','2026-10-28T00:00:00+00:00','11111111-1111-1111-1111-111111111111');
          """);
        var before=await Business(source); Assert.Equal(4,before.Length);
        Assert.Contains("item|QA-PILOT-01|QA pilot item|1250|USD",before);
        Assert.Contains("stock|22222222-2222-2222-2222-222222222222|33333333-3333-3333-3333-333333333333|17|3",before);
        var backup="/var/opt/mssql/data/"+source+".bak";
        await Master($"BACKUP DATABASE [{source}] TO DISK=N'{backup}' WITH INIT,CHECKSUM; RESTORE VERIFYONLY FROM DISK=N'{backup}' WITH CHECKSUM;");
        // Logical names equal the generated CREATE DATABASE name (SQL Server default); restore uses independent files.
        await Master($"RESTORE DATABASE [{restored}] FROM DISK=N'{backup}' WITH MOVE N'{source}' TO N'/var/opt/mssql/data/{restored}.mdf', MOVE N'{source}_log' TO N'/var/opt/mssql/data/{restored}_log.ldf', CHECKSUM;");
        Assert.Equal(before,await Business(restored)); var restoredSchema=await Inspect(restored); AssertSchema(restoredSchema);
        Assert.Equal(JsonSerializer.Serialize(initial),JsonSerializer.Serialize(restoredSchema));
        await AssertRejects(restored);
        Write("release-"+source+".json",new{source,restored,throwaway_down=down,backup,checks=new{real_migrator_up=true,reapply_unchanged=true,down_destroyed_fixture=true,throwaway_up_again=true,backup_checksum=true,restore_verifyonly=true,actual_restore=true,independent_business_expected=true,restored_business_equal=true,restored_schema_equal=true,rejections=true},business=before,schema=initial});
    }
    private static async Task AssertRejects(string database)
    {
        var badCurrency=await Assert.ThrowsAsync<SqlException>(()=>Execute(database,"UPDATE savia_internal.Items SET Currency='XXX' WHERE Sku='QA-PILOT-01'")); Assert.Equal(547,badCurrency.Number);
        var badStock=await Assert.ThrowsAsync<SqlException>(()=>Execute(database,"UPDATE savia_internal.StockBalances SET Reserved=18")); Assert.Equal(547,badStock.Number);
        var badFk=await Assert.ThrowsAsync<SqlException>(()=>Execute(database,"UPDATE savia_internal.Staff SET BranchId='99999999-9999-9999-9999-999999999999'")); Assert.Equal(547,badFk.Number);
        var badUnique=await Assert.ThrowsAsync<SqlException>(()=>Execute(database,"INSERT savia_internal.Items(Id,Sku,Name,UnitPriceMinor,Currency,Active) VALUES(NEWID(),'QA-PILOT-01','Duplicate',100,'USD',1)")); Assert.Contains(badUnique.Number,new[]{2601,2627});
        Assert.Contains("item|QA-PILOT-01|QA pilot item|1250|USD",await Business(database));
    }
    [InternalSecuritySqlFact]
    public async Task Frozen_fixture_survives_controlled_owned_container_stop_start()
    {
        var database=Environment.GetEnvironmentVariable("SAVIA_PILOT_PERSIST_DATABASE") ?? throw new InvalidOperationException("Restart proof database required");
        AssertSchema(await Inspect(database)); var business=await Business(database);
        Assert.Equal(4,business.Length);
        Assert.Contains("item|QA-PILOT-01|QA pilot item|1250|USD",business);
        Assert.Contains("stock|22222222-2222-2222-2222-222222222222|33333333-3333-3333-3333-333333333333|17|3",business);
        Assert.Contains("staff|qa-pilot-disabled|QA fixture only|Inventory|0",business);
        await AssertRejects(database);
        Write("restart-persistence.json",new{database,business,checks=new{history=true,schema=true,expected_values=true,constraint_rejections=true}});
    }
}
