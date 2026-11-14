using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using Savia.Contracts;

namespace Savia.Tests;

public sealed class UsdAcceptanceTests
{
    [Fact]
    public async Task Spec11_exchange_rejects_fx_and_cash_refund_uses_parent()
    {
        await using var f = await UsdFixture.Create();
        var sale = Guid.NewGuid();
        await f.Sale(6000, sale);
        await using var node = SaviaNode.BranchA(f.Database);
        var manager = await node.SignInAsync(Ids.Manager, "t_manager");
        var detail = await HttpAssert.OkAsync<SaleDetailResponse>(await manager.GetAsync($"/api/v1/sales/{sale}"));
        var request = new PostReturnOutcomeRequest(Guid.NewGuid(), "exchange", f.Till, "Prueba",
            [new(detail.Lines[0].SaleLineId, 1, "store")], ExchangeSaleId: Guid.NewGuid(),
            NewLines: [new(1, Ids.Item, 1, 216100)],
            NewTenders: [new(1, "cash", 216100, ForeignCurrencyCode: "USD", ForeignReceivedMinor: 6000, ExchangeRateId: f.Rate)]);
        Assert.Equal(HttpStatusCode.UnprocessableEntity,
            (await manager.PostAsJsonAsync($"/api/v1/sales/{sale}/returns/outcome", request)).StatusCode);
        var refund = request with { Outcome = "cash", ExchangeSaleId = null, NewLines = null, NewTenders = null };
        await f.Exec($"EXEC sales.usp_RecordCashEntry '{Guid.NewGuid()}','{f.Till}','{Ids.Manager}','deposit',300000,N'Prueba','{Ids.NodeA}'");
        await HttpAssert.OkAsync(await manager.PostAsJsonAsync($"/api/v1/sales/{sale}/returns/outcome", refund));
        Assert.Equal(-216100, await f.Scalar($"SELECT DeltaMinor FROM sales.CashEntries WHERE Kind='refund' AND TillId='{f.Till}'"));
        await f.CleanOracle();
    }

    [Fact]
    public async Task Spec13_kpis_keep_currencies_separate_and_count_parent_once()
    {
        await using var f = await UsdFixture.Create(usd: 100);
        await f.Exec(f.CountSql(f.Count, f.Till, 999) +
            $",@UsdCashCountId='{f.UsdCount}',@UsdLinesJson=N'[{{\"denominationMinor\":100,\"quantity\":0}}]'");
        await f.Close();
        await f.CleanOracle();
        await using var node = SaviaNode.BranchA(f.Database);
        var manager = await node.SignInAsync(Ids.Manager, "t_manager");
        var date = DateTime.UtcNow.AddHours(-6).ToString("yyyy-MM-dd");
        var report = await HttpAssert.OkAsync<JsonElement>(await manager.GetAsync($"/api/v1/reports/kpi/business?period=day&date={date}"));
        Assert.Equal(1, report.GetProperty("tillClosures").GetInt32());
        Assert.Equal(-100, report.GetProperty("tillDifferenceMinor").GetInt64());
        Assert.Equal(-100, report.GetProperty("usdTillDifferenceMinor").GetInt64());
        var team = await HttpAssert.OkAsync<JsonElement>(await manager.GetAsync($"/api/v1/reports/kpi/team?period=day&date={date}"));
        var closer = team.GetProperty("managers").EnumerateArray().Single(x => x.GetProperty("staffId").GetGuid() == Ids.Manager);
        Assert.Equal(1, closer.GetProperty("tillClosures").GetInt32());
        Assert.Equal(-100, closer.GetProperty("tillDifferenceMinor").GetInt64());
        Assert.Equal(-100, closer.GetProperty("usdTillDifferenceMinor").GetInt64());
        var day = await HttpAssert.OkAsync<DayReport>(await manager.GetAsync($"/api/v1/reports/day?date={date}"));
        Assert.Equal(-100, Assert.Single(day.Tills).UsdDifferenceMinor);
    }

    [Fact]
    public async Task Spec14_rate_permissions_dates_and_future_rate()
    {
        await using var f = await UsdFixture.Create();
        await using var node = SaviaNode.BranchA(f.Database);
        var cashier = await node.SignInAsync(Ids.CashierA, "t_cashier_a");
        var manager = await node.SignInAsync(Ids.Manager, "t_manager");
        var today = DateOnly.FromDateTime(DateTime.UtcNow.AddHours(-6));
        var request = new ExchangeRateRequest(Guid.NewGuid(), today.AddDays(1), 37, "Prueba");
        Assert.Equal(HttpStatusCode.Forbidden, (await cashier.PostAsJsonAsync("/api/v1/exchange-rates", request)).StatusCode);
        await HttpAssert.OkAsync(await manager.PostAsJsonAsync("/api/v1/exchange-rates", request));
        Assert.False((await manager.PostAsJsonAsync("/api/v1/exchange-rates", request with { Id = Guid.NewGuid() })).IsSuccessStatusCode);
        var past = request with { Id = Guid.NewGuid(), EffectiveFrom = today.AddDays(-1) };
        Assert.False((await manager.PostAsJsonAsync("/api/v1/exchange-rates", past)).IsSuccessStatusCode);
        var current = await HttpAssert.OkAsync<ExchangeRateResponse>(await manager.GetAsync("/api/v1/exchange-rate"));
        Assert.Equal(36.6243m, current.Rate);
        var supervisor = await node.SignInAsync(Ids.SupervisorA, "t_super_a");
        await HttpAssert.OkAsync(await supervisor.PostAsJsonAsync("/api/exchange-rates",
            request with { Id = Guid.NewGuid(), EffectiveFrom = today.AddDays(2) }));
        await Assert.ThrowsAsync<SqlException>(() => f.Exec("UPDATE core.ExchangeRates SET Rate=38"));
    }

    [Theory]
    [InlineData("amount")]
    [InlineData("till")]
    [InlineData("change")]
    [InlineData("rate")]
    public async Task Spec15_oracle_detects_corruption(string kind)
    {
        await using var f = await UsdFixture.Create();
        await f.Sale(6000);
        await f.CleanOracle();
        if (kind == "amount") await f.Exec("UPDATE sales.CashEntries SET DeltaMinor=DeltaMinor+100 WHERE Kind='sale'");
        if (kind == "till")
        {
            var other = Guid.NewGuid();
            await f.Exec(f.OpenSql(other).Replace(Ids.RegisterA.ToString(), Ids.RegisterB.ToString())
                .Replace(Ids.CashierA.ToString(), Ids.CashierB.ToString()).Replace(Ids.NodeA.ToString(), Ids.NodeB.ToString()));
            await f.Exec($"UPDATE sales.CashEntries SET TillId=(SELECT Id FROM sales.CashTills WHERE ParentTillId='{other}') WHERE Kind='sale'");
        }
        if (kind == "rate") await f.Exec("DISABLE TRIGGER core.tr_ExchangeRates_Immutable ON core.ExchangeRates; UPDATE core.ExchangeRates SET Rate=37");
        if (kind == "change") await f.Exec("DROP INDEX UX_CashEntries_Change ON sales.CashEntries; " +
            "INSERT sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy) " +
            "SELECT NEWID(),TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy FROM sales.CashEntries WHERE Kind='change'");
        Assert.True(await f.Scalar("DECLARE @v TABLE(CheckName varchar(100),KeyText nvarchar(250),Expected bigint,Actual " +
            "bigint); INSERT @v EXEC audit.usp_CheckConservation; SELECT COUNT(*) FROM @v") > 0);
    }

    [Fact]
    public async Task Spec16_detail_and_event_preserve_conversion()
    {
        await using var f = await UsdFixture.Create();
        var sale = Guid.NewGuid();
        await using var node = SaviaNode.BranchA(f.Database);
        var manager = await node.SignInAsync(Ids.Manager, "t_manager");
        var cashier = await node.SignInAsync(Ids.CashierA, "t_cashier_a");
        var request = new PostSaleRequest(sale, f.Till, "NIO", [new(1, Ids.Item, 1, 216100)],
            [new(1, "cash", 216100, ForeignCurrencyCode: "USD", ForeignReceivedMinor: 6000, ExchangeRateId: f.Rate)]);
        var posted = await HttpAssert.OkAsync<SaleResponse>(await cashier.PostAsJsonAsync("/api/v1/sales", request));
        var replay = await HttpAssert.OkAsync<SaleResponse>(await cashier.PostAsJsonAsync("/api/v1/sales", request));
        Assert.Equal(posted, replay);
        var detail = await HttpAssert.OkAsync<SaleDetailResponse>(await manager.GetAsync($"/api/v1/sales/{sale}"));
        Assert.Equal(6000, detail.Tenders[0].ForeignReceivedMinor);
        Assert.Equal(1, detail.Tenders[0].RoundingMinor);
        Assert.Equal(f.Rate, detail.Tenders[0].ExchangeRateId);
        Assert.Equal(36.6243m, detail.Tenders[0].ExchangeRate);
        Assert.Equal(6000, await f.Scalar("SELECT CONVERT(bigint,JSON_VALUE(PayloadJson,'$.tenders[0].ForeignReceivedMinor')) FROM " +
            "sync.Outbox WHERE EventType='sales.sale_posted'"));
    }
}
