using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

/// <summary>A validated public order with the keys the hub derived from its Idempotency-Key.</summary>
public sealed record NewWebOrder(Guid OrderId, byte[] RequestHash, byte[] AccessTokenHash, byte[]? ClientHash,
    PublicOrderRequest Request, string ProviderCode);

/// <summary>The row usp_CreateWebOrder returns. <c>Replayed</c> is true when the key already held the same request.</summary>
public sealed record WebOrderPlaced(Guid OrderId, string Code, string Status, long TotalMinor, long ShippingMinor, string Currency,
    DateTimeOffset ExpiresAt, bool Replayed);

public sealed record WebOrderView(Guid OrderId, string Code, string Status, long TotalMinor, long ShippingMinor, string Currency,
    DateTimeOffset ExpiresAt, string? Provider, byte[] RequestHash, PublicOrderLine[] Lines);

public sealed record DueWebOrder(Guid OrderId, string? Provider, long TotalMinor, string Currency);

/// <summary>A payment a provider confirmed server-side, or staff checked by hand. Nothing else may build one.</summary>
public sealed record VerifiedPayment(Guid OrderId, string Provider, string ExternalPaymentId, long AmountMinor, string Currency);

public interface IWebStoreStore
{
    Task<PublicCatalogItem[]> CatalogAsync(CancellationToken ct);
    Task<WebOrderView?> FindOrderAsync(Guid orderId, byte[] accessTokenHash, CancellationToken ct);
    Task<WebOrderPlaced> CreateOrderAsync(NewWebOrder order, Guid originNode, CancellationToken ct);
    Task<WebOrderRow[]> ListOrdersAsync(string? status, CancellationToken ct);
    Task<DueWebOrder[]> DueOrdersAsync(CancellationToken ct);
    Task<bool> ExpireAsync(Guid orderId, CancellationToken ct);
    Task RecordPaymentAsync(VerifiedPayment payment, Guid paymentId, Guid originNode, Guid? actor, CancellationToken ct);
    Task CancelAsync(Guid orderId, Guid actor, CancellationToken ct);
    Task FulfillAsync(Guid orderId, Guid originNode, Guid actor, CancellationToken ct);
    Task ConsignAsync(WebConsignmentRequest request, Guid actor, CancellationToken ct);
    Task ReleaseAsync(WebReleaseRequest request, Guid actor, CancellationToken ct);
    Task ApplyConsignmentsAsync(CancellationToken ct);
    Task ApplyReleasesAsync(CancellationToken ct);
}

/// <summary>
/// Web orders. Public use cases run only on the hub. Stock, expiry and payment rules live in the webstore procedures
/// (V047 to V051); this layer checks shape, roles and the node, and derives the order keys.
/// </summary>
public sealed class WebStoreService(IWebStoreStore store, NodeContext node)
{
    public const int MaxLines = 20;
    public const int MaxQty = 10;

    public async Task<PublicCatalogResponse> CatalogAsync(CancellationToken ct)
    {
        Guard.Kind(node, NodeKind.Cloud);
        return new PublicCatalogResponse(await store.CatalogAsync(ct), DateTimeOffset.UtcNow);
    }

    /// <summary>A wrong or missing token reads as an unknown order, so a guessed id learns nothing.</summary>
    public Task<WebOrderView?> FindOrderAsync(Guid orderId, string? accessToken, CancellationToken ct)
    {
        Guard.Kind(node, NodeKind.Cloud);
        return string.IsNullOrEmpty(accessToken) || accessToken.Length > 100
            ? Task.FromResult<WebOrderView?>(null)
            : store.FindOrderAsync(orderId, WebOrderKeys.Hash(accessToken), ct);
    }

    /// <summary>Checks and trims the request. Throws <c>web.validation</c> on the first problem.</summary>
    public static PublicOrderRequest Normalize(PublicOrderRequest? request)
    {
        if (request?.Lines is null || request.Contact is null || request.Shipping is null) throw Invalid("Faltan líneas, contacto o envío.");
        if (request.Lines.Length is 0 or > MaxLines) throw Invalid($"Entre 1 y {MaxLines} líneas.");
        var lines = request.Lines.Select(l => l is null ? throw Invalid("Línea vacía.")
            : new PublicOrderLine(Text(l.Sku, "sku", 100), l.Qty is >= 1 and <= MaxQty ? l.Qty : throw Invalid($"Cantidad entre 1 y {MaxQty}.")))
            .ToArray();
        if (lines.DistinctBy(l => l.Sku, StringComparer.Ordinal).Count() != lines.Length) throw Invalid("SKU repetido.");
        var email = Text(request.Contact.Email, "email", 254).ToLowerInvariant();
        if (!email.Contains('@') || email.StartsWith('@') || email.EndsWith('@')) throw Invalid("Correo inválido.");
        if (request.Provider is not ("manual" or "card")) throw Invalid("Forma de pago: manual o card.");
        if (request.Locale is not (null or "es" or "en")) throw Invalid("Idioma: es o en.");
        if (request.TurnstileToken is { Length: > 2048 }) throw Invalid("Token de verificación demasiado largo.");
        return new PublicOrderRequest(lines,
            new PublicOrderContact(Text(request.Contact.Name, "name", 180), email, Optional(request.Contact.Phone, "phone", 40)),
            new PublicOrderShipping(Text(request.Shipping.Zone, "zone", 20), Text(request.Shipping.Address, "address", 350),
                Text(request.Shipping.City, "city", 120), Optional(request.Shipping.Notes, "notes", 500)),
            request.Provider, request.Locale ?? "es", request.TurnstileToken);
    }

    public Task<WebOrderPlaced> CreateOrderAsync(NewWebOrder order, CancellationToken ct)
    {
        Guard.Kind(node, NodeKind.Cloud);
        return store.CreateOrderAsync(order, node.NodeId, ct);
    }

    /// <summary>The first line the catalog cannot cover, to name it in out_of_stock. Null when each line fits alone.</summary>
    public async Task<string?> ShortSkuAsync(PublicOrderLine[] lines, CancellationToken ct)
    {
        var available = (await store.CatalogAsync(ct)).ToDictionary(i => i.Sku, i => i.Available, StringComparer.Ordinal);
        return lines.FirstOrDefault(l => available.GetValueOrDefault(l.Sku) < l.Qty)?.Sku;
    }

    public Task<DueWebOrder[]> DueOrdersAsync(CancellationToken ct)
    {
        Guard.Kind(node, NodeKind.Cloud);
        return store.DueOrdersAsync(ct);
    }

    public Task<bool> ExpireAsync(Guid orderId, CancellationToken ct)
    {
        Guard.Kind(node, NodeKind.Cloud);
        return store.ExpireAsync(orderId, ct);
    }

    /// <summary>Records a provider-confirmed payment. The payment id comes from the provider's id, so a repeat is a no-op.</summary>
    public Task RecordVerifiedPaymentAsync(VerifiedPayment payment, CancellationToken ct)
    {
        Guard.Kind(node, NodeKind.Cloud);
        return store.RecordPaymentAsync(payment, WebOrderKeys.PaymentId(payment.Provider, payment.ExternalPaymentId), node.NodeId, null, ct);
    }

    public Task ApplyConsignmentsAsync(CancellationToken ct)
    {
        Guard.Kind(node, NodeKind.Cloud);
        return store.ApplyConsignmentsAsync(ct);
    }

    public Task ApplyReleasesAsync(CancellationToken ct)
    {
        Guard.Kind(node, NodeKind.Branch);
        return store.ApplyReleasesAsync(ct);
    }

    // Staff on the hub.

    public Task<WebOrderRow[]> ListOrdersAsync(Actor actor, string? status, CancellationToken ct)
    {
        Guard.Kind(node, NodeKind.Cloud);
        Guard.Role(actor, Roles.CloudReaders);
        if (status is { Length: > 24 }) throw Invalid("Estado inválido.");
        return store.ListOrdersAsync(string.IsNullOrWhiteSpace(status) ? null : status, ct);
    }

    /// <summary>A manual payment is audited by the staff id on the payment and the order.</summary>
    public Task RecordManualPaymentAsync(Actor actor, Guid orderId, ManualPaymentRequest request, CancellationToken ct)
    {
        Guard.Kind(node, NodeKind.Cloud);
        Guard.Role(actor, Roles.Approvers);
        if (request.AmountMinor <= 0) throw Invalid("Monto mayor que cero.");
        var currency = request.Currency is { Length: 3 } c ? c.ToUpperInvariant() : throw Invalid("Moneda de 3 letras.");
        var payment = new VerifiedPayment(orderId, ManualProviderCode, Text(request.Reference, "reference", 160), request.AmountMinor, currency);
        return store.RecordPaymentAsync(payment, WebOrderKeys.PaymentId(payment.Provider, payment.ExternalPaymentId), node.NodeId,
            actor.StaffId, ct);
    }

    public Task FulfillAsync(Actor actor, Guid orderId, CancellationToken ct)
    {
        Guard.Kind(node, NodeKind.Cloud);
        Guard.Role(actor, Roles.Approvers);
        return store.FulfillAsync(orderId, node.NodeId, actor.StaffId, ct);
    }

    public Task CancelAsync(Actor actor, Guid orderId, CancellationToken ct)
    {
        Guard.Kind(node, NodeKind.Cloud);
        Guard.Role(actor, Roles.Approvers);
        return store.CancelAsync(orderId, actor.StaffId, ct);
    }

    public Task ReleaseAsync(Actor actor, WebReleaseRequest request, CancellationToken ct)
    {
        Guard.Kind(node, NodeKind.Cloud);
        Guard.Role(actor, Roles.Approvers);
        if (request.Qty is < 1 or > 1000) throw Invalid("Cantidad entre 1 y 1000.");
        return store.ReleaseAsync(request with { Reason = Text(request.Reason, "reason", 300) }, actor.StaffId, ct);
    }

    // Branch.

    public Task ConsignAsync(Actor actor, WebConsignmentRequest request, CancellationToken ct)
    {
        Guard.BranchRole(actor, node, Roles.StockWorkers);
        if (request.Qty is < 1 or > 1000) throw Invalid("Cantidad entre 1 y 1000.");
        return store.ConsignAsync(request, actor.StaffId, ct);
    }

    public const string ManualProviderCode = "manual";

    private static SaviaException Invalid(string message) => Errors.Invalid("web.validation", message);

    private static string Text(string? value, string field, int max) =>
        string.IsNullOrWhiteSpace(value) || value.Trim().Length > max
            ? throw Invalid($"'{field}' es obligatorio y admite hasta {max} caracteres.")
            : value.Trim();

    private static string? Optional(string? value, string field, int max) =>
        string.IsNullOrWhiteSpace(value) ? null : Text(value, field, max);
}

/// <summary>
/// Keys derived from the buyer's Idempotency-Key, so a retry finds the same order and the same token without the hub
/// storing the token: the order id is a UUID v5 of the key, the token a SHA-256 of it, and the database keeps only the
/// token's hash.
/// </summary>
public static class WebOrderKeys
{
    private static readonly Guid OrderNamespace = new("6b1f0a52-9d3e-4c27-8f41-2a5c7e9b0d13");
    private static readonly Guid PaymentNamespace = new("0d7c4e91-3b6a-4f58-a2e0-91c3f5b8d264");
    private static readonly JsonSerializerOptions Canonical = new(JsonSerializerDefaults.Web);

    public static Guid OrderId(Guid key) => UuidV5(OrderNamespace, key.ToString("D"));

    public static string AccessToken(Guid key) =>
        Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes("order-token:" + key.ToString("D"))))
            .TrimEnd('=').Replace('+', '-').Replace('/', '_');

    public static byte[] Hash(string text) => SHA256.HashData(Encoding.UTF8.GetBytes(text));

    /// <summary>Hash of the normalized request without the bot token, which is single-use and changes on a retry.</summary>
    public static byte[] RequestHash(PublicOrderRequest normalized) =>
        SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(normalized with { TurnstileToken = null }, Canonical));

    public static Guid PaymentId(string provider, string externalPaymentId) => UuidV5(PaymentNamespace, provider + ":" + externalPaymentId);

    // RFC 9562 section 5.5. SHA-1 here names an id; it protects nothing.
    private static Guid UuidV5(Guid space, string name)
    {
        var hash = SHA1.HashData([.. space.ToByteArray(bigEndian: true), .. Encoding.UTF8.GetBytes(name)]);
        hash[6] = (byte)((hash[6] & 0x0F) | 0x50);
        hash[8] = (byte)((hash[8] & 0x3F) | 0x80);
        return new Guid(hash.AsSpan(0, 16), bigEndian: true);
    }
}
