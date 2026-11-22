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
/// The public order path end to end on a hub over real SQL: a branch hands 2 units to the web, buyers order through the
/// public routes, staff and the sweep settle them. The name matches the api-host pass, so it also runs as the
/// least-privilege login.
/// </summary>
public sealed class WebOrderVerticalSliceTests : IAsyncLifetime
{
    private const int WebUnits = 2;
    private string _db = "";
    private SaviaNode _hub = null!;
    private readonly FakeHostedGateway _gateway = new();
    private string _sku = "";

    public async Task InitializeAsync()
    {
        _db = await TestSql.CloneAsync("weborder");
        // As in db/tests/webstore/080: branch A consigns to the web, then the database becomes the hub and credits it.
        await Exec($"""
            DECLARE @a uniqueidentifier=test.Id('nodeA'),@cloud uniqueidentifier=test.Id('nodeCloud'),@item uniqueidentifier=test.Id('item'),
              @locA uniqueidentifier=test.Id('locA'),@manager uniqueidentifier=test.Id('manager'),@c uniqueidentifier=NEWID();
            EXEC sync.usp_SetLocalNode @NodeId=@a;
            EXEC test.SeedStock @item,@locA,5;
            EXEC inventory.usp_ConsignToWeb @ConsignmentId=@c,@ItemId=@item,@FromLocationId=@locA,@Quantity={WebUnits},@ActorId=@manager;
            UPDATE sync.LocalNode SET NodeId=@cloud;
            EXEC inventory.usp_ApplyWebConsignments;
            """);
        _sku = await TestSql.ScalarAsync<string>(_db, $"SELECT Sku FROM catalog.Items WHERE Id='{Ids.Item}'");
        _hub = new SaviaNode(_db, Domain.NodeKind.Cloud, Ids.NodeCloud, null, null, new Dictionary<string, string?>
        {
            ["Savia:Public:BotCheck"] = "disabled",
            ["Savia:Public:OrderPageUrl"] = "https://tienda.example/pedido",
            ["Savia:WebStore:SweepSeconds"] = "0",
        });
    }

    public async Task DisposeAsync()
    {
        await _hub.DisposeAsync();
        await TestSql.DropAsync(_db);
    }

    [Fact]
    public async Task Public_catalog_order_and_replay_return_the_same_order()
    {
        var client = _hub.CreateClient();
        var catalog = await HttpAssert.OkAsync<PublicCatalogResponse>(await client.GetAsync("/api/v1/public/catalog"));
        Assert.Equal(WebUnits, Assert.Single(catalog.Items, i => i.Sku == _sku).Available);

        var key = Guid.NewGuid();
        var first = await client.SendAsync(Order(key, "uno@example.test", 1, "manual"));
        Assert.Equal(HttpStatusCode.Created, first.StatusCode);
        var created = (await first.Content.ReadFromJsonAsync<PublicOrderCreated>())!;
        Assert.Equal(("reserved", 50000L, "instructions"), (created.Status, created.ShippingMinor, created.Payment!.Kind));

        // A retry with a new bot token is the same request: same order, same token, no second reservation.
        var again = await client.SendAsync(Order(key, "uno@example.test", 1, "manual", turnstile: "otro"));
        Assert.Equal(HttpStatusCode.OK, again.StatusCode);
        var replay = (await again.Content.ReadFromJsonAsync<PublicOrderCreated>())!;
        Assert.Equal((created.OrderId, created.AccessToken, created.Code), (replay.OrderId, replay.AccessToken, replay.Code));
        Assert.Equal(1, await Scalar("SELECT COUNT(*) FROM webstore.Orders"));
        Assert.Equal(1, await WebReserved());

        await Public(await client.SendAsync(Order(key, "uno@example.test", 2, "manual")), HttpStatusCode.Conflict, "idempotency_conflict");
    }

    [Fact]
    public async Task Order_status_needs_its_token()
    {
        var client = _hub.CreateClient();
        var created = await PlaceAsync(client, "estado@example.test", 1, "manual");
        var path = $"/api/v1/public/orders/{created.OrderId}";
        await Public(await client.GetAsync(path), HttpStatusCode.NotFound, "not_found");
        using var wrong = new HttpRequestMessage(HttpMethod.Get, path) { Headers = { { "X-Order-Token", "x" + created.AccessToken[1..] } } };
        await Public(await client.SendAsync(wrong), HttpStatusCode.NotFound, "not_found");
        using var right = new HttpRequestMessage(HttpMethod.Get, path) { Headers = { { "X-Order-Token", created.AccessToken } } };
        var response = await client.SendAsync(right);
        var status = await HttpAssert.OkAsync<PublicOrderStatus>(response);
        Assert.Equal(("reserved", _sku, 1), (status.Status, status.Lines.Single().Sku, status.Lines.Single().Qty));
        Assert.DoesNotContain("Calle", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Last_units_go_to_one_buyer_and_the_next_gets_out_of_stock_with_the_sku()
    {
        var client = _hub.CreateClient();
        await PlaceAsync(client, "primera@example.test", WebUnits, "manual");
        var refused = await client.SendAsync(Order(Guid.NewGuid(), "segunda@example.test", 1, "manual"));
        await Public(refused, HttpStatusCode.Conflict, "out_of_stock");
        Assert.Equal(_sku, (await refused.Content.ReadFromJsonAsync<PublicProblem>())!.Sku);
        Assert.Equal(WebUnits, await WebReserved());
    }

    [Fact]
    public async Task Failed_bot_check_reserves_nothing()
    {
        await using var hub = _hub.WithWebHostBuilder(b => b.ConfigureTestServices(s => s.AddSingleton<IBotCheck, RefuseBotCheck>()));
        await Public(await hub.CreateClient().SendAsync(Order(Guid.NewGuid(), "bot@example.test", 1, "manual")),
            HttpStatusCode.Forbidden, "turnstile_failed");
        Assert.Equal(0, await Scalar("SELECT COUNT(*) FROM webstore.Orders"));
        Assert.Equal(0, await WebReserved());
    }

    [Fact]
    public async Task Card_return_is_not_payment_until_the_gateway_confirms_and_webhooks_must_be_signed()
    {
        await using var hub = WithGateway();
        var client = hub.CreateClient(new() { AllowAutoRedirect = false });
        var created = await PlaceAsync(client, "tarjeta@example.test", 1, "card");
        Assert.Equal(("fakecard", "redirect"), (created.Payment!.Provider, created.Payment.Kind));
        var session = created.Payment.Url!.Split('/')[^1];

        // The buyer closes the hosted page and edits the return URL: still reserved.
        var back = await client.GetAsync($"/api/v1/public/payments/fakecard/return?session={session}&status=paid");
        Assert.Equal(HttpStatusCode.SeeOther, back.StatusCode);
        Assert.Equal($"https://tienda.example/pedido?order={created.OrderId}", back.Headers.Location!.ToString());
        Assert.Equal("reserved", await Status(created.OrderId));

        var body = $"{{\"orderId\":\"{created.OrderId}\"}}";
        _gateway.Capture(created.OrderId);
        await Public(await client.SendAsync(Webhook(body, "00")), HttpStatusCode.Unauthorized, "signature_invalid");
        Assert.Equal(0, await Scalar("SELECT COUNT(*) FROM webstore.Payments"));

        for (var i = 0; i < 2; i++) await HttpAssert.OkAsync(await client.SendAsync(Webhook(body, FakeHostedGateway.Sign(body))));
        Assert.Equal("paid", await Status(created.OrderId));
        Assert.Equal(1, await Scalar("SELECT COUNT(*) FROM webstore.Payments"));
    }

    [Fact]
    public async Task Sweep_expires_a_due_order_once_and_records_a_payment_the_buyer_never_returned_from()
    {
        await using var hub = WithGateway();
        var client = hub.CreateClient();
        var manual = await PlaceAsync(client, "vence@example.test", 1, "manual");
        var card = await PlaceAsync(client, "cerro@example.test", 1, "card");
        _gateway.Capture(card.OrderId);
        await Exec("UPDATE webstore.Orders SET ExpiresAt=DATEADD(minute,-1,SYSUTCDATETIME())");

        var sweep = hub.Services.GetRequiredService<WebStoreSweep>();
        Assert.Equal(new SweepResult(1, 1, 0), await sweep.RunOnceAsync(CancellationToken.None));
        Assert.Equal(new SweepResult(0, 0, 0), await sweep.RunOnceAsync(CancellationToken.None));
        Assert.Equal(("expired", "paid"), (await Status(manual.OrderId), await Status(card.OrderId)));
        Assert.Equal(1, await WebReserved());
    }

    [Fact]
    public async Task Sweep_skips_an_order_it_cannot_settle_and_still_expires_the_rest()
    {
        await using var hub = WithGateway();
        var client = hub.CreateClient();
        var bad = await PlaceAsync(client, "monto@example.test", 1, "card");
        var manual = await PlaceAsync(client, "sigue@example.test", 1, "manual");
        _gateway.CaptureWrongAmount(bad.OrderId);
        // The bad order is due first, so a pass that stops on its error never reaches the manual one.
        await Exec($"UPDATE webstore.Orders SET ExpiresAt=DATEADD(minute,-2,SYSUTCDATETIME()) WHERE Id='{bad.OrderId}'");
        await Exec($"UPDATE webstore.Orders SET ExpiresAt=DATEADD(minute,-1,SYSUTCDATETIME()) WHERE Id='{manual.OrderId}'");

        var sweep = hub.Services.GetRequiredService<WebStoreSweep>();
        Assert.Equal(new SweepResult(0, 1, 1), await sweep.RunOnceAsync(CancellationToken.None));
        Assert.Equal(("reserved", "expired"), (await Status(bad.OrderId), await Status(manual.OrderId)));
        Assert.Equal(0, await Scalar("SELECT COUNT(*) FROM webstore.Payments"));
    }

    [Fact]
    public async Task Staff_lists_records_a_manual_payment_fulfills_and_cancels()
    {
        var buyer = _hub.CreateClient();
        var paid = await PlaceAsync(buyer, "pagada@example.test", 1, "manual");
        var cancelled = await PlaceAsync(buyer, "cancelada@example.test", 1, "manual");
        await HttpAssert.ProblemAsync(await buyer.GetAsync("/api/v1/web-orders"), HttpStatusCode.Unauthorized, "auth.required");

        var staff = await _hub.SignInAsync(Ids.Manager, "t_manager");
        var rows = await HttpAssert.OkAsync<WebOrderRow[]>(await staff.GetAsync("/api/v1/web-orders?status=reserved"));
        var row = Assert.Single(rows, r => r.Id == paid.OrderId);
        Assert.Equal(("Calle 1", "pagada@example.test"), (row.Address, row.Email));
        Assert.False(string.IsNullOrEmpty(row.SourceStore));

        await HttpAssert.OkAsync(await staff.PostAsJsonAsync($"/api/v1/web-orders/{paid.OrderId}/manual-payment",
            new ManualPaymentRequest(paid.TotalMinor, paid.Currency, "Transferencia 123")));
        Assert.Equal("paid", await Status(paid.OrderId));
        await HttpAssert.OkAsync(await staff.PostAsync($"/api/v1/web-orders/{paid.OrderId}/fulfill", null));
        Assert.Equal("fulfilled", await Status(paid.OrderId));

        await HttpAssert.OkAsync(await staff.PostAsync($"/api/v1/web-orders/{cancelled.OrderId}/cancel", null));
        Assert.Equal("cancelled", await Status(cancelled.OrderId));
        Assert.Equal(0, await WebReserved());
    }

    private WebApplicationFactory<Program> WithGateway() =>
        _hub.WithWebHostBuilder(b => b.ConfigureTestServices(s => s.AddSingleton<IPaymentProvider>(_gateway)));

    private HttpRequestMessage Order(Guid key, string email, int qty, string provider, string turnstile = "token") =>
        new(HttpMethod.Post, "/api/v1/public/orders")
        {
            Content = JsonContent.Create(new
            {
                lines = new[] { new { sku = _sku, qty } },
                contact = new { name = "Compradora", email },
                shipping = new { zone = "managua", address = "Calle 1", city = "Managua" },
                provider,
                turnstileToken = turnstile,
            }),
            Headers = { { "Idempotency-Key", key.ToString() } },
        };

    private async Task<PublicOrderCreated> PlaceAsync(HttpClient client, string email, int qty, string provider)
    {
        var response = await client.SendAsync(Order(Guid.NewGuid(), email, qty, provider));
        Assert.True(response.StatusCode == HttpStatusCode.Created, await response.Content.ReadAsStringAsync());
        return (await response.Content.ReadFromJsonAsync<PublicOrderCreated>())!;
    }

    private static HttpRequestMessage Webhook(string body, string signature) =>
        new(HttpMethod.Post, "/api/v1/public/payments/fakecard/webhook")
        {
            Content = new StringContent(body, Encoding.UTF8, "application/json"),
            Headers = { { FakeHostedGateway.SignatureHeader, signature } },
        };

    private static async Task Public(HttpResponseMessage response, HttpStatusCode status, string code)
    {
        var body = await response.Content.ReadAsStringAsync();
        Assert.True(response.StatusCode == status, $"expected {(int)status} {code} but got {(int)response.StatusCode}: {body}");
        Assert.Equal(code, JsonDocument.Parse(body).RootElement.GetProperty("code").GetString());
    }

    private Task<int> WebReserved() => Scalar(
        $"SELECT COALESCE(SUM(Reserved),0) FROM inventory.StockBalances WHERE ItemId='{Ids.Item}' AND Pool='web'");

    private Task<string> Status(Guid order) => TestSql.ScalarAsync<string>(_db, $"SELECT Status FROM webstore.Orders WHERE Id='{order}'");

    private Task<int> Scalar(string sql) => TestSql.ScalarAsync<int>(_db, sql);

    private async Task Exec(string sql)
    {
        await using var connection = new SqlConnection(TestSql.ConnectionFor(_db));
        await connection.OpenAsync();
        await using var command = new SqlCommand(sql, connection);
        await command.ExecuteNonQueryAsync();
    }

    private sealed class RefuseBotCheck : IBotCheck
    {
        public Task<bool> PassesAsync(string? token, IPAddress? client, CancellationToken ct) => Task.FromResult(false);
    }
}
