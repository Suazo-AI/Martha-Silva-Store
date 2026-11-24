using System.Net;
using System.Net.Http.Json;
using System.Text;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using Savia.Api;
using Savia.Domain;

namespace Savia.Tests;

/// <summary>Every payment provider keeps the same promises; a new card adapter joins this theory before it ships.</summary>
public sealed class PaymentProviderContractTests
{
    public static TheoryData<string> Providers => ["manual", "fakecard"];

    private static IPaymentProvider Make(string code) => code == "manual"
        ? new ManualPaymentProvider(new ConfigurationBuilder().Build())
        : new FakeHostedGateway();

    private static PaymentStartRequest Start(Guid order) =>
        new(order, "W-TEST", 170000, "NIO", "es", new Uri("https://hub.test/api/v1/public/payments/x/return"));

    [Theory, MemberData(nameof(Providers))]
    public async Task Start_tells_the_buyer_where_to_go_or_what_to_do(string code)
    {
        var start = await Make(code).StartAsync(Start(Guid.NewGuid()), CancellationToken.None);
        Assert.Contains(start.Kind, new[] { "redirect", "instructions" });
        Assert.True(start.Kind == "redirect" ? start.Url is { Length: > 0 } : start.Instructions is { Length: > 0 });
    }

    [Theory, MemberData(nameof(Providers))]
    public async Task A_browser_claim_alone_is_never_a_verified_payment(string code)
    {
        var provider = Make(code);
        var order = Guid.NewGuid();
        await provider.StartAsync(Start(order), CancellationToken.None);
        var forged = new DefaultHttpContext().Request;
        forged.QueryString = new QueryString($"?status=paid&order={order}&amount=170000");
        var result = await provider.ConfirmReturnAsync(forged, CancellationToken.None);
        Assert.Null(PaymentProviders.Verified(provider, result));
        Assert.Null(PaymentProviders.Verified(provider, await provider.QueryAsync(order, null, CancellationToken.None), order));
    }

    [Theory, MemberData(nameof(Providers))]
    public async Task Refund_of_an_uncaptured_order_is_refused(string code) =>
        Assert.False((await Make(code).RefundAsync(Guid.NewGuid(), "none", 100, CancellationToken.None)).Accepted);

    [Fact]
    public void Manual_payment_is_not_a_card_and_the_buyer_card_choice_skips_it()
    {
        var manual = Make("manual");
        Assert.False(manual.IsCard);
        Assert.Null(new PaymentProviders([manual]).ForBuyer("card"));
        Assert.Same(manual, new PaymentProviders([manual]).ForBuyer("manual"));
    }

    [Fact]
    public async Task Fake_gateway_verifies_only_after_its_server_captured()
    {
        var gateway = new FakeHostedGateway();
        var order = Guid.NewGuid();
        await gateway.StartAsync(Start(order), CancellationToken.None);
        gateway.Capture(order);
        var paid = PaymentProviders.Verified(gateway, await gateway.QueryAsync(order, null, CancellationToken.None));
        Assert.Equal((order, 170000L, "NIO"), (paid!.OrderId, paid.AmountMinor, paid.Currency));
    }

    [Fact]
    public async Task Fake_gateway_rejects_an_unsigned_webhook_before_reading_it()
    {
        var request = new DefaultHttpContext().Request;
        request.Body = new MemoryStream(Encoding.UTF8.GetBytes($"{{\"orderId\":\"{Guid.NewGuid()}\"}}"));
        request.Headers[FakeHostedGateway.SignatureHeader] = "00";
        var ex = await Assert.ThrowsAsync<SaviaException>(() => new FakeHostedGateway().HandleWebhookAsync(request, CancellationToken.None));
        Assert.Equal("payment.signature", ex.Error.Code);
    }
}

/// <summary>Abuse controls answer before any SQL runs, so these hosts point at a database that does not exist.</summary>
public sealed class PublicAbuseTests
{
    private const string Absent = "SAVIA_T_absent_public";

    private static SaviaNode Hub(Dictionary<string, string?>? extra = null) => new(Absent, NodeKind.Cloud, Ids.NodeCloud, null, null,
        new Dictionary<string, string?>
        {
            ["Savia:Public:BotCheck"] = "disabled",
            ["Savia:Public:AllowedOrigins"] = "https://tienda.example",
            ["Savia:WebStore:SweepSeconds"] = "0",
        }.Concat(extra ?? []).ToDictionary());

    private static HttpRequestMessage Order(string json) => new(HttpMethod.Post, "/api/v1/public/orders")
    {
        Content = new StringContent(json, Encoding.UTF8, "application/json"),
        Headers = { { "Idempotency-Key", Guid.NewGuid().ToString() } },
    };

    private static async Task AssertPublicAsync(HttpResponseMessage response, HttpStatusCode status, string code)
    {
        var body = await response.Content.ReadAsStringAsync();
        Assert.True(response.StatusCode == status, $"expected {(int)status} but got {(int)response.StatusCode}: {body}");
        Assert.Equal(code, (await response.Content.ReadFromJsonAsync<Contracts.PublicProblem>())!.Code);
    }

    [Fact]
    public async Task Body_over_16_KB_is_413()
    {
        await using var hub = Hub();
        var big = $"{{\"lines\":[],\"provider\":\"manual\",\"contact\":{{\"name\":\"{new string('x', 17000)}\"}}}}";
        await AssertPublicAsync(await hub.CreateClient().SendAsync(Order(big)), HttpStatusCode.RequestEntityTooLarge, "payload_too_large");
    }

    [Fact]
    public async Task Unknown_field_is_400()
    {
        await using var hub = Hub();
        var json = """{"lines":[{"sku":"A","qty":1}],"contact":{"name":"A","email":"a@b.test"},"shipping":{"zone":"managua","address":"x","city":"y"},"provider":"manual","unitPriceMinor":1}""";
        await AssertPublicAsync(await hub.CreateClient().SendAsync(Order(json)), HttpStatusCode.BadRequest, "validation");
    }

    [Fact]
    public async Task Too_many_requests_from_one_client_is_429()
    {
        await using var hub = Hub(new() { ["Savia:Public:PerMinute"] = "2" });
        var client = hub.CreateClient();
        for (var i = 0; i < 2; i++) await AssertPublicAsync(await client.SendAsync(Order("{}")), HttpStatusCode.BadRequest, "validation");
        await AssertPublicAsync(await client.SendAsync(Order("{}")), HttpStatusCode.TooManyRequests, "rate_limited");
    }

    [Theory]
    [InlineData("https://tienda.example", true)]
    [InlineData("https://evil.example", false)]
    public async Task Cors_allows_only_listed_origins_without_credentials(string origin, bool allowed)
    {
        await using var hub = Hub();
        using var preflight = new HttpRequestMessage(HttpMethod.Options, "/api/v1/public/orders")
        {
            Headers = { { "Origin", origin }, { "Access-Control-Request-Method", "POST" }, { "Access-Control-Request-Headers", "content-type,idempotency-key" } },
        };
        var response = await hub.CreateClient().SendAsync(preflight);
        Assert.Equal(allowed, response.Headers.Contains("Access-Control-Allow-Origin"));
        Assert.False(response.Headers.Contains("Access-Control-Allow-Credentials"));
    }

    [Fact]
    public async Task Public_routes_do_not_exist_on_a_branch()
    {
        await using var branch = new SaviaNode(Absent, NodeKind.Branch, Ids.NodeA, Ids.BranchA, Ids.LocA,
            new Dictionary<string, string?> { ["Savia:WebStore:SweepSeconds"] = "0" });
        Assert.Equal(HttpStatusCode.NotFound, (await branch.CreateClient().SendAsync(Order("{}"))).StatusCode);
    }
}
