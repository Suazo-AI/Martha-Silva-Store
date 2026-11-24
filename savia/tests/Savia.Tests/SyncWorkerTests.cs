using System.Net;
using System.Text.Json.Nodes;
using Microsoft.Data.SqlClient;
using Savia.Application;

namespace Savia.Tests;

/// <summary>
/// The production branch round (<c>BranchSync</c> + <c>HttpSyncHub</c>) against the in-memory hub, on real SQL.
/// Faults are injected between the worker and the hub; every case ends with the conservation oracle on both nodes.
/// </summary>
public sealed class SyncWorkerTests
{
    private static readonly CancellationToken None = CancellationToken.None;

    [Fact]
    public async Task Initial_then_incremental_rounds_move_only_new_rows()
    {
        await using var f = await SyncFixture.CreateAsync();
        var first = await f.SellAsync();
        var initial = await f.Round().RunOnceAsync(None);
        Assert.True(initial.Pushed > 0);
        Assert.False(initial.Rebuilt);
        Assert.Equal(1, await f.SaleCountAsync(f.CloudDb, first));

        var idle = await f.Round().RunOnceAsync(None);
        Assert.Equal((0, 0), (idle.Pulled, idle.Pushed));

        var second = await f.SellAsync();
        var incremental = await f.Round().RunOnceAsync(None);
        Assert.True(incremental.Pushed > 0);
        Assert.Equal(1, await f.SaleCountAsync(f.CloudDb, second));
        var batch = JsonNode.Parse(f.LastPush)!;
        Assert.All(batch["tables"]!.AsArray(), t => Assert.Equal("incremental", (string)t!["a"]!));
        Assert.Single(batch["tables"]!.AsArray().Single(t => (string)t!["t"]! == "[sales].[Sales]")!["rows"]!.AsArray());
        await f.AssertConservationAsync();
    }

    [Fact]
    public async Task Retry_after_a_lost_answer_repeats_no_effect()
    {
        await using var f = await SyncFixture.CreateAsync();
        var sale = await f.SellAsync();
        f.Faults.LoseAnswer = SyncFixture.PushPath;   // the hub commits; the branch never hears back
        await Assert.ThrowsAsync<HttpRequestException>(() => f.Round().RunOnceAsync(None));
        Assert.Equal(1, await f.SaleCountAsync(f.CloudDb, sale));

        var retry = await f.Round().RunOnceAsync(None);
        Assert.Equal(0, retry.Pushed);
        Assert.Equal(1, await f.SaleCountAsync(f.CloudDb, sale));
        await f.AssertConservationAsync();
    }

    [Fact]
    public async Task Dropped_push_is_delivered_by_the_next_round()
    {
        await using var f = await SyncFixture.CreateAsync();
        var sale = await f.SellAsync();
        f.Faults.DropBefore = SyncFixture.PushPath;
        await Assert.ThrowsAsync<HttpRequestException>(() => f.Round().RunOnceAsync(None));
        Assert.Equal(0, await f.SaleCountAsync(f.CloudDb, sale));

        var next = await f.Round().RunOnceAsync(None);
        Assert.True(next.Pushed > 0);
        Assert.Equal(1, await f.SaleCountAsync(f.CloudDb, sale));
        await f.AssertConservationAsync();
    }

    [Fact]
    public async Task Late_batch_from_an_earlier_round_changes_nothing()
    {
        await using var f = await SyncFixture.CreateAsync();
        await f.SellAsync();
        await f.Round().RunOnceAsync(None);
        var early = f.LastPush;
        var later = await f.SellAsync();
        await f.Round().RunOnceAsync(None);
        var stock = await f.CountAsync(f.CloudDb, $"SELECT SUM(OnHand) FROM inventory.StockBalances WHERE LocationId='{Ids.LocA}'");

        var late = await f.PostAsync(SyncFixture.PushPath, early, Ids.NodeA, SyncFixture.SecretA);
        Assert.Equal(HttpStatusCode.OK, late.StatusCode);
        Assert.Equal(0, (int)JsonNode.Parse(await late.Content.ReadAsStringAsync())!["changed"]!);
        Assert.Equal(1, await f.SaleCountAsync(f.CloudDb, later));
        Assert.Equal(stock, await f.CountAsync(f.CloudDb, $"SELECT SUM(OnHand) FROM inventory.StockBalances WHERE LocationId='{Ids.LocA}'"));
        await f.AssertConservationAsync();
    }

    [Fact]
    public async Task Lost_rebuild_answer_does_not_open_the_hub_to_the_restored_fork()
    {
        await using var f = await SyncFixture.CreateAsync();
        var backup = $"{f.BranchDb}.bak";
        await SyncFixture.ExecAsync("master", $"BACKUP DATABASE [{f.BranchDb}] TO DISK=N'{backup}' WITH INIT, FORMAT, COPY_ONLY;");
        var lost = await f.SellAsync();
        await f.Round().RunOnceAsync(None);
        await RestoreAsync(f.BranchDb, backup);

        // The hub serves the rebuild, but the branch never receives it, so it never applies it.
        f.Faults.LoseAnswerIfBodyHas = "\"mode\":\"rebuild\"";
        await Assert.ThrowsAsync<HttpRequestException>(() => f.Round().RunOnceAsync(None));
        Assert.Equal(0, await f.SaleCountAsync(f.BranchDb, lost));

        // The next round must still rebuild before the restored fork may push.
        var next = await f.Round().RunOnceAsync(None);
        Assert.True(next.Rebuilt, "a push from the restored fork was accepted before the branch applied any rebuild");
        Assert.Equal(1, await f.SaleCountAsync(f.BranchDb, lost));
        await TestSql.AssertConservationAsync(f.CloudDb);
    }

    private static async Task RestoreAsync(string database, string backup)
    {
        SqlConnection.ClearAllPools();
        await SyncFixture.ExecAsync("master", $"""
            ALTER DATABASE [{database}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
            RESTORE DATABASE [{database}] FROM DISK=N'{backup}' WITH REPLACE, RECOVERY;
            ALTER DATABASE [{database}] SET MULTI_USER;
            """);
        SqlConnection.ClearAllPools();
    }

    [Fact]
    public async Task Restored_branch_rebuilds_before_any_normal_pull()
    {
        // A normal pull leaves out the branch's own rows. After a restore, rows of other branches can point to rows the
        // branch lost (a transferred credit), so a normal pull would fail on a foreign key every round and never rebuild.
        await using var f = await SyncFixture.CreateAsync();
        var backup = $"{f.BranchDb}.bak";
        await SyncFixture.ExecAsync("master", $"BACKUP DATABASE [{f.BranchDb}] TO DISK=N'{backup}' WITH INIT, FORMAT, COPY_ONLY;");
        await f.SellAsync();
        await f.Round().RunOnceAsync(None);
        await RestoreAsync(f.BranchDb, backup);

        f.Faults.Posts.Clear();
        var recovery = await f.Round().RunOnceAsync(None);
        Assert.True(recovery.Rebuilt);
        var firstPull = f.Faults.Posts.First(p => p.Path == "/sync/v1/pull");
        Assert.Contains("\"mode\":\"rebuild\"", firstPull.Body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task Restored_branch_rebuilds_from_the_hub_before_it_pushes()
    {
        await using var f = await SyncFixture.CreateAsync();
        var backup = $"{f.BranchDb}.bak";   // the server's default backup folder
        await SyncFixture.ExecAsync("master", $"BACKUP DATABASE [{f.BranchDb}] TO DISK=N'{backup}' WITH INIT, FORMAT, COPY_ONLY;");
        var lost = await f.SellAsync();
        await f.Round().RunOnceAsync(None);
        var preRestore = f.LastPush;
        Assert.Equal(1, await f.SaleCountAsync(f.CloudDb, lost));

        // The branch PC comes back from the backup: the sale the hub holds is gone locally.
        await RestoreAsync(f.BranchDb, backup);
        Assert.Equal(0, await f.SaleCountAsync(f.BranchDb, lost));

        // The worker rebuilds before any local work (P9-SPEC open question 2: a sale made before this round opens a second
        // till, and the rebuild then fails on UX_OpenTill_Register; evidence/dotnet-sync-restore-sell-before-rebuild-red.txt).
        var recovery = await f.Round().RunOnceAsync(None);
        Assert.True(recovery.Rebuilt, "the hub refuses the new fork until it served a rebuild");
        Assert.Equal(1, await f.SaleCountAsync(f.BranchDb, lost));
        var after = await f.SellAsync();
        Assert.True((await f.Round().RunOnceAsync(None)).Pushed > 0);
        Assert.Equal(1, await f.SaleCountAsync(f.CloudDb, after));

        // The batch read before the restore belongs to a retired fork.
        await HttpAssert.ProblemAsync(await f.PostAsync(SyncFixture.PushPath, preRestore, Ids.NodeA, SyncFixture.SecretA),
            HttpStatusCode.Conflict, "sync.retired_fork");
        var idle = await f.Round().RunOnceAsync(None);
        Assert.False(idle.Rebuilt);
        Assert.Equal(0, idle.Pushed);
        await TestSql.AssertConservationAsync(f.CloudDb);

        // D-037: the sale the rebuild brought back is listed in sync.RecoveredSales and expects no new local event.
        Assert.Equal(1, await f.CountAsync(f.BranchDb, $"SELECT COUNT(*) FROM sync.RecoveredSales WHERE SaleId='{lost}'"));
        Assert.Empty(await SyncFixture.ViolationsAsync(f.BranchDb));
    }

    [Fact]
    public async Task Rebuild_larger_than_a_page_resumes_after_a_lost_page_and_reports_progress()
    {
        // D-041: a page holds at most 5,000 rows per table, so 6,001 hub categories need two pages in every direction.
        await using var f = await SyncFixture.CreateAsync();
        await SyncFixture.ExecAsync(f.CloudDb, """
            INSERT catalog.Categories(Id,Name)
            SELECT NEWID(),CONCAT(N'Paging ',n) FROM (SELECT TOP (6001) ROW_NUMBER() OVER (ORDER BY (SELECT 1)) n
                                                     FROM sys.all_objects a CROSS JOIN sys.all_objects b) x;
            """);
        // A provisioned branch knows its node before the backup, so the restored copy carries the recovery lock.
        await SyncFixture.ExecAsync(f.BranchDb, $"EXEC sync.usp_SetLocalNode @NodeId='{Ids.NodeA}';");
        var backup = $"{f.BranchDb}.bak";
        await SyncFixture.ExecAsync("master", $"BACKUP DATABASE [{f.BranchDb}] TO DISK=N'{backup}' WITH INIT, FORMAT, COPY_ONLY;");
        var lost = await f.SellAsync();
        f.Faults.Posts.Clear();
        await f.Round().RunOnceAsync(None);
        Assert.True(f.Faults.Posts.Count(p => p.Path == "/sync/v1/pull") >= 2, "the initial pull took a single page");
        await RestoreAsync(f.BranchDb, backup);

        // The second rebuild page never reaches the hub: the round fails half way, as a killed worker would.
        var status = new SyncStatus();
        f.Faults.DropBefore = "/sync/v1/pull";
        f.Faults.PassBeforeDrop = 1;
        await Assert.ThrowsAsync<HttpRequestException>(() => f.Round(status).RunOnceAsync(None));
        var progress = status.View.Rebuild;
        Assert.NotNull(progress);
        Assert.InRange(progress.Done, 0, progress.Total - 1);
        Assert.Equal(51864, (await Assert.ThrowsAsync<SqlException>(f.SellAsync)).Number);

        // A new worker continues the same pass at page 2; the last page lifts the recovery lock.
        f.Faults.Posts.Clear();
        var resumed = await f.Round(status).RunOnceAsync(None);
        Assert.True(resumed.Rebuilt);
        Assert.Contains("\"page\":2", f.Faults.Posts.First(p => p.Path == "/sync/v1/pull").Body, StringComparison.Ordinal);
        status.Record(DateTimeOffset.UtcNow);
        Assert.Null(status.View.Rebuild);
        Assert.Equal(1, await f.SaleCountAsync(f.BranchDb, lost));
        Assert.Equal(6001, await f.CountAsync(f.BranchDb, "SELECT COUNT(*) FROM catalog.Categories WHERE Name LIKE N'Paging %'"));
        Assert.Equal(1, await f.SaleCountAsync(f.BranchDb, await f.SellAsync()));
        await TestSql.AssertConservationAsync(f.CloudDb);
        Assert.Empty(await SyncFixture.ViolationsAsync(f.BranchDb));
    }

    [Fact]
    public void Status_keeps_rebuild_progress_after_a_failed_round_and_clears_it_after_a_good_one()
    {
        var status = new SyncStatus();
        status.Rebuilding(new SyncProgress(12, 39));
        status.Record(DateTimeOffset.UtcNow, "sync.unreachable", "timeout");
        Assert.Equal(new SyncProgress(12, 39), status.View.Rebuild);
        status.Record(DateTimeOffset.UtcNow);
        Assert.Null(status.View.Rebuild);
    }

    [Fact]
    public async Task Restored_branch_the_hub_never_saw_refuses_sales_until_it_rebuilds()
    {
        // D-036: the lock is the branch's own. The hub has no cursor for it and plans only 'initial', yet the restored
        // branch may not sell until a rebuild from the hub lands.
        await using var f = await SyncFixture.CreateAsync();
        await SyncFixture.ExecAsync(f.BranchDb, $"EXEC sync.usp_SetLocalNode @NodeId='{Ids.NodeA}';");
        var backup = $"{f.BranchDb}.bak";
        await SyncFixture.ExecAsync("master", $"BACKUP DATABASE [{f.BranchDb}] TO DISK=N'{backup}' WITH INIT, FORMAT, COPY_ONLY;");
        await RestoreAsync(f.BranchDb, backup);

        var refused = await Assert.ThrowsAsync<SqlException>(f.SellAsync);
        Assert.Equal(51864, refused.Number);
        Assert.True((await f.Round().RunOnceAsync(None)).Rebuilt);
        Assert.Equal(1, await f.SaleCountAsync(f.BranchDb, await f.SellAsync()));
    }
}
