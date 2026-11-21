using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Martha.Store.Api.Tests;

// Private baseline contains hashes only. Manual approved orchestration supplies receipts; this is not a runner.
internal static class PilotRecoveryProof
{
    internal static readonly string[] Tables = ["BranchAssignmentAudit", "Branches", "CashCloses", "CashEntries", "CashTills", "Items", "Locations", "Operations", "Parties", "PurchaseOrderLines", "PurchaseOrders", "PurchaseReceiptLines", "PurchaseReceipts", "SaleLines", "SaleReversalLines", "SaleReversals", "Sales", "Sessions", "Staff", "StockAdjustments", "StockBalances", "StockExceptionReviews", "StockMovements"];
    internal static readonly string[] Selected = [
        "InternalBranchScopeSqlTests.BS21_25_Operations_http_checks_persisted_scope_and_actor_before_returning_result",
        "InternalBranchScopeSqlTests.BS28_Cashier_cannot_read_purchase_costs_through_any_supply_get",
        "InternalReleaseScriptTests.Release_script_upgrades_empty_and_first_migration_databases_and_preserves_synthetic_rows",
        "PrivatePilotReleaseTests.Real_migration_reapply_throwaway_down_up_and_actual_backup_restore",
        "InternalCashSqlTests.Cash_reads_follow_persisted_money_and_preserve_history_without_configuration",
        "InternalAcceptanceHttpSqlTests.N8_missing_wrong_or_stale_csrf_is_rejected_without_writes_and_a_valid_pair_still_works",
        "PrivatePilotReleaseTests.Frozen_fixture_survives_controlled_owned_container_stop_start"];
    internal sealed record Baseline(string Nonce, string Candidate, string Source, string Restored, string Identities, string Snapshot, Ownership Resources, DateTimeOffset SqlStart)
    {
        public string Hash => Digest(JsonSerializer.Serialize(new[] { Nonce, Candidate, Source, Restored, Identities, Snapshot, JsonSerializer.Serialize(Resources), SqlStart.ToString("O",CultureInfo.InvariantCulture) }));
    }
    internal sealed record Ownership(string Nonce, string Candidate, string ContainerId, string NetworkId, string VolumeId, bool CreationAcknowledged);
    internal sealed record SqlResult(string Name, string Candidate, string Outcome);
    internal sealed record Receipt(string Nonce, string Candidate, string BaselineHash, string Source, string Restored,
        string ContainerId, string NetworkId, string VolumeId, bool CreationAcknowledged,
        string BackupPath, string BackupSetId, string BackupCatalog, bool BackupChecksum, bool VerifyOnly, bool RestoreCompleted,
        string DataFile, string LogFile, string RestartContainerId, string[] States,
        DateTimeOffset BeforeSqlStart, DateTimeOffset AfterSqlStart, bool FreshRead,
        bool Reseeded, bool Migrated, bool Replaced, SqlResult[] Results);
    internal static string Digest(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)));
    // JSON arrays frame every cell; tags distinguish null, strings, numbers, binary and round-trip timestamps.
    internal static string Cell(object value) => value switch {
        DBNull => JsonSerializer.Serialize(new[] { "null" }),
        byte[] x => JsonSerializer.Serialize(new[] { "binary", Convert.ToHexString(x) }),
        DateTimeOffset x => JsonSerializer.Serialize(new[] { "datetimeoffset", x.ToString("O", CultureInfo.InvariantCulture) }),
        DateTime x => JsonSerializer.Serialize(new[] { "datetime", x.ToString("O", CultureInfo.InvariantCulture) }),
        TimeSpan x => JsonSerializer.Serialize(new[] { "time", x.ToString("c", CultureInfo.InvariantCulture) }),
        double x => JsonSerializer.Serialize(new[] { "double", BitConverter.DoubleToInt64Bits(x).ToString(CultureInfo.InvariantCulture) }),
        float x => JsonSerializer.Serialize(new[] { "float", BitConverter.SingleToInt32Bits(x).ToString(CultureInfo.InvariantCulture) }),
        // Preserve every UTF-16 code unit, including unpaired surrogates stored by SQL nvarchar.
        string x => JsonSerializer.Serialize(new[] { "string-utf16le", Convert.ToHexString(x.SelectMany(c=>new[]{(byte)c,(byte)(c>>8)}).ToArray()) }),
        Guid or bool or byte or short or int or long or decimal => JsonSerializer.Serialize(new[] { value.GetType().FullName!, Convert.ToString(value, CultureInfo.InvariantCulture)! }),
        _ => throw new InvalidOperationException("Unsupported lossless SQL cell type")
    };
    internal static async Task<string[]> HashRows(string database, string sql)
    {
        await using var c = new SqlConnection(PrivatePilotReleaseTests.Connection(database)); await c.OpenAsync();
        await using var cmd = c.CreateCommand(); cmd.CommandText = sql; cmd.CommandTimeout = 90;
        await using var reader = await cmd.ExecuteReaderAsync(); var hashes = new List<string>();
        while (await reader.ReadAsync())
            hashes.Add(Digest(JsonSerializer.Serialize(Enumerable.Range(0, reader.FieldCount)
                .Select(i => new[] { reader.GetName(i), reader.GetDataTypeName(i), Cell(reader.GetValue(i)) }).ToArray())));
        // Keep duplicates. Order is irrelevant, multiplicity and every column are not.
        return hashes.OrderBy(x => x, StringComparer.Ordinal).ToArray();
    }
    internal static async Task<DateTimeOffset> SqlStart(string database)
    {
        await using var c=new SqlConnection(PrivatePilotReleaseTests.Connection(database)); await c.OpenAsync();
        await using var cmd=c.CreateCommand(); cmd.CommandTimeout=90;
        cmd.CommandText="SELECT TODATETIMEOFFSET(sqlserver_start_time,DATEPART(TZOFFSET,SYSDATETIMEOFFSET())) FROM sys.dm_os_sys_info";
        return (DateTimeOffset)(await cmd.ExecuteScalarAsync())!;
    }
    internal static async Task<Receipt> RestoredReceipt(Baseline b)
    {
        // Read the actual backup-set identity and checksum, not a Boolean inferred from a test name.
        var backup="/var/opt/mssql/data/"+b.Source+".bak";
        var sets=await PrivatePilotReleaseTests.Rows(b.Restored,$"SELECT CONVERT(varchar(36),s.backup_set_uuid) FROM msdb.dbo.backupset s JOIN msdb.dbo.backupmediafamily m ON m.media_set_id=s.media_set_id WHERE s.database_name='{b.Source}' AND m.physical_device_name='{backup}' AND s.type='D' AND s.has_backup_checksums=1 AND s.is_damaged=0");
        var set=Assert.Single(sets); Assert.True(Guid.TryParse(set,out _));
        var restored=await PrivatePilotReleaseTests.Rows(b.Restored,$"SELECT CONVERT(varchar(36),s.backup_set_uuid) FROM msdb.dbo.restorehistory h JOIN msdb.dbo.backupset s ON s.backup_set_id=h.backup_set_id WHERE h.destination_database_name='{b.Restored}' AND h.restore_type='D'");
        Assert.Equal(new[]{set},restored);
        var data="/var/opt/mssql/data/"+b.Restored+".mdf"; var log="/var/opt/mssql/data/"+b.Restored+"_log.ldf";
        Assert.Equal(new[]{"0|"+data,"1|"+log},await PrivatePilotReleaseTests.Rows(b.Restored,"SELECT type,physical_name FROM sys.database_files ORDER BY type"));
        return new(b.Nonce,b.Candidate,b.Hash,b.Source,b.Restored,b.Resources.ContainerId,b.Resources.NetworkId,b.Resources.VolumeId,true,
            backup,set,b.Source,true,true,true,data,log,"",[],b.SqlStart,default,false,false,false,false,[]);
    }
    internal static async Task<string> Capture(string database)
    {
        var schema = await PrivatePilotReleaseTests.Inspect(database);
        Assert.Equal(Tables, schema["tables"]);
        var rows = new SortedDictionary<string, string[]>(StringComparer.Ordinal);
        foreach (var t in Tables) rows[t] = await HashRows(database, $"SELECT * FROM savia_internal.[{t}]");
        rows["dbo.__EFMigrationsHistory"] = await HashRows(database, "SELECT * FROM dbo.__EFMigrationsHistory");
        rows["$schema"] = [Digest(JsonSerializer.Serialize(schema))];
        rows["$metadata"] = await HashRows(database, """
            SELECT s.name AS schema_name,t.name AS table_name,c.name AS column_name,c.column_id,
              ty.name AS type_name,c.max_length,c.precision,c.scale,c.is_nullable,c.is_identity,c.collation_name,
              c.is_computed,cc.definition AS computed_definition,dc.definition AS default_definition
            FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
            JOIN sys.columns c ON c.object_id=t.object_id JOIN sys.types ty ON ty.user_type_id=c.user_type_id
            LEFT JOIN sys.computed_columns cc ON cc.object_id=c.object_id AND cc.column_id=c.column_id
            LEFT JOIN sys.default_constraints dc ON dc.object_id=c.default_object_id
            """);
        rows["$foreignkeys"] = await HashRows(database, """
            SELECT ps.name AS parent_schema,pt.name AS parent_table,f.name,pc.name AS parent_column,
              rs.name AS referenced_schema,rt.name AS referenced_table,rc.name AS referenced_column,
              fc.constraint_column_id,f.delete_referential_action,f.update_referential_action,f.is_disabled,f.is_not_trusted
            FROM sys.foreign_keys f JOIN sys.foreign_key_columns fc ON fc.constraint_object_id=f.object_id
            JOIN sys.tables pt ON pt.object_id=f.parent_object_id JOIN sys.schemas ps ON ps.schema_id=pt.schema_id
            JOIN sys.columns pc ON pc.object_id=pt.object_id AND pc.column_id=fc.parent_column_id
            JOIN sys.tables rt ON rt.object_id=f.referenced_object_id JOIN sys.schemas rs ON rs.schema_id=rt.schema_id
            JOIN sys.columns rc ON rc.object_id=rt.object_id AND rc.column_id=fc.referenced_column_id
            """);
        rows["$indexes"] = await HashRows(database, """
            SELECT s.name AS schema_name,t.name AS table_name,i.name,i.type,i.is_unique,i.is_primary_key,
              i.is_unique_constraint,i.is_disabled,i.filter_definition,c.name AS column_name,
              ic.index_column_id,ic.key_ordinal,ic.is_descending_key,ic.is_included_column
            FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id JOIN sys.indexes i ON i.object_id=t.object_id
            JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
            JOIN sys.columns c ON c.object_id=t.object_id AND c.column_id=ic.column_id
            """);
        return JsonSerializer.Serialize(rows);
    }
    internal static void Equal(string expected, string actual) => Assert.Equal(expected, actual);
    internal static void Admit(Baseline b, Receipt r, string nonce, string candidate, string database, bool restart)
    {
        Assert.Matches("^[a-f0-9]{32}$", nonce); Assert.Matches("^[a-f0-9]{40}$", candidate);
        Assert.Equal(nonce, b.Nonce); Assert.Equal(candidate, b.Candidate);
        Assert.Equal(b.Nonce, r.Nonce); Assert.Equal(b.Candidate, r.Candidate); Assert.Equal(b.Hash, r.BaselineHash);
        Assert.Equal(b.Source, r.Source); Assert.Equal(b.Restored, r.Restored); Assert.Equal(b.Restored, database);
        Assert.NotEqual(b.Source, b.Restored);
        Assert.Matches("^SaviaInternalTest_Pilot_[a-f0-9]{32}$", b.Source);
        Assert.Matches("^SaviaInternalTest_Pilot_[a-f0-9]{32}$", b.Restored);
        foreach (var id in new[] { r.ContainerId, r.NetworkId, r.VolumeId, r.BackupSetId }) Assert.False(string.IsNullOrWhiteSpace(id));
        Assert.Equal(new Ownership(nonce,candidate,r.ContainerId,r.NetworkId,r.VolumeId,true), b.Resources);
        Assert.True(r.CreationAcknowledged); Assert.Equal(b.Source, r.BackupCatalog);
        Assert.Equal("/var/opt/mssql/data/" + b.Source + ".bak", r.BackupPath);
        Assert.Equal("/var/opt/mssql/data/" + b.Restored + ".mdf", r.DataFile);
        Assert.Equal("/var/opt/mssql/data/" + b.Restored + "_log.ldf", r.LogFile);
        Assert.True(r.BackupChecksum && r.VerifyOnly && r.RestoreCompleted);
        Assert.False(r.Reseeded || r.Migrated || r.Replaced);
        if (!restart) return;
        Assert.Equal(b.SqlStart,r.BeforeSqlStart);
        Assert.Equal(r.ContainerId, r.RestartContainerId);
        Assert.Equal(new[] { "running", "stopped", "running" }, r.States);
        Assert.True(r.BeforeSqlStart > DateTimeOffset.MinValue && r.AfterSqlStart > r.BeforeSqlStart);
        Assert.True(r.FreshRead);
        AssertResults(r.Results, candidate, Selected[..6]);
    }
    internal static void AssertResults(SqlResult[] results, string candidate, string[] names)
    {
        Assert.Equal(names.Order(), results.Select(x => x.Name).Order());
        Assert.All(results, x => { Assert.Equal(candidate, x.Candidate); Assert.Equal("Passed", x.Outcome); });
    }
    internal static T Load<T>(string directory, string name) => JsonSerializer.Deserialize<T>(File.ReadAllText(Path.Combine(directory, name)))!;
}

public sealed class PilotRecoveryOfflineTests
{
    private static PilotRecoveryProof.Baseline Baseline => new(new string('a',32),new string('b',40),"SaviaInternalTest_Pilot_"+new string('c',32),"SaviaInternalTest_Pilot_"+new string('d',32),"synthetic identities", Snapshot(),new(new string('a',32),new string('b',40),"container-id","network-id","volume-id",true),DateTimeOffset.Parse("2026-11-10T00:00:00Z"));
    private static SortedDictionary<string,object[][]> FixtureRows()
    {
        var rows=new SortedDictionary<string,object[][]>(StringComparer.Ordinal);
        foreach(var t in PilotRecoveryProof.Tables) rows[t]=[];
        rows["CashEntries"]=[ ["opening-a","till-a","cashier","cashier",10000L], ["sale","till-a","cashier","cashier",2500L],
            ["opening-b","till-b","cashier","cashier",2000L], ["refund","till-b","cashier","manager",-1250L] ];
        rows["CashCloses"]=[ ["close-a","till-a",12500L,12400L,-100L], ["close-b","till-b",750L,750L,0L] ];
        rows["Operations"]=[ ["refund-op","manager","successful-result-refund-id"] ];
        rows["Sessions"]=[ ["session-a","cashier",DBNull.Value] ];
        return rows;
    }
    private static string Snapshot(SortedDictionary<string,object[][]>? raw=null) => JsonSerializer.Serialize((raw??FixtureRows())
        .ToDictionary(x=>x.Key,x=>x.Value.Select(r=>PilotRecoveryProof.Digest(JsonSerializer.Serialize(r.Select(PilotRecoveryProof.Cell).ToArray())))
            .OrderBy(h=>h,StringComparer.Ordinal).ToArray()));
    private static PilotRecoveryProof.Receipt Receipt(PilotRecoveryProof.Baseline b) => new(b.Nonce,b.Candidate,b.Hash,b.Source,b.Restored,"container-id","network-id","volume-id",true,
        "/var/opt/mssql/data/"+b.Source+".bak","backup-set-id",b.Source,true,true,true,"/var/opt/mssql/data/"+b.Restored+".mdf","/var/opt/mssql/data/"+b.Restored+"_log.ldf",
        "container-id",["running","stopped","running"],DateTimeOffset.Parse("2026-11-10T00:00:00Z"),DateTimeOffset.Parse("2026-11-10T00:01:00Z"),true,false,false,false,
        PilotRecoveryProof.Selected[..6].Select(x=>new PilotRecoveryProof.SqlResult(x,b.Candidate,"Passed")).ToArray());
    [Fact] public void Offline_recovery_accepts_unchanged_snapshot_and_complete_receipt()
    {
        var b=Baseline; PilotRecoveryProof.Equal(b.Snapshot,Snapshot());
        PilotRecoveryProof.Admit(b,Receipt(b),b.Nonce,b.Candidate,b.Restored,true);
        PilotRecoveryProof.AssertResults(PilotRecoveryProof.Selected.Select(x=>new PilotRecoveryProof.SqlResult(x,b.Candidate,"Passed")).ToArray(),b.Candidate,PilotRecoveryProof.Selected);
    }
    [Theory]
    [InlineData("removed refund")] [InlineData("duplicate entry")] [InlineData("balanced altered identity")]
    [InlineData("lost shortage")] [InlineData("changed original close")] [InlineData("swapped actor/till")]
    [InlineData("changed operation result")] [InlineData("omitted table")] [InlineData("extra row")]
    public void Offline_recovery_rejects_snapshot_corruption(string corruption)
    {
        var b=Baseline; var rows=FixtureRows();
        switch(corruption)
        {
            case "omitted table": rows.Remove("Sessions"); break;
            case "removed refund": rows["CashEntries"]=rows["CashEntries"][..3]; break;
            case "duplicate entry": rows["CashEntries"]=[..rows["CashEntries"],rows["CashEntries"][3]]; break;
            case "extra row": rows["Sessions"]=[..rows["Sessions"],["extra","manager",DBNull.Value]]; break;
            case "balanced altered identity": rows["CashEntries"][3][0]="another-refund-same-amount"; break;
            case "lost shortage": rows["CashCloses"][0][3]=12500L; rows["CashCloses"][0][4]=0L; break;
            case "changed original close": rows["CashCloses"][0][0]="replacement-close"; break;
            case "swapped actor/till": rows["CashEntries"][3][1]="till-a"; rows["CashEntries"][3][3]="cashier"; break;
            case "changed operation result": rows["Operations"][0][2]="different-refund-result"; break;
            default: throw new ArgumentOutOfRangeException(nameof(corruption));
        }
        Assert.ThrowsAny<Exception>(()=>PilotRecoveryProof.Equal(b.Snapshot,Snapshot(rows)));
    }
    [Theory]
    [InlineData("stale baseline")] [InlineData("wrong nonce")] [InlineData("wrong restored database")]
    [InlineData("missing backup")] [InlineData("missing restore")] [InlineData("no-op restart")]
    [InlineData("absent SQL result")] [InlineData("skipped SQL result")] [InlineData("replacement")]
    [InlineData("wrong source")] [InlineData("wrong resource")] [InlineData("wrong baseline hash")]
    [InlineData("wrong volume")] [InlineData("wrong network")] [InlineData("missing acknowledgement")]
    [InlineData("unobserved stop")] [InlineData("no fresh read")] [InlineData("reseeded")] [InlineData("migrated")]
    public void Offline_recovery_rejects_incomplete_admission(string corruption)
    {
        var b=Baseline; var r=Receipt(b);
        r=corruption switch {
            "stale baseline"=>r with { Candidate=new string('e',40) }, "wrong nonce"=>r with { Nonce=new string('f',32) },
            "wrong restored database"=>r with { Restored=b.Source }, "missing backup"=>r with { BackupSetId="" },
            "missing restore"=>r with { RestoreCompleted=false }, "no-op restart"=>r with { AfterSqlStart=r.BeforeSqlStart },
            "absent SQL result"=>r with { Results=r.Results[..5] }, "skipped SQL result"=>r with { Results=[..r.Results[..5],r.Results[5] with { Outcome="Skipped" }] },
            "replacement"=>r with { Replaced=true }, "wrong source"=>r with { BackupCatalog=b.Restored },
            "wrong resource"=>r with { RestartContainerId="other" }, "wrong volume"=>r with { VolumeId="other" },
            "wrong network"=>r with { NetworkId="other" }, "missing acknowledgement"=>r with { CreationAcknowledged=false },
            "unobserved stop"=>r with { States=["running","running"] }, "no fresh read"=>r with { FreshRead=false },
            "reseeded"=>r with { Reseeded=true }, "migrated"=>r with { Migrated=true }, _=>r with { BaselineHash="wrong" } };
        Assert.ThrowsAny<Exception>(()=>PilotRecoveryProof.Admit(b,r,b.Nonce,b.Candidate,b.Restored,true));
    }
    [Theory] [InlineData("missing")] [InlineData("skip")] [InlineData("stale")] [InlineData("duplicate")]
    public void Offline_recovery_final_seven_results_require_exact_names_source_and_zero_skips(string corruption)
    {
        var b=Baseline;
        var results=PilotRecoveryProof.Selected.Select(x=>new PilotRecoveryProof.SqlResult(x,b.Candidate,"Passed")).ToArray();
        if(corruption=="missing") results=results[..6];
        else results[6]=corruption switch { "skip"=>results[6] with { Outcome="Skipped" }, "stale"=>results[6] with { Candidate=new string('e',40) }, _=>results[0] };
        Assert.ThrowsAny<Exception>(()=>PilotRecoveryProof.AssertResults(results,b.Candidate,PilotRecoveryProof.Selected));
    }
    [Fact] public void Offline_recovery_cells_preserve_null_type_delimiters_precision_and_duplicates()
    {
        Assert.NotEqual(PilotRecoveryProof.Cell(DBNull.Value),PilotRecoveryProof.Cell("null"));
        Assert.NotEqual(PilotRecoveryProof.Cell(1),PilotRecoveryProof.Cell(1L));
        Assert.NotEqual(PilotRecoveryProof.Cell("\uD800"),PilotRecoveryProof.Cell("\uFFFD"));
        Assert.NotEqual(PilotRecoveryProof.Cell("a|b"),PilotRecoveryProof.Cell("a"));
        Assert.NotEqual(PilotRecoveryProof.Cell(DateTimeOffset.Parse("2026-11-10T00:00:00.0000001Z")),PilotRecoveryProof.Cell(DateTimeOffset.Parse("2026-11-10T00:00:00Z")));
        Assert.NotEqual(PilotRecoveryProof.Cell(new byte[]{0,1}),PilotRecoveryProof.Cell(new byte[]{1}));
    }
}
