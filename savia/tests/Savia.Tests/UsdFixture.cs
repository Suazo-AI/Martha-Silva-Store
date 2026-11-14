using Microsoft.Data.SqlClient;

namespace Savia.Tests;

internal sealed class UsdFixture(string database) : IAsyncDisposable
{
    public string Database => database;
    public Guid Till { get; } = Guid.NewGuid();
    public Guid Rate { get; } = Guid.NewGuid();
    public Guid Count { get; } = Guid.NewGuid();
    public Guid UsdCount { get; } = Guid.NewGuid();
    public Guid Closure { get; } = Guid.NewGuid();

    public static async Task<UsdFixture> Create(long nio = 100000, long usd = 0, string? usdLines = null)
    {
        var f = new UsdFixture(await TestSql.CloneAsync("usd"));
        try
        {
            await f.Exec($"UPDATE catalog.Items SET UnitPriceMinor=216100,TaxRateBps=0 WHERE Id='{Ids.Item}'; EXEC " +
                $"test.SeedStock '{Ids.Item}','{Ids.LocA}',20;");
            await f.Exec(f.OpenSql(f.Till, usdLines ?? $"[{{\"denominationMinor\":100,\"quantity\":{usd / 100}}}]", nio));
            await f.Exec($"INSERT core.ExchangeRates(Id,CurrencyCode,EffectiveFrom,Rate,SetBy,Reason) " +
                $"VALUES('{f.Rate}','USD',CAST(DATEADD(hour,-6,core.ufn_BusinessNow()) AS " +
                $"date),36.6243,'{Ids.Manager}',N'Prueba');");
            return f;
        }
        catch { await f.DisposeAsync(); throw; }
    }

    public Task Exec(string text) => Execute(text);
    private async Task Execute(string text)
    {
        await using var connection = new SqlConnection(TestSql.ConnectionFor(database));
        await connection.OpenAsync();
        await using var command = new SqlCommand(text, connection) { CommandTimeout = 60 };
        await command.ExecuteNonQueryAsync();
    }
    public async Task<long> Scalar(string text) => await TestSql.ScalarAsync<long>(database, text);
    public async Task<Guid> Child() => Guid.Parse(await TestSql.ScalarAsync<string>(database,
        $"SELECT CONVERT(varchar(36),Id) FROM sales.CashTills WHERE ParentTillId='{Till}'"));
    public string OpenSql(Guid id, string usd = "[{\"denominationMinor\":100,\"quantity\":0}]", long nio = 100000) =>
        $"EXEC sales.usp_OpenTillCounted " +
            $"'{id}','{Ids.RegisterA}','{Ids.CashierA}','NIO',{nio},'{Ids.NodeA}'," +
            $"N'[{{\"denominationMinor\":100,\"quantity\":{nio / 100}}}]',@UsdLinesJson=N'{usd}'";
    public string CountSql(Guid id, Guid till, int quantity = 0) =>
        $"EXEC sales.usp_RecordCashCount '{id}','{till}','{Ids.CashierA}',N'[{{\"denominationMinor\":100,\"quantity\":{quantity}}}]'";
    public async Task Counts()
    {
        await Exec(CountSql(Count, Till));
        await Exec(CountSql(Count, Till) + $",@UsdLinesJson=N'[{{\"denominationMinor\":100,\"quantity\":0}}]',@UsdCashCountId='{UsdCount}'");
    }
    public Task Close() => Exec($"EXEC sales.usp_CloseTill '{Closure}','{Till}','{Count}','{Ids.Manager}','{Ids.NodeA}',@UsdCashCountId='{UsdCount}'");
    public async Task CountAndClose() { await Counts(); await Close(); }
    public Task Sale(long dollars, Guid? id = null, long amount = 216100, long remainder = 0,
        long? received = null, bool duplicate = false, bool card = false, Guid? till = null)
    {
        var fx = new { tenderNumber = 1, foreignCurrencyCode = "USD", foreignReceivedMinor = dollars, exchangeRateId = Rate };
        var json = System.Text.Json.JsonSerializer.Serialize(duplicate ? new[] { fx, fx } : new[] { fx });
        return Exec($"DECLARE @l sales.SaleLineRequest,@t sales.SaleTenderRequest; " +
            $"INSERT @l VALUES(1,'{Ids.Item}',1,216100,0); " +
            $"INSERT @t VALUES(1,'{(card ? "card" : "cash")}',{amount},NULL,{received?.ToString() ?? "NULL"},NULL,NULL); " +
            (remainder > 0 ? $"INSERT @t VALUES(2,'cash',{remainder},NULL,{remainder},0,NULL); " : "") +
            $"EXEC sales.usp_PostSale '{id ?? Guid.NewGuid()}','{Ids.BranchA}','{Ids.LocA}','{Ids.CashierA}','NIO','{Ids.NodeA}',@l,@t," +
            $"@TillId='{till ?? Till}',@FxJson=N'{json}'");
    }
    public async Task CleanOracle() => Assert.Equal(0, await Scalar("DECLARE @v TABLE(CheckName varchar(100),KeyText nvarchar(250),Expected bigint,Actual " +
        "bigint); INSERT @v EXEC audit.usp_CheckConservation; SELECT COUNT(*) FROM @v"));
    public ValueTask DisposeAsync() => new(TestSql.DropAsync(database));
}
