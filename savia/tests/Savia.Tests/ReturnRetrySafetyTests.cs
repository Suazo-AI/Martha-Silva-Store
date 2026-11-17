using Microsoft.Data.SqlClient;

namespace Savia.Tests;

/// <summary>Prepared runtime fixtures. Never count source/build checks as SQL proof.</summary>
public sealed class ReturnRetrySafetyTests
{
    [Theory]
    [InlineData(false, false, false)]
    [InlineData(false, true, false)]
    [InlineData(true, false, false)]
    [InlineData(true, true, false)]
    [InlineData(false, false, true)]
    [InlineData(true, false, true)]
    public async Task Same_reversal_serializes_exact_and_different_financial_requests(bool credit, bool mismatch, bool mixed)
    {
        await using var f = await UsdFixture.Create(100000, 10000);
        var sale = Guid.NewGuid();
        var reversal = Guid.NewGuid();
        var creditId = Guid.NewGuid();
        await f.Exec($"""
            DECLARE @l sales.SaleLineRequest,@t sales.SaleTenderRequest;
            INSERT @l VALUES(1,'{Ids.Item}',1,216100,0);
            INSERT @t(TenderNumber,TenderKind,AmountMinor) VALUES(1,'card',216100);
            EXEC sales.usp_PostSale '{sale}','{Ids.BranchA}','{Ids.LocA}','{Ids.CashierA}','NIO','{Ids.NodeA}',@l,@t,
              @TillId='{f.Till}';
            """);
        var usdBefore = await f.Scalar($"SELECT COALESCE(SUM(e.DeltaMinor),0) FROM sales.CashEntries e JOIN sales.CashTills t ON t.Id=e.TillId WHERE t.ParentTillId='{f.Till}'");
        // Both directions isolate the reversal lock from the winner's drawer lock.
        var otherTill = Guid.NewGuid();
        var otherRegister = Guid.NewGuid();
        await f.Exec($"""
            INSERT sales.CashRegisters(Id,BranchId,LocationId,Code,Name)
            VALUES('{otherRegister}','{Ids.BranchA}','{Ids.LocA}','RETRY',N'Retry');
            EXEC sales.usp_OpenTill '{otherTill}','{otherRegister}','{Ids.CashierA}','NIO',100000,'{Ids.NodeA}';
            """);
        var lineId = await TestSql.ScalarAsync<string>(f.Database,
            $"SELECT CONVERT(varchar(36),Id) FROM sales.SaleLines WHERE SaleId='{sale}'");
        string Request(bool useCredit, Guid till, string pool)
        {
            var call = useCredit
                ? $"EXEC sales.usp_PostCreditReturn '{reversal}','{creditId}','{sale}','{Ids.BranchA}','{Ids.LocA}','{till}','{Ids.Manager}','{Ids.Manager}',@customer,N'Talla','{Ids.NodeA}',@r;"
                : $"EXEC sales.usp_PostReturnOutcome '{reversal}','{sale}','{Ids.BranchA}','{Ids.LocA}','{till}','{Ids.Manager}','transfer',N'Talla',N'BAC','{Ids.NodeA}',@r,NULL,@new,@pay;";
            return $"""
                DECLARE @r sales.ReturnLineRequest,@new sales.SaleLineRequest,@pay sales.SaleTenderRequest,
                  @customer uniqueidentifier=test.Id('customer');
                INSERT @r VALUES('{lineId}',1,'{pool}');
                {call}
                """;
        }
        await using var winner = new SqlConnection(TestSql.ConnectionFor(f.Database));
        await using var contender = new SqlConnection(TestSql.ConnectionFor(f.Database));
        await using var observer = new SqlConnection(TestSql.ConnectionFor(f.Database));
        await winner.OpenAsync(); await contender.OpenAsync(); await observer.OpenAsync();
        await using var transaction = (SqlTransaction)await winner.BeginTransactionAsync();
        await using var win = new SqlCommand(Request(credit, f.Till, "store"), winner, transaction) { CommandTimeout = 20 };
        await using var send = new SqlCommand(Request(mixed ? !credit : credit, mixed ? otherTill : f.Till,
            mismatch ? "quarantine" : "store"), contender) { CommandTimeout = 20 };
        Task<int>? pending = null;
        Exception? original = null;
        try
        {
            await win.ExecuteNonQueryAsync(); // procedure commits its nested transaction only
            var before = await Snapshot(winner, transaction);
            pending = send.ExecuteNonQueryAsync();
            await ObserveReversalWait(observer, winner.ServerProcessId, contender.ServerProcessId, reversal, pending);
            await transaction.CommitAsync(); // release ONLY after a server-observed application wait
            var code = 0;
            try { await pending; }
            catch (SqlException ex) { code = ex.Number; }
            Assert.Equal(mismatch || mixed ? 51538 : 0, code);
            Assert.Equal(before, await Snapshot(observer, null));
        }
        catch (Exception ex) { original = ex; throw; }
        finally
        {
            // Cancel and drain before disposing sessions; cleanup cannot replace the original failure.
            try
            {
                if (transaction.Connection is not null)
                {
                    send.Cancel();
                    await transaction.RollbackAsync();
                }
            }
            catch when (original is not null) { }
            if (pending is not null)
            {
                try { await pending; }
                catch when (original is not null || pending.IsFaulted) { }
            }
        }
        Assert.Equal(1, await f.Scalar($"SELECT COUNT(*) FROM sales.SaleReversals WHERE Id='{reversal}' AND RequestIdentityVersion=1"));
        Assert.Equal(1, await f.Scalar($"SELECT COUNT(*) FROM sales.SaleReversalLines WHERE ReversalId='{reversal}'"));
        Assert.Equal(1, await f.Scalar($"SELECT ReturnedQuantity FROM sales.SaleLines WHERE SaleId='{sale}'"));
        Assert.Equal(1, await f.Scalar($"SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId='{reversal}'"));
        Assert.Equal(credit ? 1 : 0, await f.Scalar($"SELECT COUNT(*) FROM credits.Credits WHERE SourceReversalId='{reversal}'"));
        Assert.Equal(usdBefore, await f.Scalar($"SELECT COALESCE(SUM(e.DeltaMinor),0) FROM sales.CashEntries e JOIN sales.CashTills t ON t.Id=e.TillId WHERE t.ParentTillId='{f.Till}'"));
        await TestSql.AssertConservationAsync(f.Database);
    }

    private static async Task ObserveReversalWait(SqlConnection observer, int winner, int contender,
        Guid reversal, Task pending)
    {
        // Match the full server lock identity, plus the readable 32-character application prefix.
        // An unrelated till/page/key wait and a sequential/no-wait schedule both fail.
        var deadline = System.Diagnostics.Stopwatch.StartNew();
        while (deadline.Elapsed < TimeSpan.FromSeconds(6))
        {
            Assert.False(pending.IsCompleted, "Contender completed without observed reversal-lock overlap");
            await using var query = new SqlCommand("""
                SELECT COUNT(*) FROM sys.dm_tran_locks w
                JOIN sys.dm_tran_locks h ON h.resource_type=w.resource_type
                  AND h.resource_database_id=w.resource_database_id
                  AND h.resource_associated_entity_id=w.resource_associated_entity_id
                  AND h.resource_description=w.resource_description
                  AND h.resource_lock_partition=w.resource_lock_partition
                JOIN sys.dm_exec_requests r ON r.session_id=w.request_session_id
                WHERE w.resource_type='APPLICATION' AND w.request_status='WAIT'
                  AND h.request_status='GRANT' AND h.request_mode='X' AND w.request_mode='X'
                  AND w.request_session_id=@contender AND h.request_session_id=@winner
                  AND r.blocking_session_id=@winner AND r.wait_type LIKE 'LCK_M_%'
                  AND CHARINDEX(@prefix,w.resource_description)>0;
                """, observer) { CommandTimeout = 2 };
            query.Parameters.AddWithValue("@winner", winner);
            query.Parameters.AddWithValue("@contender", contender);
            query.Parameters.AddWithValue("@prefix", ("savia.return." + reversal.ToString()).Substring(0, 32));
            if (Convert.ToInt32(await query.ExecuteScalarAsync()) > 0) return;
            await Task.Delay(20); // polling cadence only; never evidence of overlap
        }
        throw new TimeoutException("No shared reversal APPLICATION wait observed before release");
    }

    private static async Task<string> Snapshot(SqlConnection connection, SqlTransaction? transaction)
    {
        // Every financial/sync table, ordered by its full primary key; includes USD children/entries.
        await using var command = new SqlCommand("""
            DECLARE @image nvarchar(max)=N'',@object int,@name nvarchar(300),@order nvarchar(max),
              @sql nvarchar(max),@rows nvarchar(max);
            DECLARE snapshots CURSOR LOCAL FAST_FORWARD FOR
            SELECT t.object_id,QUOTENAME(s.name)+N'.'+QUOTENAME(t.name)
            FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
            WHERE s.name IN ('sales','inventory','credits','accounting','sync') ORDER BY s.name,t.name;
            OPEN snapshots; FETCH NEXT FROM snapshots INTO @object,@name;
            WHILE @@FETCH_STATUS=0
            BEGIN
              SET @order=NULL;
              SELECT @order=STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(c.name)),N',')
                WITHIN GROUP(ORDER BY ic.key_ordinal)
              FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
              JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
              WHERE i.object_id=@object AND i.is_primary_key=1;
              IF @order IS NULL THROW 59002,'Snapshot needs primary key',1;
              SET @sql=N'SELECT @r=(SELECT * FROM '+@name+N' ORDER BY '+@order+N' FOR JSON PATH,INCLUDE_NULL_VALUES);';
              EXEC sys.sp_executesql @sql,N'@r nvarchar(max) OUTPUT',@r=@rows OUTPUT;
              SET @image+=@name+N':'+CONVERT(nvarchar(20),DATALENGTH(@rows))+N':'+@rows;
              FETCH NEXT FROM snapshots INTO @object,@name;
            END;
            CLOSE snapshots; DEALLOCATE snapshots;
            SELECT @image;
            """, connection, transaction) { CommandTimeout = 20 };
        return (string)(await command.ExecuteScalarAsync())!;
    }
}
