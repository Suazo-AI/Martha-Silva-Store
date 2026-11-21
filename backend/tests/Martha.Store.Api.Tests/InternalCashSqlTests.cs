using System.Text.Json;
using System.Data.Common;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Martha.Store.Api.Internal;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Martha.Store.Api.Tests;

// PREPARED ONLY. Always use migrations: missing cash migration must fail, never EnsureCreated.
public sealed class InternalCashSqlTests
{
    [InternalCommerceSqlFact]
    public async Task Cash_reads_follow_persisted_money_and_preserve_history_without_configuration()
    {
        await using var f = await InternalCommerceSqlDatabase.Create(migrate: true);
        await Seed(f);
        var empty = await Read(f, s => s.Context(InternalSecurityRules.Principal(f.Staff, f.Session), default));
        Assert.True(empty.Success); Assert.Null(empty.Value!.OwnTill); Assert.Null(empty.Value.LastClose);
        Assert.Equal(new InternalCashConfiguration("USD", 2), empty.Value.Configuration);
        var open = await Run(f, s => s.Open(new(f.Location, "USD", 1000), f.Actor, "cash-read-open-key-0001", default));
        Assert.True(open.Success);
        var sale = await Run(f, s => s.Sell(new(open.Value!.Till.Id, null, [new(f.Item, 2)], "USD", 300), f.Actor, "cash-read-sale-key-0001", default));
        Assert.True(sale.Success);
        var current = await Read(f, s => s.Context(InternalSecurityRules.Principal(f.Staff, f.Session), default));
        Assert.Equal(1250, current.Value!.OwnTill!.BalanceMinor);
        var paid = await Read(f, s => s.RefundContext(sale.Value!.Sale.SaleId, 0, 50, InternalSecurityRules.Principal(f.Staff, f.Session), default));
        Assert.True(paid.Success); Assert.Equal(250, paid.Value!.RefundableMinor); Assert.Equal("paid", paid.Value.PaymentStatus);
        Assert.Equal(1250, Assert.Single(paid.Value.PayingTills.Items).BalanceMinor);
        var closed = await Run(f, s => s.Close(open.Value!.Till.Id, new(1240), f.Actor, "cash-read-close-key-001", default));
        Assert.True(closed.Success);
        var noConfig = await Read(f, s => s.Context(InternalSecurityRules.Principal(f.Staff, f.Session), default), new("", -1));
        Assert.True(noConfig.Success); Assert.Null(noConfig.Value!.Configuration); Assert.Null(noConfig.Value.OwnTill);
        Assert.Equal(closed.Value!.Close.Id, noConfig.Value.LastClose!.Close.Id);
        var next = await Run(f, s => s.Open(new(f.Location, "USD", 1000), f.Actor, "cash-read-next-key-0001", default));
        Assert.True(next.Success);
        var refunded = await Run(f, s => s.Refund(sale.Value!.Sale.SaleId,
            new(next.Value!.Till.Id, "USD", "read test", [new(sale.Value.Sale.Lines.Single().SaleLineId, 1)]), f.Actor, "cash-read-refund-key-01", default));
        Assert.True(refunded.Success);
        var after = await Read(f, s => s.RefundContext(sale.Value!.Sale.SaleId, 0, 50, InternalSecurityRules.Principal(f.Staff, f.Session), default), new("EUR", 3));
        Assert.True(after.Success); Assert.Equal(125, after.Value!.RefundedMinor); Assert.Equal(125, after.Value.RefundableMinor);
        Assert.Equal("partially_refunded", after.Value.PaymentStatus); Assert.Equal("USD", after.Value.Payment.Currency);
        Assert.Equal(875, Assert.Single(after.Value.PayingTills.Items).BalanceMinor);
        var historical = await Read(f, s => s.Context(InternalSecurityRules.Principal(f.Staff, f.Session), default));
        Assert.Equal(closed.Value.Close.Id, historical.Value!.LastClose!.Close.Id);
        Assert.Equal(1250, historical.Value.LastClose.Close.ExpectedMinor);
        await using var db = f.Context();
        await db.InternalSessions.Where(x => x.Id == f.Session.Id).ExecuteUpdateAsync(x => x.SetProperty(y => y.RevokedAt, DateTimeOffset.UtcNow));
        var revoked = await Read(f, s => s.Context(InternalSecurityRules.Principal(f.Staff, f.Session), default));
        Assert.Equal("unauthenticated", revoked.Error);
    }

    private static async Task<T> Read<T>(InternalCommerceSqlDatabase f, Func<InternalCashReadService, Task<T>> action,
        InternalCashOptions? configuration = null)
    {
        await using var db = f.Context();
        var security = new InternalSecurityService(db, new PasswordHasher<InternalStaff>(), TimeProvider.System);
        var http = new HttpContextAccessor { HttpContext = new DefaultHttpContext { User = InternalSecurityRules.Principal(f.Staff, f.Session) } };
        var runner = new InternalCommandRunner(db, security, http, TimeProvider.System);
        var commerce = new InternalCommerceService(db, runner, new InternalStockLedger(db));
        return await action(new InternalCashReadService(db, security, configuration ?? new("USD", 2), commerce));
    }

    [InternalCommerceSqlFact]
    public async Task Paid_sale_close_later_shift_refund_preserves_original_close_and_replays()
    {
        await using var f = await InternalCommerceSqlDatabase.Create(migrate: true);
        await Seed(f);
        var open = await Run(f, s => s.Open(new(f.Location, "USD", 10000), f.Actor, "cash-open-original-0001", default));
        Assert.True(open.Success); var id = open.Value!.Till.Id;
        var request = new InternalCashSaleRequest(id, null, [new(f.Item, 8), new(f.SecondItem, 10)], "USD", 4000);
        var sale = await Run(f, s => s.Sell(request, f.Actor, "cash-sale-original-0001", default));
        Assert.True(sale.Success); Assert.Equal(1000 + 2750, sale.Value!.Sale.TotalMinor);
        Assert.Equal(250, sale.Value.ChangeMinor);
        var close = await Run(f, s => s.Close(id, new(13650), f.Actor, "cash-close-original-0001", default));
        Assert.True(close.Success); Assert.Equal(13750, close.Value!.Close.ExpectedMinor); Assert.Equal(-100, close.Value.Close.DifferenceMinor);
        var before = JsonSerializer.Serialize(close);
        await using (var db = f.Context())
            await db.Set<InternalItem>().Where(x => x.Id == f.Item).ExecuteUpdateAsync(x => x.SetProperty(i => i.UnitPriceMinor, 999));
        var replay = await Run(f, s => s.Sell(request, f.Actor, "cash-sale-original-0001", default));
        Assert.Equal(JsonSerializer.Serialize(sale), JsonSerializer.Serialize(replay));
        var next = await Run(f, s => s.Open(new(f.Location, "USD", 20000), f.Actor, "cash-open-nextshift-0001", default));
        Assert.True(next.Success);
        var refundRequest = new InternalCashRefundRequest(next.Value!.Till.Id, "USD", "original-price refund",
            [new(sale.Value.Sale.Lines.Single(x => x.ItemId == f.Item).SaleLineId, 8)]);
        var refund = await Run(f, s => s.Refund(sale.Value.Sale.SaleId, refundRequest, f.Actor, "cash-refund-original-001", default));
        Assert.True(refund.Success); Assert.Equal(-1000, refund.Value!.Refund.DeltaMinor); Assert.Equal(2750, refund.Value.RefundableMinor);
        var nextClose = await Run(f, s => s.Close(next.Value.Till.Id, new(19000), f.Actor, "cash-close-nextshift-001", default));
        Assert.True(nextClose.Success); Assert.Equal(19000, nextClose.Value!.Close.ExpectedMinor);
        var refundReplay = await Run(f, s => s.Refund(sale.Value.Sale.SaleId, refundRequest, f.Actor, "cash-refund-original-001", default));
        Assert.Equal(JsonSerializer.Serialize(refund), JsonSerializer.Serialize(refundReplay));
        var oldClose = await Run(f, s => s.Close(id, new(13650), f.Actor, "cash-close-original-0001", default));
        Assert.Equal(before, JsonSerializer.Serialize(oldClose));
        await using var verify = f.Context();
        // Independent ADO.NET oracle uses fixed SQL, never handler calculations or EF inventory.
        await verify.Database.OpenConnectionAsync();
        await using var command = verify.Database.GetDbConnection().CreateCommand();
        command.CommandText = "SELECT SUM(DeltaMinor), COUNT(*) FROM savia_internal.CashEntries WHERE Kind='sale';";
        await using var reader = await command.ExecuteReaderAsync(); Assert.True(await reader.ReadAsync());
        Assert.Equal(3750L, reader.GetInt64(0)); Assert.Equal(1, reader.GetInt32(1));
    }

    [InternalCommerceSqlFact]
    public async Task Different_key_open_race_keeps_one_open_till_and_one_opening()
    {
        await using var f = await InternalCommerceSqlDatabase.Create(migrate: true);
        var outcomes = await Task.WhenAll(Run(f, s => s.Open(new(f.Location, "USD", 10000), f.Actor, "cash-open-race-key-0001", default)),
            Run(f, s => s.Open(new(f.Location, "USD", 10000), f.Actor, "cash-open-race-key-0002", default)));
        Assert.Single(outcomes, x => x.Success);
        await using var verify = f.Context();
        Assert.Equal(1, await verify.Set<InternalCashTill>().CountAsync(x => x.ClosedAt == null));
        Assert.Equal(1, await verify.Set<InternalCashEntry>().CountAsync(x => x.Kind == "opening"));
    }

    [InternalCommerceSqlFact]
    public async Task Underpayment_rolls_back_saved_stock_and_sale_and_old_route_is_rejected()
    {
        await using var f = await InternalCommerceSqlDatabase.Create(migrate: true); await Seed(f);
        var open = await Run(f, s => s.Open(new(f.Location, "USD", 10000), f.Actor, "cash-underpay-open-0001", default));
        var rejected = await Run(f, s => s.Sell(new(open.Value!.Till.Id, null, [new(f.Item, 1)], "USD", 1), f.Actor, "cash-underpay-sale-0001", default));
        Assert.Equal("insufficient_tender", rejected.Error);
        await using var db = f.Context();
        Assert.False(await db.Set<InternalSale>().AnyAsync());
        Assert.Equal(20, (await db.Set<InternalStockBalance>().SingleAsync(x => x.ItemId == f.Item)).OnHand);
        Assert.Equal(1, await db.Set<InternalCashEntry>().CountAsync());
        var legacy = await f.Execute(s => s.RecordSale(new(f.Location, null, [new(f.Item, 1)]), f.Actor, "cash-legacy-new-key-0001", default));
        Assert.Equal("cash_payment_required", legacy.Error);
    }

    [InternalCommerceSqlFact]
    public async Task Different_key_refund_race_cannot_exceed_original_quantity_or_cash()
    {
        await using var f = await InternalCommerceSqlDatabase.Create(migrate: true); await Seed(f);
        var open = await Run(f, s => s.Open(new(f.Location, "USD", 10000), f.Actor, "cash-refund-race-open-01", default));
        var sale = await Run(f, s => s.Sell(new(open.Value!.Till.Id, null, [new(f.Item, 1)], "USD", 125), f.Actor, "cash-refund-race-sale-01", default));
        var request = new InternalCashRefundRequest(open.Value!.Till.Id, "USD", "quantity refund", [new(sale.Value!.Sale.Lines.Single().SaleLineId, 1)]);
        var outcomes = await Task.WhenAll(Run(f, s => s.Refund(sale.Value.Sale.SaleId, request, f.Actor, "cash-refund-race-key-001", default)),
            Run(f, s => s.Refund(sale.Value.Sale.SaleId, request, f.Actor, "cash-refund-race-key-002", default)));
        Assert.Single(outcomes, x => x.Success);
        await using var db = f.Context();
        Assert.Equal(1, await db.Set<InternalCashEntry>().CountAsync(x => x.Kind == "refund"));
        Assert.Equal(125, await db.Set<InternalSaleReversal>().SumAsync(x => x.RecordedCreditMinor));
        Assert.Equal(20, (await db.Set<InternalStockBalance>().SingleAsync(x => x.ItemId == f.Item)).OnHand);
    }

    [InternalCommerceSqlFact]
    public Task Rollback_after_first_saved_stock_movement() => RollbackAt(1);
    [InternalCommerceSqlFact]
    public Task Rollback_after_saved_sale_and_cash_entry() => RollbackAt(2);
    [InternalCommerceSqlFact]
    public Task Rollback_before_transaction_commit() => RollbackAt(3);

    private static async Task RollbackAt(int stage)
    {
        await using var f = await InternalCommerceSqlDatabase.Create(migrate: true); await Seed(f);
        var open = await Run(f, s => s.Open(new(f.Location, "USD", 10000), f.Actor, "cash-failure-open-0001", default));
        var before = await Fingerprint(f);
        IInterceptor fault = stage == 3 ? new CommitFault(false) : new SaveFault(stage);
        var result = await Run(f, s => s.Sell(new(open.Value!.Till.Id, null, [new(f.Item, 1)], "USD", 125),
            f.Actor, "cash-injected-sale-0001", default), fault);
        Assert.Equal("unknown_outcome", result.Error);
        Assert.Equal(before, await Fingerprint(f)); // Aborted commit preserves Operations too.
    }

    [InternalCommerceSqlFact]
    public async Task Postcommit_response_loss_reconciles_one_persisted_payment()
    {
        await using var f = await InternalCommerceSqlDatabase.Create(migrate: true); await Seed(f);
        var open = await Run(f, s => s.Open(new(f.Location, "USD", 10000), f.Actor, "cash-loss-open-000001", default));
        var request = new InternalCashSaleRequest(open.Value!.Till.Id, null, [new(f.Item, 1)], "USD", 125);
        var uncertain = await Run(f, s => s.Sell(request, f.Actor, "cash-loss-sale-key-0001", default), new CommitFault(true));
        Assert.Equal("unknown_outcome", uncertain.Error);
        var committed = await Fingerprint(f);
        var recovered = await Run(f, s => s.Sell(request, f.Actor, "cash-loss-sale-key-0001", default));
        Assert.True(recovered.Success); Assert.Equal(125, recovered.Value!.Payment.DeltaMinor);
        Assert.Equal(committed, await Fingerprint(f));
        await using var db = f.Context();
        Assert.Equal(1, await db.Set<InternalCashEntry>().CountAsync(x => x.Kind == "sale"));
        Assert.Equal(19, (await db.Set<InternalStockBalance>().SingleAsync(x => x.ItemId == f.Item)).OnHand);
    }

    // Full independent ADO.NET fingerprint; no model-derived table expectations.
    private static async Task<SortedDictionary<string, string>> Fingerprint(InternalCommerceSqlDatabase f)
    {
        await using var db = f.Context(); await db.Database.OpenConnectionAsync();
        var connection = db.Database.GetDbConnection(); var names = new List<string>();
        await using (var command = connection.CreateCommand())
        {
            command.CommandText = "SELECT name FROM sys.tables WHERE schema_id=SCHEMA_ID('savia_internal') ORDER BY name";
            await using var reader = await command.ExecuteReaderAsync(); while (await reader.ReadAsync()) names.Add(reader.GetString(0));
        }
        InternalAcceptanceFingerprint.AssertTables(names);
        var result = new SortedDictionary<string, string>(StringComparer.Ordinal);
        foreach (var name in names)
        {
            await using var command = connection.CreateCommand(); command.CommandText = $"SELECT * FROM [savia_internal].[{name}]";
            await using var reader = await command.ExecuteReaderAsync(); var rows = new List<string>();
            while (await reader.ReadAsync()) rows.Add(string.Join("|", Enumerable.Range(0, reader.FieldCount).Select(i =>
                reader.GetName(i) + "=" + (reader.GetValue(i) switch { DBNull => "NULL", byte[] b => Convert.ToHexString(b),
                    DateTimeOffset t => t.ToString("O", CultureInfo.InvariantCulture), var value => Convert.ToString(value, CultureInfo.InvariantCulture) }))));
            rows.Sort(StringComparer.Ordinal);
            result[name] = rows.Count + ":" + Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(string.Join("\n", rows))));
        }
        return result;
    }
    private sealed class SaveFault(int stage) : SaveChangesInterceptor
    {
        public override ValueTask<int> SavedChangesAsync(SaveChangesCompletedEventData data, int result, CancellationToken ct = default)
        {
            var db = data.Context!;
            if ((stage == 1 && db.ChangeTracker.Entries<InternalStockMovement>().Any(x => x.Entity.Kind == "sale"))
                || (stage == 2 && db.ChangeTracker.Entries<InternalCashEntry>().Any(x => x.Entity.Kind == "sale")))
                throw new StorageUnavailableException();
            return ValueTask.FromResult(result);
        }
    }
    private sealed class CommitFault(bool after) : DbTransactionInterceptor
    {
        public override ValueTask<InterceptionResult> TransactionCommittingAsync(DbTransaction transaction, TransactionEventData data,
            InterceptionResult result, CancellationToken ct = default)
        {
            if (!after) throw new StorageUnavailableException();
            return ValueTask.FromResult(result);
        }
        public override Task TransactionCommittedAsync(DbTransaction transaction, TransactionEndEventData data, CancellationToken ct = default)
        {
            if (after) throw new StorageUnavailableException();
            return Task.CompletedTask;
        }
    }

    [InternalCommerceSqlFact]
    public async Task Closing_report_shows_each_till_with_sales_expected_counted_and_difference()
    {
        await using var f = await InternalCommerceSqlDatabase.Create(migrate: true);
        await Seed(f);
        var open = await Run(f, s => s.Open(new(f.Location, "USD", 1000), f.Actor, "cash-report-open-0001", default));
        Assert.True(open.Success, open.Error);
        var tillId = open.Value!.Till.Id;
        var sale = await Run(f, s => s.Sell(new(tillId, null, [new(f.Item, 2)], "USD", 300), f.Actor, "cash-report-sale-0001", default));
        Assert.True(sale.Success, sale.Error);
        // Count 1240 while the drawer expects 1250: a ten cent shortfall, exactly the case the store reports.
        var close = await Run(f, s => s.Close(tillId, new(1240), f.Actor, "cash-report-close-0001", default));
        Assert.True(close.Success, close.Error);
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var report = await Run(f, s => s.ClosingReport(today.AddDays(-1), today.AddDays(1), default, f.Actor));
        var rows = report.Split("\r\n", StringSplitOptions.RemoveEmptyEntries);
        Assert.Equal(3, rows.Length); // Header, one till, one total.
        Assert.Contains("Esperado", rows[0]);
        var tillRow = rows.Single(row => row.StartsWith("caja;", StringComparison.Ordinal)).Split(';');
        Assert.Equal("caja", tillRow[0]);
        Assert.Equal("12.50", tillRow[8]); // Expected in the drawer.
        Assert.Equal("12.40", tillRow[9]); // Counted.
        Assert.Equal("-0.10", tillRow[10]); // Difference.
        Assert.Equal("cerrada", tillRow[11]);
        Assert.Contains(f.Staff.DisplayName, rows[1]);
        var totalRow = rows.Single(row => row.StartsWith("total;", StringComparison.Ordinal)).Split(';');
        Assert.Equal("12.50", totalRow[8]);
        Assert.Equal("-0.10", totalRow[10]);
        // A window without movements holds no till at all.
        var empty = await Run(f, s => s.ClosingReport(today.AddDays(30), today.AddDays(31), default, f.Actor));
        Assert.Single(empty.Split("\r\n", StringSplitOptions.RemoveEmptyEntries));
    }

    private static async Task Seed(InternalCommerceSqlDatabase f)
    {
        Assert.True((await f.Execute(s => s.Adjust(new(f.Item, f.Location, 20, "synthetic stock"), f.Actor, "cash-stock-item-one-0001", default))).Success);
        Assert.True((await f.Execute(s => s.Adjust(new(f.SecondItem, f.Location, 20, "synthetic stock"), f.Actor, "cash-stock-item-two-0001", default))).Success);
    }
    private static async Task<T> Run<T>(InternalCommerceSqlDatabase f, Func<InternalCashService, Task<T>> action, params IInterceptor[] faults)
    {
        await using var source = f.Context();
        await using var db = new InternalDbContext(new DbContextOptionsBuilder<InternalDbContext>()
            .UseSqlServer(source.Database.GetConnectionString()).AddInterceptors(faults).Options);
        var security = new InternalSecurityService(db, new PasswordHasher<InternalStaff>(), TimeProvider.System);
        var http = new HttpContextAccessor { HttpContext = new DefaultHttpContext { User = InternalSecurityRules.Principal(f.Staff, f.Session) } };
        var runner = new InternalCommandRunner(db, security, http, TimeProvider.System);
        var commerce = new InternalCommerceService(db, runner, new InternalStockLedger(db));
        return await action(new InternalCashService(db, runner, commerce, new("USD", 2), TimeProvider.System));
    }
}
