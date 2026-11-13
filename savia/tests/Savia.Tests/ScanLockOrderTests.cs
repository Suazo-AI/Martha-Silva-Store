using System.Net.Http.Json;
using Microsoft.Data.SqlClient;
using Savia.Contracts;

namespace Savia.Tests;

public sealed class ScanLockOrderTests
{
    [Fact]
    public async Task Scanners_in_caller_transactions_lock_session_before_scan_key_ranges()
    {
        var db = await TestSql.CloneAsync("scan_lock");
        try
        {
            await using var node = SaviaNode.BranchA(db);
            var client = await node.SignInAsync(Ids.CashierA, "t_cashier_a");
            var session = Guid.NewGuid();
            await HttpAssert.OkAsync(await client.PostAsJsonAsync("/api/v1/receiving/sessions", new OpenScanSessionRequest(Guid.NewGuid(), session, "LOCK-ORDER", Ids.Supplier)));
            await using var first = new SqlConnection(TestSql.ConnectionFor(db));
            await using var second = new SqlConnection(TestSql.ConnectionFor(db));
            await first.OpenAsync(); await second.OpenAsync();
            async Task Scan(SqlConnection c, string id, bool begin = false)
            {
                if (begin) { await using var start = new SqlCommand("BEGIN TRAN", c); await start.ExecuteNonQueryAsync(); }
                await using var cmd = new SqlCommand("EXEC receiving.usp_RecordScan @ScanId,@Session,@Code,1,NULL,@Actor", c);
                cmd.Parameters.AddWithValue("@ScanId", Guid.Parse(id)); cmd.Parameters.AddWithValue("@Session", session);
                cmd.Parameters.AddWithValue("@Code", Ids.ItemBarcode); cmd.Parameters.AddWithValue("@Actor", Ids.CashierA);
                await cmd.ExecuteNonQueryAsync();
            }
            // Pre-existing keys separate the ranges. An empty table would lock the entire range
            // on the first insert and conceal the production race.
            foreach (var suffix in new[] { "050", "150", "250" })
                await Scan(first, "00000000-0000-0000-0000-000000000" + suffix);
            // First scanner keeps its caller-owned transaction open after one scan.
            await Scan(first, "00000000-0000-0000-0000-000000000100", true);
            // The second scanner must wait for the session without owning a gap in ScanEvents.
            var waiting = Scan(second, "00000000-0000-0000-0000-000000000200");
            await Task.Delay(300);
            // A new scan of the first scanner shares that key range. Old ordering deadlocks here.
            await Scan(first, "00000000-0000-0000-0000-000000000210");
            await using (var commit = new SqlCommand("COMMIT", first)) await commit.ExecuteNonQueryAsync();
            await waiting;
            Assert.Equal(6, await TestSql.ScalarAsync<int>(db, $"SELECT COUNT(*) FROM receiving.ScanEvents WHERE ScanSessionId='{session}'"));
        }
        finally { await TestSql.DropAsync(db); }
    }
}
