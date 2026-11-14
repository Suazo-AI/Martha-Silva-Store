using Microsoft.Data.SqlClient;

namespace Savia.Tests;

public sealed class UsdCashTests
{
    [Theory]
    [InlineData(6000, 219746, 3645, 1)]
    [InlineData(5900, 216083, 0, -17)]
    public async Task Spec01_02_conversion_and_physical_cash(long dollars, long received, long change, long rounding)
    {
        await using var f = await UsdFixture.Create();
        await f.Sale(dollars);
        Assert.Equal(received, await f.Scalar("SELECT ReceivedMinor FROM sales.SaleTenders"));
        Assert.Equal(change, await f.Scalar("SELECT ChangeMinor FROM sales.SaleTenders"));
        Assert.Equal(rounding, await f.Scalar("SELECT RoundingMinor FROM sales.SaleTenders"));
        Assert.Equal(dollars, await f.Scalar("SELECT DeltaMinor FROM sales.CashEntries WHERE Kind='sale'"));
        Assert.Equal(100000 - change, await f.Scalar($"SELECT SUM(DeltaMinor) FROM sales.CashEntries WHERE TillId='{f.Till}'"));
        await f.CleanOracle();
    }

    [Fact]
    public async Task Spec03_mixed_cash()
    {
        await using var f = await UsdFixture.Create();
        await f.Sale(2000, amount: 73249, remainder: 142851);
        Assert.Equal(216100, await f.Scalar("SELECT SUM(AmountMinor) FROM sales.SaleTenders"));
        await f.CleanOracle();
    }

    [Theory]
    [InlineData("stale")]
    [InlineData("missing")]
    [InlineData("received")]
    [InlineData("duplicate")]
    [InlineData("card")]
    [InlineData("short")]
    [InlineData("change")]
    public async Task Spec04_rejections_have_no_effect(string kind)
    {
        await using var f = await UsdFixture.Create();
        if (kind == "missing") await f.Exec("DISABLE TRIGGER core.tr_ExchangeRates_Immutable ON core.ExchangeRates; DELETE core.ExchangeRates");
        if (kind == "stale") await f.Exec("DISABLE TRIGGER core.tr_ExchangeRates_Immutable ON core.ExchangeRates; UPDATE " +
            "core.ExchangeRates SET EffectiveFrom=DATEADD(day,1,EffectiveFrom)");
        if (kind == "change") await f.Exec($"UPDATE sales.CashEntries SET DeltaMinor=0 WHERE TillId='{f.Till}'");
        await Assert.ThrowsAsync<SqlException>(() => f.Sale(kind == "short" ? 5800 : 6000,
            received: kind == "received" ? 1 : null, duplicate: kind == "duplicate", card: kind == "card"));
        Assert.Equal(0, await f.Scalar("SELECT COUNT(*) FROM sales.Sales"));
        Assert.Equal(0, await f.Scalar("SELECT COUNT(*) FROM sales.SaleTenders"));
        Assert.Equal(0, await f.Scalar("SELECT COUNT(*) FROM sales.CashEntries WHERE Kind<>'opening'"));
        Assert.Equal(0, await f.Scalar("SELECT COUNT(*) FROM sync.Outbox WHERE EventType='sales.sale_posted'"));
        Assert.Equal(20, await f.Scalar($"SELECT OnHand FROM inventory.StockBalances WHERE ItemId='{Ids.Item}' AND Pool='store'"));
    }

    [Fact]
    public async Task Spec05_concurrent_change_is_serialized()
    {
        await using var f = await UsdFixture.Create(nio: 5000);
        async Task<bool> Attempt() { try { await f.Sale(6000); return true; } catch (SqlException) { return false; } }
        var results = await Task.WhenAll(Attempt(), Attempt());
        Assert.Single(results, x => x);
        await f.CleanOracle();
    }

    [Fact]
    public async Task Spec06_replay_after_rate_change_and_close_conflicts_on_changed_dollars()
    {
        await using var f = await UsdFixture.Create();
        var sale = Guid.NewGuid();
        await f.Sale(6000, sale);
        // Shift only fixture history so a second rate can become current without changing its saved value.
        await f.Exec("DISABLE TRIGGER core.tr_ExchangeRates_Immutable ON core.ExchangeRates; " +
            "UPDATE core.ExchangeRates SET EffectiveFrom=DATEADD(day,-1,EffectiveFrom); " +
            "ENABLE TRIGGER core.tr_ExchangeRates_Immutable ON core.ExchangeRates;");
        await f.Exec($"INSERT core.ExchangeRates(Id,CurrencyCode,EffectiveFrom,Rate,SetBy,Reason) " +
            $"VALUES(NEWID(),'USD',CAST(DATEADD(hour,-6,core.ufn_BusinessNow()) AS date),37,'{Ids.Manager}',N'Prueba');");
        await f.Sale(6000, sale);
        await f.CountAndClose();
        await f.Sale(6000, sale);
        await f.Close();
        await Assert.ThrowsAsync<SqlException>(() => f.Sale(6100, sale));
        Assert.Equal(1, await f.Scalar("SELECT COUNT(*) FROM sales.Sales"));
        Assert.Equal(2, await f.Scalar("SELECT COUNT(*) FROM accounting.CloseDocuments"));
        Assert.Equal(2, await f.Scalar("SELECT COUNT(*) FROM sync.Outbox WHERE EventType='cash.till_closed'"));
        await f.CleanOracle();
    }

    [Fact]
    public async Task Spec07_sale_and_close_are_atomic()
    {
        await using var f = await UsdFixture.Create();
        await f.Counts();
        async Task Sell() { try { await f.Sale(6000); } catch (SqlException) { } }
        await Task.WhenAll(Sell(), f.Close());
        Assert.Equal(2, await f.Scalar("SELECT COUNT(*) FROM sales.CashTills WHERE Status='closed'"));
        await f.CleanOracle();
    }

    [Fact]
    public async Task Spec08_open_rolls_back_and_close_requires_both_counts()
    {
        await using var f = await UsdFixture.Create();
        await Assert.ThrowsAsync<SqlException>(() => f.Exec(f.OpenSql(Guid.NewGuid(), "[{\"denominationMinor\":3,\"quantity\":1}]")
            .Replace(Ids.RegisterA.ToString(), Ids.RegisterB.ToString()).Replace(Ids.CashierA.ToString(), Ids.CashierB.ToString())
            .Replace(Ids.NodeA.ToString(), Ids.NodeB.ToString())));
        Assert.Equal(2, await f.Scalar("SELECT COUNT(*) FROM sales.CashTills"));
        await f.Exec(f.CountSql(f.Count, f.Till));
        await Assert.ThrowsAsync<SqlException>(f.Close);
        Assert.Equal(2, await f.Scalar("SELECT COUNT(*) FROM sales.CashTills WHERE Status='open'"));
    }

    [Fact]
    public async Task Spec09_expected_cash_by_currency()
    {
        await using var f = await UsdFixture.Create(usd: 100);
        await f.Sale(6000);
        await f.CountAndClose();
        Assert.Equal(6100, await f.Scalar("SELECT ExpectedMinor FROM sales.CashClosures c JOIN sales.CashTills t ON t.Id=c.TillId WHERE t.CurrencyCode='USD'"));
        Assert.Equal(96355, await f.Scalar("SELECT ExpectedMinor FROM sales.CashClosures c JOIN sales.CashTills t ON t.Id=c.TillId " +
            "WHERE t.CurrencyCode='NIO'"));
        Assert.Equal(3, await f.Scalar("SELECT COUNT(*) FROM accounting.CloseDocumentLines l " +
            "JOIN accounting.CloseDocuments d ON d.Id=l.CloseDocumentId WHERE d.CurrencyCode='USD'"));
        Assert.Equal(1, await f.Scalar("SELECT AmountMinor FROM accounting.CloseDocumentLines WHERE ConceptCode='CASH_ROUNDING'"));
    }

    [Fact]
    public async Task Spec10_child_till_is_internal()
    {
        await using var f = await UsdFixture.Create();
        var child = await f.Child();
        foreach (var kind in new[] { "payout", "deposit", "adjustment" })
            await Assert.ThrowsAsync<SqlException>(() => f.Exec($"EXEC sales.usp_RecordCashEntry " +
                $"'{Guid.NewGuid()}','{child}','{Ids.CashierA}','{kind}',100,N'Prueba','{Ids.NodeA}'"));
        await Assert.ThrowsAsync<SqlException>(() => f.Sale(6000, till: child));
        var error = await Assert.ThrowsAsync<SqlException>(() => f.Exec(
            $"DECLARE @lines sales.ReturnLineRequest; EXEC sales.usp_PostCreditReturn @ReversalId='{Guid.NewGuid()}'," +
            $"@SaleId='{Guid.NewGuid()}',@CreditId='{Guid.NewGuid()}',@BranchId='{Ids.BranchA}',@TillId='{child}'," +
            $"@ReturnLocationId='{Ids.LocA}',@ActorId='{Ids.CashierA}',@ApprovedBy='{Ids.Manager}',@CustomerId=NULL,@Reason=N'Prueba'," +
            $"@OriginNodeId='{Ids.NodeA}',@Lines=@lines"));
        Assert.Equal(52106, error.Number);
        await Assert.ThrowsAsync<SqlException>(() => f.Exec($"EXEC sales.usp_CloseTill " +
            $"'{Guid.NewGuid()}','{child}','{Guid.NewGuid()}','{Ids.Manager}','{Ids.NodeA}'"));
    }

    [Fact]
    public async Task Spec12_count_replay_conflicts_in_both_currencies()
    {
        await using var f = await UsdFixture.Create();
        await f.Counts();
        await f.Counts();
        await Assert.ThrowsAsync<SqlException>(() => f.Exec(f.CountSql(f.Count, f.Till, 1)));
        await Assert.ThrowsAsync<SqlException>(() => f.Exec(f.CountSql(f.Count, f.Till) +
            $",@UsdCashCountId='{f.UsdCount}',@UsdLinesJson=N'[{{\"denominationMinor\":100,\"quantity\":1}}]'"));
    }
}
