using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Savia.Api;
using Savia.Contracts;

namespace Savia.Tests;

/// <summary>
/// The public order path end to end on a hub over real SQL: buyers order through the public routes, staff and the sweep
/// settle them. The name matches the api-host pass, so it also runs as the least-privilege login.
/// </summary>
public sealed class WebOrderVerticalSliceTests : WebOrderHub
{
    [Fact]
    public async Task Public_catalog_order_and_replay_return_the_same_order()
    {
        var client = Hub.CreateClient();
        var catalog = await HttpAssert.OkAsync<PublicCatalogResponse>(await client.GetAsync("/api/v1/public/catalog"));
        Assert.Equal(WebUnits, Assert.Single(catalog.Items, i => i.Sku == Sku).Available);

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
        var client = Hub.CreateClient();
        var created = await PlaceAsync(client, "estado@example.test", 1, "manual");
        var path = $"/api/v1/public/orders/{created.OrderId}";
        await Public(await client.GetAsync(path), HttpStatusCode.NotFound, "not_found");
        using var wrong = new HttpRequestMessage(HttpMethod.Get, path) { Headers = { { "X-Order-Token", "x" + created.AccessToken[1..] } } };
        await Public(await client.SendAsync(wrong), HttpStatusCode.NotFound, "not_found");
        using var right = new HttpRequestMessage(HttpMethod.Get, path) { Headers = { { "X-Order-Token", created.AccessToken } } };
        var response = await client.SendAsync(right);
        var status = await HttpAssert.OkAsync<PublicOrderStatus>(response);
        Assert.Equal(("reserved", Sku, 1), (status.Status, status.Lines.Single().Sku, status.Lines.Single().Qty));
        Assert.DoesNotContain("Calle", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Last_units_go_to_one_buyer_and_the_next_gets_out_of_stock_with_the_sku()
    {
        var client = Hub.CreateClient();
        await PlaceAsync(client, "primera@example.test", WebUnits, "manual");
        var refused = await client.SendAsync(Order(Guid.NewGuid(), "segunda@example.test", 1, "manual"));
        await Public(refused, HttpStatusCode.Conflict, "out_of_stock");
        Assert.Equal(Sku, (await refused.Content.ReadFromJsonAsync<PublicProblem>())!.Sku);
        Assert.Equal(WebUnits, await WebReserved());
    }

    [Fact]
    public async Task Failed_bot_check_reserves_nothing()
    {
        await using var hub = Hub.WithWebHostBuilder(b => b.ConfigureTestServices(s => s.AddSingleton<IBotCheck, RefuseBotCheck>()));
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
        Gateway.Capture(created.OrderId);
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
        Gateway.Capture(card.OrderId);
        await Exec("UPDATE webstore.Orders SET ExpiresAt=DATEADD(minute,-1,SYSUTCDATETIME())");

        var sweep = hub.Services.GetRequiredService<WebStoreSweep>();
        Assert.Equal(new SweepResult(1, 1, 0, 0), await sweep.RunOnceAsync(CancellationToken.None));
        Assert.Equal(new SweepResult(0, 0, 0, 0), await sweep.RunOnceAsync(CancellationToken.None));
        Assert.Equal(("expired", "paid"), (await Status(manual.OrderId), await Status(card.OrderId)));
        Assert.Equal(1, await WebReserved());
    }

    [Fact]
    public async Task Sweep_sends_a_capture_for_another_amount_to_review_and_still_expires_the_rest()
    {
        await using var hub = WithGateway();
        var client = hub.CreateClient();
        var bad = await PlaceAsync(client, "monto@example.test", 1, "card");
        var manual = await PlaceAsync(client, "sigue@example.test", 1, "manual");
        Gateway.CaptureWrongAmount(bad.OrderId);
        await Exec($"UPDATE webstore.Orders SET ExpiresAt=DATEADD(minute,-2,SYSUTCDATETIME()) WHERE Id='{bad.OrderId}'");
        await Exec($"UPDATE webstore.Orders SET ExpiresAt=DATEADD(minute,-1,SYSUTCDATETIME()) WHERE Id='{manual.OrderId}'");

        // The money the bank took is recorded and shown to staff; the order no longer holds stock nor can be cancelled.
        var sweep = hub.Services.GetRequiredService<WebStoreSweep>();
        Assert.Equal(new SweepResult(0, 1, 0, 1), await sweep.RunOnceAsync(CancellationToken.None));
        Assert.Equal(("payment_review", "expired"), (await Status(bad.OrderId), await Status(manual.OrderId)));
        Assert.Equal(bad.TotalMinor + 1, await Scalar("SELECT CAST(SUM(AmountMinor) AS int) FROM webstore.Payments"));
        Assert.Equal(0, await WebReserved());
        Assert.Equal(new SweepResult(0, 0, 0, 0), await sweep.RunOnceAsync(CancellationToken.None));
    }

    [Fact]
    public async Task Staff_lists_records_a_manual_payment_fulfills_and_cancels()
    {
        var buyer = Hub.CreateClient();
        var paid = await PlaceAsync(buyer, "pagada@example.test", 1, "manual");
        var cancelled = await PlaceAsync(buyer, "cancelada@example.test", 1, "manual");
        await HttpAssert.ProblemAsync(await buyer.GetAsync("/api/v1/web-orders"), HttpStatusCode.Unauthorized, "auth.required");

        var staff = await Hub.SignInAsync(Ids.Manager, "t_manager");
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

    private sealed class RefuseBotCheck : IBotCheck
    {
        public Task<bool> PassesAsync(string? token, IPAddress? client, CancellationToken ct) => Task.FromResult(false);
    }
}
