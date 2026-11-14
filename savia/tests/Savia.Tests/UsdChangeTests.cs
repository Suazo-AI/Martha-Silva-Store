using Microsoft.Data.SqlClient;
using System.Net;
using System.Net.Http.Json;
using System.Text.RegularExpressions;
using Savia.Contracts;

namespace Savia.Tests;

public sealed class UsdChangeTests
{
    private static string Procedure(string path) => Regex.Split(File.ReadAllText(Path.Combine(TestSql.SaviaRoot, path)), @"(?m)^GO\s*$")
        .Single(s => s.TrimStart().StartsWith("CREATE OR ALTER PROCEDURE [sales].[usp_PostSale]")).Trim();

    [Fact]
    public async Task Spec1e_historical_http_replay_and_hash_zero_negative_nonzero()
    {
        await using var f = await UsdFixture.Create();
        await f.Exec(Procedure("db/migrations/V027__usd_cash.sql"));
        await using var node = SaviaNode.BranchA(f.Database);
        var client = await node.SignInAsync(Ids.CashierA, "t_cashier_a");
        var request = new PostSaleRequest(Guid.NewGuid(), f.Till, "NIO", [new(1, Ids.Item, 1, 216100)],
            [new(1, "cash", 216100, ForeignCurrencyCode: "USD", ForeignReceivedMinor: 6000, ExchangeRateId: f.Rate)]);
        var posted = await HttpAssert.OkAsync<SaleResponse>(await client.PostAsJsonAsync("/api/v1/sales", request));
        Assert.Equal(1, await f.Scalar("SELECT COUNT(*) FROM sales.SaleTenders WHERE ForeignChangeMinor IS NULL AND ChangeMinor=3600 AND RoundingMinor=46"));
        await f.Exec(Procedure("db/migrations/V028__usd_change.sql"));
        await f.CleanOracle();
        var zero = request with { Tenders = [request.Tenders[0] with { ForeignChangeMinor = 0 }] };
        Assert.Equal(posted, await HttpAssert.OkAsync<SaleResponse>(await client.PostAsJsonAsync("/api/v1/sales", zero)));
        var changed = request with { Tenders = [request.Tenders[0] with { ForeignChangeMinor = 100 }] };
        Assert.Equal(HttpStatusCode.Conflict, (await client.PostAsJsonAsync("/api/v1/sales", changed)).StatusCode);
        var negative = request with { Tenders = [request.Tenders[0] with { ForeignChangeMinor = -1 }] };
        Assert.Equal(HttpStatusCode.UnprocessableEntity, (await client.PostAsJsonAsync("/api/v1/sales", negative)).StatusCode);
    }

    [Theory]
    [InlineData(1)]
    [InlineData(2)]
    public async Task Spec1e4_full_and_partial_refunds_do_not_return_usd_twice(int quantity)
    {
        await using var f = await UsdFixture.Create(nio: 500000);
        await f.Exec($"UPDATE catalog.Items SET UnitPriceMinor=108050 WHERE Id='{Ids.Item}'");
        await using var node = SaviaNode.BranchA(f.Database);
        var client = await node.SignInAsync(Ids.CashierA, "t_cashier_a");
        var manager = await node.SignInAsync(Ids.Manager, "t_manager");
        var request = new PostSaleRequest(Guid.NewGuid(), f.Till, "NIO", [new(1, Ids.Item, 2, 108050)],
            [new(1, "cash", 216100, ForeignCurrencyCode: "USD", ForeignReceivedMinor: 10000,
                ExchangeRateId: f.Rate, ForeignChangeMinor: 4000)]);
        await HttpAssert.OkAsync(await client.PostAsJsonAsync("/api/v1/sales", request));
        var detail = await HttpAssert.OkAsync<SaleDetailResponse>(await manager.GetAsync($"/api/v1/sales/{request.SaleId}"));
        var refund = new PostReturnOutcomeRequest(Guid.NewGuid(), "cash", f.Till, "Prueba",
            [new(detail.Lines[0].SaleLineId, quantity, "store")]);
        await HttpAssert.OkAsync(await manager.PostAsJsonAsync($"/api/v1/sales/{request.SaleId}/returns/outcome", refund));
        Assert.Equal(-108050 * quantity, await f.Scalar("SELECT SUM(DeltaMinor) FROM sales.CashEntries WHERE Kind='refund'"));
        Assert.Equal(6000, await f.Scalar("SELECT SUM(DeltaMinor) FROM sales.CashEntries WHERE CurrencyCode='USD'"));
        Assert.Equal(4000, detail.Tenders[0].ForeignChangeMinor);
        Assert.Equal(146497, detail.Tenders[0].ForeignChangeNioMinor);
        Assert.Equal(4000, await f.Scalar("SELECT CONVERT(bigint,JSON_VALUE(PayloadJson,'$.tenders[0].ForeignChangeMinor')) FROM sync.Outbox WHERE EventType='sales.sale_posted'"));
        await f.CleanOracle();
    }
    private static Task Sell(UsdFixture f, long amount, long received, long change = 0, long cash = 0, Guid? id = null) =>
        f.Exec($"UPDATE catalog.Items SET UnitPriceMinor={amount + cash},TaxRateBps=0 WHERE Id='{Ids.Item}'; " +
            $"DECLARE @l sales.SaleLineRequest,@t sales.SaleTenderRequest; INSERT @l VALUES(1,'{Ids.Item}',1,{amount + cash},0); " +
            $"INSERT @t VALUES(1,'cash',{amount},NULL,NULL,NULL,NULL); " +
            (cash > 0 ? $"INSERT @t VALUES(2,'cash',{cash},NULL,{cash},0,NULL); " : "") +
            $"EXEC sales.usp_PostSale '{id ?? Guid.NewGuid()}','{Ids.BranchA}','{Ids.LocA}','{Ids.CashierA}','NIO','{Ids.NodeA}',@l,@t," +
            $"@TillId='{f.Till}',@FxJson=N'[{{\"tenderNumber\":1,\"foreignCurrencyCode\":\"USD\",\"foreignReceivedMinor\":{received}," +
            $"\"exchangeRateId\":\"{f.Rate}\",\"foreignChangeMinor\":{change}}}]'");

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Spec1b3_card_and_nio_plus_card_still_work(bool mixed)
    {
        await using var f = await UsdFixture.Create();
        await using var node = SaviaNode.BranchA(f.Database);
        var client = await node.SignInAsync(Ids.CashierA, "t_cashier_a");
        SaleTender[] tenders = mixed
            ? [new(1, "cash", 116100, ReceivedMinor: 116100, ChangeMinor: 0), new(2, "card", 100000)]
            : [new(1, "card", 216100)];
        var request = new PostSaleRequest(Guid.NewGuid(), f.Till, "NIO", [new(1, Ids.Item, 1, 216100)], tenders);
        await HttpAssert.OkAsync(await client.PostAsJsonAsync("/api/v1/sales", request));
        Assert.Equal(0, await f.Scalar("SELECT COUNT(*) FROM sales.CashEntries WHERE CurrencyCode='USD' AND Kind<>'opening'"));
        await f.CleanOracle();
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Spec1c_reject_change_without_usd_and_wrong_client_change(bool wrongClientChange)
    {
        await using var f = await UsdFixture.Create();
        await using var node = SaviaNode.BranchA(f.Database);
        var client = await node.SignInAsync(Ids.CashierA, "t_cashier_a");
        var tender = wrongClientChange
            ? new SaleTender(1, "cash", 216100, ChangeMinor: 3640, ForeignCurrencyCode: "USD",
                ForeignReceivedMinor: 6000, ExchangeRateId: f.Rate)
            : new SaleTender(1, "cash", 216100, ReceivedMinor: 216100, ChangeMinor: 0, ForeignChangeMinor: 0);
        var request = new PostSaleRequest(Guid.NewGuid(), f.Till, "NIO", [new(1, Ids.Item, 1, 216100)], [tender]);
        Assert.Equal(HttpStatusCode.UnprocessableEntity, (await client.PostAsJsonAsync("/api/v1/sales", request)).StatusCode);
        Assert.Equal(0, await f.Scalar("SELECT COUNT(*) FROM sales.Sales"));
        Assert.Equal(0, await f.Scalar("SELECT COUNT(*) FROM sales.SaleTenders"));
        Assert.Equal(0, await f.Scalar("SELECT COUNT(*) FROM sales.CashEntries WHERE Kind<>'opening'"));
        Assert.Equal(0, await f.Scalar("SELECT COUNT(*) FROM sync.Outbox WHERE EventType='sales.sale_posted'"));
        Assert.Equal(20, await f.Scalar($"SELECT OnHand FROM inventory.StockBalances WHERE ItemId='{Ids.Item}' AND Pool='store'"));
    }

    [Fact]
    public async Task Spec1d3_opening_rows_are_unfiltered_and_duplicate_sale_is_rejected()
    {
        await using var f = await UsdFixture.Create();
        Assert.Equal(2, await f.Scalar("SELECT COUNT(*) FROM sales.CashEntries WHERE Kind='opening' AND SaleTenderId IS NULL"));
        await Sell(f, 216100, 10000, 4000);
        var error = await Assert.ThrowsAsync<SqlException>(() => f.Exec(
            "INSERT sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy) " +
            "SELECT NEWID(),TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy FROM sales.CashEntries WHERE Kind='sale'"));
        Assert.Contains(error.Number, new[] { 2601, 2627 });
        await f.CleanOracle();
    }

    [Theory]
    [InlineData(216100, 6000, 0, 3645, 1)]
    [InlineData(216100, 10000, 4000, 3645, 1)]
    [InlineData(216100, 5925, 0, 895, 4)]
    [InlineData(3637, 100, 0, 25, 0)]
    [InlineData(183121, 10000, 5000, 0, 0)]
    [InlineData(183122, 5000, 0, 0, 0)]
    public async Task Spec01_1a_1b_1c3(long amount, long received, long usdChange, long nioChange, long rounding)
    {
        await using var f = await UsdFixture.Create(nio: 500000);
        await Sell(f, amount, received, usdChange);
        Assert.Equal(nioChange, await f.Scalar("SELECT ChangeMinor FROM sales.SaleTenders"));
        Assert.Equal(rounding, await f.Scalar("SELECT RoundingMinor FROM sales.SaleTenders"));
        Assert.Equal(usdChange, await f.Scalar("SELECT ForeignChangeMinor FROM sales.SaleTenders"));
        Assert.Equal(received - usdChange, await f.Scalar("SELECT SUM(DeltaMinor) FROM sales.CashEntries WHERE CurrencyCode='USD'"));
        await f.CleanOracle();
    }

    [Fact]
    public async Task Spec1b2_1c2_coin_lattice_and_edges()
    {
        await using var f = await UsdFixture.Create(nio: 500000);
        await f.Exec($"EXEC test.SeedStock '{Ids.Item}','{Ids.LocA}',100;");
        for (var r = -100; r <= 30; r++)
        {
            if (r < -1 && r > -99) continue;
            var id = Guid.NewGuid();
            if (r == -100) { await Assert.ThrowsAsync<SqlException>(() => Sell(f, 3662 - r, 100)); continue; }
            var formable = Enumerable.Range(0, Math.Max(0, r) + 1)
                .Where(c => Enumerable.Range(0, c / 25 + 1).Any(q => (c - q * 25) % 10 == 0)).Max();
            await Sell(f, 3662 - r, 100, id: id);
            Assert.Equal(formable, await f.Scalar($"SELECT ChangeMinor FROM sales.SaleTenders WHERE SaleId='{id}'"));
        }
        await f.CleanOracle();
    }

    [Theory]
    [InlineData(216100, 10000, -1)]
    [InlineData(216100, 10000, 10000)]
    [InlineData(216100, 10000, 4102)]
    [InlineData(216100, 5900, 1)]
    [InlineData(216100, 10000, 5000)]
    public async Task Spec1c_rejections_have_no_effect(long amount, long received, long change)
    {
        await using var f = await UsdFixture.Create();
        await Assert.ThrowsAsync<SqlException>(() => Sell(f, amount, received, change));
        Assert.Equal(0, await f.Scalar("SELECT COUNT(*) FROM sales.Sales"));
        Assert.Equal(0, await f.Scalar("SELECT COUNT(*) FROM sales.SaleTenders"));
        Assert.Equal(0, await f.Scalar("SELECT COUNT(*) FROM sales.CashEntries WHERE Kind<>'opening'"));
        Assert.Equal(0, await f.Scalar("SELECT COUNT(*) FROM sync.Outbox WHERE EventType='sales.sale_posted'"));
        Assert.Equal(20, await f.Scalar($"SELECT OnHand FROM inventory.StockBalances WHERE ItemId='{Ids.Item}' AND Pool='store'"));
    }

    [Fact]
    public async Task Spec1d2_same_sale_nio_cash_funds_change()
    {
        await using var f = await UsdFixture.Create(nio: 5000);
        await Sell(f, 100000, 6000, cash: 116100);
        Assert.Equal(119745, await f.Scalar("SELECT ChangeMinor FROM sales.SaleTenders WHERE ForeignCurrencyCode='USD'"));
        Assert.Equal(1355, await f.Scalar($"SELECT SUM(DeltaMinor) FROM sales.CashEntries WHERE TillId='{f.Till}'"));
        await f.CleanOracle();
    }

    [Fact]
    public async Task Spec1e2_second_change_failure_rolls_back()
    {
        await using var f = await UsdFixture.Create();
        await f.Exec("CREATE TRIGGER sales.test_change_failure ON sales.CashEntries AFTER INSERT AS " +
            "IF EXISTS(SELECT 1 FROM inserted WHERE Kind='change' AND CurrencyCode='USD') THROW 59099,'forced second change',1;");
        var error = await Assert.ThrowsAsync<SqlException>(() => Sell(f, 216100, 10000, 4000));
        Assert.Equal(59099, error.Number);
        Assert.Equal(0, await f.Scalar("SELECT COUNT(*) FROM sales.Sales"));
        Assert.Equal(0, await f.Scalar("SELECT COUNT(*) FROM sales.SaleTenders"));
        Assert.Equal(0, await f.Scalar("SELECT COUNT(*) FROM sales.CashEntries WHERE Kind<>'opening'"));
        Assert.Equal(20, await f.Scalar($"SELECT OnHand FROM inventory.StockBalances WHERE ItemId='{Ids.Item}' AND Pool='store'"));
        Assert.Equal(0, await f.Scalar("SELECT COUNT(*) FROM sync.Outbox WHERE EventType='sales.sale_posted'"));
    }

    [Fact]
    public async Task Spec1e3_close_nets_usd_change()
    {
        await using var f = await UsdFixture.Create();
        await Sell(f, 216100, 10000, 4000);
        await f.CountAndClose();
        Assert.Equal(6000, await f.Scalar("SELECT ExpectedMinor FROM sales.CashClosures c JOIN sales.CashTills t ON t.Id=c.TillId WHERE t.CurrencyCode='USD'"));
        Assert.Equal(1, await f.Scalar("SELECT AmountMinor FROM accounting.CloseDocumentLines WHERE ConceptCode='CASH_ROUNDING'"));
        await f.CleanOracle();
    }

    [Theory]
    [InlineData(50)]
    [InlineData(25)]
    [InlineData(10)]
    [InlineData(5)]
    [InlineData(1)]
    public async Task Spec1f_usd_coins_count_and_replay(int coin)
    {
        var lines = $"[{{\"denominationMinor\":{coin},\"quantity\":5}},{{\"denominationMinor\":100,\"quantity\":5}}]";
        await using var f = await UsdFixture.Create(usdLines: lines);
        var sql = f.CountSql(f.Count, f.Till) + $",@UsdLinesJson=N'{lines}',@UsdCashCountId='{f.UsdCount}'";
        await f.Exec(sql);
        await f.Exec(sql);
        await f.Close();
        await f.Close();
        Assert.Equal(500 + coin * 5, await f.Scalar("SELECT ExpectedMinor FROM sales.CashClosures c JOIN sales.CashTills t ON t.Id=c.TillId WHERE t.CurrencyCode='USD'"));
        await f.CleanOracle();
    }

    [Theory]
    [InlineData("ReceivedMinor=NULL")]
    [InlineData("ChangeMinor=-5,RoundingMinor=3651")]
    [InlineData("ForeignChangeMinor=-1")]
    [InlineData("ChangeMinor=5,RoundingMinor=3641")]
    public async Task Spec_constraints_reject_null_negative_and_unformable(string mutation)
    {
        await using var f = await UsdFixture.Create();
        await Sell(f, 216100, 6000);
        var error = await Assert.ThrowsAsync<SqlException>(() => f.Exec("UPDATE sales.SaleTenders SET " + mutation));
        Assert.Equal(547, error.Number);
        await f.CleanOracle();
    }

    [Theory]
    [InlineData("amount")]
    [InlineData("currency")]
    [InlineData("till")]
    [InlineData("extra")]
    public async Task Spec1e5_oracle_detects_usd_change_corruption(string mutation)
    {
        await using var f = await UsdFixture.Create();
        await Sell(f, 216100, 10000, 4000);
        await f.CleanOracle();
        if (mutation is "currency" or "till") await f.Exec("ALTER TABLE sales.CashEntries NOCHECK CONSTRAINT FK_CashEntries_TillCurrency");
        if (mutation == "amount") await f.Exec("UPDATE sales.CashEntries SET DeltaMinor=-3999 WHERE Kind='change' AND CurrencyCode='USD'");
        if (mutation == "currency") await f.Exec("UPDATE sales.CashEntries SET CurrencyCode='NIO' WHERE Kind='change' AND CurrencyCode='USD'");
        if (mutation == "till") await f.Exec($"DROP INDEX UX_CashEntries_Change ON sales.CashEntries; UPDATE sales.CashEntries SET TillId='{f.Till}' WHERE Kind='change' AND CurrencyCode='USD'");
        if (mutation == "extra") await f.Exec("DROP INDEX UX_CashEntries_Change ON sales.CashEntries; " +
            "INSERT sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy) " +
            "SELECT NEWID(),TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy FROM sales.CashEntries WHERE Kind='change' AND CurrencyCode='USD'");
        await Assert.ThrowsAsync<SqlException>(() => f.Exec("EXEC audit.usp_CheckConservation @Throw=1"));
    }
}
