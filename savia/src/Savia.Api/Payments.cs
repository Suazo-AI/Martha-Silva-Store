using Savia.Application;

namespace Savia.Api;

// Payment providers (ORDER-PATH-SPEC 4.3). Only ConfirmReturnAsync, QueryAsync or a verified webhook may lead to a
// recorded payment; a browser parameter alone never marks an order paid. No card adapter exists yet: BAC or Pagadito is
// added as one more IPaymentProvider once the bank gives sandbox access.

public enum PaymentStatus { Captured, Authorized, Declined, Pending, Unknown }

/// <param name="ReturnUrl">Where the hosted page sends the buyer back: the hub's return route for this provider.</param>
public sealed record PaymentStartRequest(Guid OrderId, string Code, long AmountMinor, string Currency, string Locale, Uri ReturnUrl);

public sealed record PaymentStart(string Kind, string? Url, string? Method, string? Instructions);

/// <param name="OrderId">The order the provider says it charged, echoed from what StartAsync sent. Added to the spec's
/// record because a return or webhook names the order only through the provider.</param>
public sealed record PaymentResult(PaymentStatus Status, string? ProviderPaymentId, long? AmountMinor, string? Currency,
    string? FailureCode, Guid? OrderId = null);

public sealed record RefundResult(bool Accepted, string? FailureCode);

public interface IPaymentProvider
{
    /// <summary>Stored on the order: <c>manual</c>, later <c>bac</c> or <c>pagadito</c>.</summary>
    string Code { get; }

    /// <summary>False for <c>manual</c>: it never satisfies the card requirement (D-008).</summary>
    bool IsCard { get; }

    /// <summary>What the buyer and staff see.</summary>
    string Label { get; }

    Task<PaymentStart> StartAsync(PaymentStartRequest request, CancellationToken ct);

    /// <summary>Confirms server-to-server what the browser's return claims.</summary>
    Task<PaymentResult> ConfirmReturnAsync(HttpRequest request, CancellationToken ct);

    /// <summary>Null when the provider has no webhook. Throws <c>payment.signature</c> (401) before it reads a forged body.</summary>
    Task<PaymentResult?> HandleWebhookAsync(HttpRequest request, CancellationToken ct);

    Task<PaymentResult> QueryAsync(Guid orderId, string? providerPaymentId, CancellationToken ct);

    Task<RefundResult> RefundAsync(Guid orderId, string providerPaymentId, long amountMinor, CancellationToken ct);
}

/// <summary>
/// Bank transfer, a Compra-Click link sent by staff, or payment on pickup. Staff record the payment by hand
/// (POST /web-orders/{id}/manual-payment); until then the order is pending and expires like any other.
/// </summary>
public sealed class ManualPaymentProvider(IConfiguration config) : IPaymentProvider
{
    public const string DefaultInstructions =
        "Le escribiremos por WhatsApp o correo con los datos de transferencia o un enlace de pago. " +
        "Su pedido queda reservado hasta la hora indicada.";

    public string Code => WebStoreService.ManualProviderCode;
    public bool IsCard => false;
    public string Label => "Pago manual (no es tarjeta)";

    public Task<PaymentStart> StartAsync(PaymentStartRequest request, CancellationToken ct) => Task.FromResult(new PaymentStart(
        "instructions", null, "manual", config["Savia:Payments:Manual:Instructions"] is { Length: > 0 } text ? text : DefaultInstructions));

    public Task<PaymentResult> ConfirmReturnAsync(HttpRequest request, CancellationToken ct) =>
        Task.FromResult(new PaymentResult(PaymentStatus.Unknown, null, null, null, "unsupported"));

    public Task<PaymentResult?> HandleWebhookAsync(HttpRequest request, CancellationToken ct) => Task.FromResult<PaymentResult?>(null);

    public Task<PaymentResult> QueryAsync(Guid orderId, string? providerPaymentId, CancellationToken ct) =>
        Task.FromResult(new PaymentResult(PaymentStatus.Pending, null, null, null, null, orderId));

    public Task<RefundResult> RefundAsync(Guid orderId, string providerPaymentId, long amountMinor, CancellationToken ct) =>
        Task.FromResult(new RefundResult(false, "unsupported"));
}

/// <summary>Every registered provider, looked up by code. The buyer asks for <c>card</c>; the hub picks its card gateway.</summary>
public sealed class PaymentProviders(IEnumerable<IPaymentProvider> providers)
{
    private readonly IPaymentProvider[] all = [.. providers];

    public IPaymentProvider? ForBuyer(string requested) =>
        requested == "card" ? all.LastOrDefault(p => p.IsCard) : all.LastOrDefault(p => !p.IsCard && p.Code == requested);

    public IPaymentProvider? ByCode(string? code) => all.LastOrDefault(p => p.Code == code);

    /// <summary>A confirmed capture that names the order, the provider's id, the amount and the currency.</summary>
    public static VerifiedPayment? Verified(IPaymentProvider provider, PaymentResult result, Guid? knownOrder = null) =>
        result is { Status: PaymentStatus.Captured, ProviderPaymentId.Length: > 0, AmountMinor: long amount, Currency: { } currency }
        && (knownOrder ?? result.OrderId) is Guid order
            ? new VerifiedPayment(order, provider.Code, result.ProviderPaymentId, amount, currency)
            : null;
}
