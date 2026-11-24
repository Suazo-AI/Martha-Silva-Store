using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.DependencyInjection;
using Savia.Api;
using Savia.Contracts;

namespace Savia.Tests;

/// <summary>
/// A hub over real SQL with web stock to sell: branch A hands <see cref="WebUnits"/> units to the web, as in
/// db/tests/webstore/080, and a fake hosted card page stands in for the bank. The web-order test classes share it.
/// </summary>
public abstract class WebOrderHub : IAsyncLifetime
{
    protected const int WebUnits = 2;
    private string _db = "";
    protected SaviaNode Hub { get; private set; } = null!;
    protected FakeHostedGateway Gateway { get; } = new();
    protected string Sku { get; private set; } = "";

    public async Task InitializeAsync()
    {
        _db = await TestSql.CloneAsync("weborder");
        // The branch consigns to the web, then the database becomes the hub and credits it.
        await Exec($"""
            DECLARE @a uniqueidentifier=test.Id('nodeA'),@cloud uniqueidentifier=test.Id('nodeCloud'),@item uniqueidentifier=test.Id('item'),
              @locA uniqueidentifier=test.Id('locA'),@manager uniqueidentifier=test.Id('manager'),@c uniqueidentifier=NEWID();
            EXEC sync.usp_SetLocalNode @NodeId=@a;
            EXEC test.SeedStock @item,@locA,5;
            EXEC inventory.usp_ConsignToWeb @ConsignmentId=@c,@ItemId=@item,@FromLocationId=@locA,@Quantity={WebUnits},@ActorId=@manager;
            UPDATE sync.LocalNode SET NodeId=@cloud;
            EXEC inventory.usp_ApplyWebConsignments;
            """);
        Sku = await TestSql.ScalarAsync<string>(_db, $"SELECT Sku FROM catalog.Items WHERE Id='{Ids.Item}'");
        Hub = new SaviaNode(_db, Domain.NodeKind.Cloud, Ids.NodeCloud, null, null, new Dictionary<string, string?>
        {
            ["Savia:Public:BotCheck"] = "disabled",
            ["Savia:Public:OrderPageUrl"] = "https://tienda.example/pedido",
            ["Savia:WebStore:SweepSeconds"] = "0",
        });
    }

    public async Task DisposeAsync()
    {
        await Hub.DisposeAsync();
        await TestSql.DropAsync(_db);
    }

    protected WebApplicationFactory<Program> WithGateway() =>
        Hub.WithWebHostBuilder(b => b.ConfigureTestServices(s => s.AddSingleton<IPaymentProvider>(Gateway)));

    protected HttpRequestMessage Order(Guid key, string email, int qty, string provider, string turnstile = "token") =>
        new(HttpMethod.Post, "/api/v1/public/orders")
        {
            Content = JsonContent.Create(new
            {
                lines = new[] { new { sku = Sku, qty } },
                contact = new { name = "Compradora", email },
                shipping = new { zone = "managua", address = "Calle 1", city = "Managua" },
                provider,
                turnstileToken = turnstile,
            }),
            Headers = { { "Idempotency-Key", key.ToString() } },
        };

    protected async Task<PublicOrderCreated> PlaceAsync(HttpClient client, string email, int qty, string provider)
    {
        var response = await client.SendAsync(Order(Guid.NewGuid(), email, qty, provider));
        Assert.True(response.StatusCode == HttpStatusCode.Created, await response.Content.ReadAsStringAsync());
        return (await response.Content.ReadFromJsonAsync<PublicOrderCreated>())!;
    }

    protected static HttpRequestMessage Webhook(string body, string signature) =>
        new(HttpMethod.Post, "/api/v1/public/payments/fakecard/webhook")
        {
            Content = new StringContent(body, Encoding.UTF8, "application/json"),
            Headers = { { FakeHostedGateway.SignatureHeader, signature } },
        };

    /// <summary>A correctly signed webhook for the order, as the gateway would send it.</summary>
    protected static HttpRequestMessage SignedWebhook(Guid orderId)
    {
        var body = $"{{\"orderId\":\"{orderId}\"}}";
        return Webhook(body, FakeHostedGateway.Sign(body));
    }

    protected static async Task Public(HttpResponseMessage response, HttpStatusCode status, string code)
    {
        var body = await response.Content.ReadAsStringAsync();
        Assert.True(response.StatusCode == status, $"expected {(int)status} {code} but got {(int)response.StatusCode}: {body}");
        Assert.Equal(code, JsonDocument.Parse(body).RootElement.GetProperty("code").GetString());
    }

    protected Task<int> WebReserved() => Scalar(
        $"SELECT COALESCE(SUM(Reserved),0) FROM inventory.StockBalances WHERE ItemId='{Ids.Item}' AND Pool='web'");

    protected Task<string> Status(Guid order) => TestSql.ScalarAsync<string>(_db, $"SELECT Status FROM webstore.Orders WHERE Id='{order}'");

    protected Task<int> Scalar(string sql) => TestSql.ScalarAsync<int>(_db, sql);

    protected async Task Exec(string sql)
    {
        await using var connection = new SqlConnection(TestSql.ConnectionFor(_db));
        await connection.OpenAsync();
        await using var command = new SqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync();
    }
}
