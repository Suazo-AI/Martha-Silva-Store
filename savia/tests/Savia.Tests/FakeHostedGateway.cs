using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Savia.Api;
using Savia.Domain;

namespace Savia.Tests;

/// <summary>
/// Test-only hosted card page. It keeps the payment state on its own "server" side, the way BAC or Pagadito would:
/// a return or webhook is believed only after it is looked up there, and a webhook must carry an HMAC of its body.
/// It is never registered by the application.
/// </summary>
public sealed class FakeHostedGateway : IPaymentProvider
{
    public const string SignatureHeader = "X-Fake-Signature";
    private static readonly byte[] Secret = Encoding.UTF8.GetBytes("fake-gateway-test-key");   // test value, not a credential
    private readonly ConcurrentDictionary<string, Guid> sessions = new();
    private readonly ConcurrentDictionary<Guid, Charge> charges = new();

    private sealed record Charge(long AmountMinor, string Currency, string? PaymentId);

    public string Code => "fakecard";
    public bool IsCard => true;
    public string Label => "Tarjeta (prueba)";

    public Task<PaymentStart> StartAsync(PaymentStartRequest request, CancellationToken ct)
    {
        var session = Guid.NewGuid().ToString("N");
        sessions[session] = request.OrderId;
        charges.TryAdd(request.OrderId, new Charge(request.AmountMinor, request.Currency, null));
        return Task.FromResult(new PaymentStart("redirect", $"https://gateway.test/pay/{session}", "card", null));
    }

    /// <summary>The bank charged the card: only now does a server-side lookup answer Captured.</summary>
    public void Capture(Guid orderId) => charges[orderId] = charges[orderId] with { PaymentId = "fake-" + orderId.ToString("N")[..12] };

    /// <summary>The bank charged a different amount, so the hub must refuse to record it.</summary>
    public void CaptureWrongAmount(Guid orderId) =>
        charges[orderId] = charges[orderId] with { AmountMinor = charges[orderId].AmountMinor + 1, PaymentId = "fake-" + orderId.ToString("N")[..12] };

    public Task<PaymentResult> ConfirmReturnAsync(HttpRequest request, CancellationToken ct) =>
        Task.FromResult(sessions.TryGetValue(request.Query["session"].ToString(), out var order)
            ? Lookup(order)
            : new PaymentResult(PaymentStatus.Unknown, null, null, null, "unknown_session"));

    public async Task<PaymentResult?> HandleWebhookAsync(HttpRequest request, CancellationToken ct)
    {
        using var reader = new StreamReader(request.Body);
        var body = await reader.ReadToEndAsync(ct);
        if (!CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(Sign(body)),
                Encoding.ASCII.GetBytes(request.Headers[SignatureHeader].ToString())))
            throw new SaviaException(new SaviaError("payment.signature", ErrorKind.Unauthorized, "Firma inválida."));
        return Lookup(JsonDocument.Parse(body).RootElement.GetProperty("orderId").GetGuid());
    }

    public Task<PaymentResult> QueryAsync(Guid orderId, string? providerPaymentId, CancellationToken ct) => Task.FromResult(Lookup(orderId));

    public Task<RefundResult> RefundAsync(Guid orderId, string providerPaymentId, long amountMinor, CancellationToken ct) =>
        Task.FromResult(charges.TryGetValue(orderId, out var c) && c.PaymentId == providerPaymentId
            ? new RefundResult(true, null)
            : new RefundResult(false, "not_captured"));

    public static string Sign(string body) => Convert.ToHexString(HMACSHA256.HashData(Secret, Encoding.UTF8.GetBytes(body)));

    private PaymentResult Lookup(Guid orderId) => charges.TryGetValue(orderId, out var c)
        ? c.PaymentId is null
            ? new PaymentResult(PaymentStatus.Pending, null, c.AmountMinor, c.Currency, null, orderId)
            : new PaymentResult(PaymentStatus.Captured, c.PaymentId, c.AmountMinor, c.Currency, null, orderId)
        : new PaymentResult(PaymentStatus.Unknown, null, null, null, "unknown_order", orderId);
}
