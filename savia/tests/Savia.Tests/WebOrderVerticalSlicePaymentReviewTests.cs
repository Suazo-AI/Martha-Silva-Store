using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using Savia.Api;
using Savia.Contracts;

namespace Savia.Tests;

/// <summary>
/// Money the bank took is never invisible: a card capture that does not match its order (another amount, another
/// currency, a late or a second capture) is recorded for review through the return, the webhook and the sweep, and
/// a manager settles it. The name matches the api-host pass, so it also runs as the least-privilege login.
/// </summary>
public sealed class WebOrderVerticalSlicePaymentReviewTests : WebOrderHub
{
    [Fact]
    public async Task Webhook_for_another_amount_goes_to_review_and_a_manager_marks_it_refunded()
    {
        await using var hub = WithGateway();
        var client = hub.CreateClient();
        var order = await PlaceAsync(client, "monto@example.test", 1, "card");
        Gateway.CaptureWrongAmount(order.OrderId);
        for (var i = 0; i < 2; i++) await HttpAssert.OkAsync(await client.SendAsync(SignedWebhook(order.OrderId)));
        Assert.Equal(("payment_review", 0, 1), (await Status(order.OrderId), await WebReserved(), await Payments()));

        var staff = await Hub.SignInAsync(Ids.Manager, "t_manager");
        var row = Assert.Single(await HttpAssert.OkAsync<WebOrderRow[]>(await staff.GetAsync("/api/v1/web-orders?status=review")));
        var payment = Assert.Single(row.Payments!);
        Assert.True(row.NeedsReview);
        Assert.Equal((order.TotalMinor + 1, "captured", "amount"), (payment.AmountMinor, payment.Status, payment.Review));
        await HttpAssert.ProblemAsync(await staff.PostAsync($"/api/v1/web-orders/{order.OrderId}/cancel", null),
            HttpStatusCode.Conflict, "web.status");
        await HttpAssert.ProblemAsync(await staff.PostAsync($"/api/v1/web-orders/{order.OrderId}/accept-payment", null),
            HttpStatusCode.Conflict, "payment.mismatch");

        var cashier = await Hub.SignInAsync(Ids.CashierA, "t_cashier_a");
        await HttpAssert.ProblemAsync(await cashier.PostAsJsonAsync(Refund(order.OrderId), new RefundReviewRequest("RF-1")),
            HttpStatusCode.Forbidden, "auth.role_required");
        await HttpAssert.ProblemAsync(await staff.PostAsJsonAsync(Refund(order.OrderId), new RefundReviewRequest(" ")),
            HttpStatusCode.UnprocessableEntity, "web.validation");
        await HttpAssert.OkAsync(await staff.PostAsJsonAsync(Refund(order.OrderId), new RefundReviewRequest("RF-1")));
        Assert.Equal(("cancelled", 1), (await Status(order.OrderId), await Payments("refunded")));
        Assert.Empty(await HttpAssert.OkAsync<WebOrderRow[]>(await staff.GetAsync("/api/v1/web-orders?status=review")));
    }

    [Fact]
    public async Task Return_with_a_capture_in_another_currency_is_recorded_for_review()
    {
        await using var hub = WithGateway();
        var client = hub.CreateClient(new() { AllowAutoRedirect = false });
        var order = await PlaceAsync(client, "dolares@example.test", 1, "card");
        Gateway.CaptureInDollars(order.OrderId);

        var back = await client.GetAsync($"/api/v1/public/payments/fakecard/return?session={order.Payment!.Url!.Split('/')[^1]}");
        Assert.Equal(HttpStatusCode.SeeOther, back.StatusCode);
        Assert.Equal(("payment_review", 0), (await Status(order.OrderId), await WebReserved()));
        Assert.Equal(1, await Scalar("SELECT COUNT(*) FROM webstore.Payments WHERE CurrencyCode='USD' AND Status='captured'"));
    }

    [Fact]
    public async Task Second_capture_on_a_paid_order_is_flagged_without_touching_stock()
    {
        await using var hub = WithGateway();
        var client = hub.CreateClient();
        var order = await PlaceAsync(client, "doble@example.test", 1, "card");
        Gateway.Capture(order.OrderId);
        await HttpAssert.OkAsync(await client.SendAsync(SignedWebhook(order.OrderId)));
        Gateway.CaptureAgain(order.OrderId);
        await HttpAssert.OkAsync(await client.SendAsync(SignedWebhook(order.OrderId)));
        Assert.Equal(("paid", 2, 1), (await Status(order.OrderId), await Payments(), await WebReserved()));

        var staff = await Hub.SignInAsync(Ids.Manager, "t_manager");
        var row = Assert.Single(await HttpAssert.OkAsync<WebOrderRow[]>(await staff.GetAsync("/api/v1/web-orders?status=review")));
        Assert.Equal(new string?[] { null, "duplicate" }, row.Payments!.Select(p => p.Review));
        await HttpAssert.OkAsync(await staff.PostAsJsonAsync(Refund(order.OrderId), new RefundReviewRequest("RF-2")));
        Assert.Equal(("paid", 1, 1), (await Status(order.OrderId), await Payments("captured"), await WebReserved()));
    }

    [Fact]
    public async Task Capture_after_expiry_goes_to_review_and_a_manager_accepts_it_while_stock_lasts()
    {
        await using var hub = WithGateway();
        var client = hub.CreateClient();
        var order = await PlaceAsync(client, "tarde@example.test", 1, "card");
        await Exec("UPDATE webstore.Orders SET ExpiresAt=DATEADD(minute,-1,SYSUTCDATETIME())");
        var sweep = hub.Services.GetRequiredService<WebStoreSweep>();
        Assert.Equal(new SweepResult(0, 1, 0, 0), await sweep.RunOnceAsync(CancellationToken.None));

        Gateway.Capture(order.OrderId);
        await HttpAssert.OkAsync(await client.SendAsync(SignedWebhook(order.OrderId)));
        Assert.Equal(("payment_review", 0), (await Status(order.OrderId), await WebReserved()));

        var staff = await Hub.SignInAsync(Ids.Manager, "t_manager");
        Assert.Equal("late", Assert.Single(Assert.Single(await HttpAssert.OkAsync<WebOrderRow[]>(
            await staff.GetAsync("/api/v1/web-orders?status=review"))).Payments!).Review);
        await HttpAssert.OkAsync(await staff.PostAsync($"/api/v1/web-orders/{order.OrderId}/accept-payment", null));
        Assert.Equal(("paid", 1), (await Status(order.OrderId), await WebReserved()));
        await HttpAssert.OkAsync(await staff.PostAsync($"/api/v1/web-orders/{order.OrderId}/fulfill", null));
        Assert.Equal("fulfilled", await Status(order.OrderId));
    }

    private static string Refund(Guid order) => $"/api/v1/web-orders/{order}/mark-refunded";

    private Task<int> Payments(string? status = null) =>
        Scalar("SELECT COUNT(*) FROM webstore.Payments" + (status is null ? "" : $" WHERE Status='{status}'"));
}
