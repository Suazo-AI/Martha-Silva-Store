namespace Savia.Contracts;

// Public order path (savia/docs/webstore/ORDER-PATH.md). Field names follow ORDER-PATH-SPEC 4.2.

public sealed record PublicCatalogItem(string Sku, Guid ProductId, string Name, string? Size, string? Color, long UnitPriceMinor,
    string Currency, int Available);

/// <summary><c>available</c> is what one order can reserve, capped at 10 so the exact stock does not leak.</summary>
public sealed record PublicCatalogResponse(PublicCatalogItem[] Items, DateTimeOffset AsOf);

public sealed record PublicOrderLine(string Sku, int Qty);

public sealed record PublicOrderContact(string Name, string Email, string? Phone);

public sealed record PublicOrderShipping(string Zone, string Address, string City, string? Notes);

/// <summary><c>provider</c> is <c>manual</c> or <c>card</c>; the hub picks the card gateway.</summary>
public sealed record PublicOrderRequest(PublicOrderLine[] Lines, PublicOrderContact Contact, PublicOrderShipping Shipping,
    string Provider, string? Locale, string? TurnstileToken);

/// <summary><c>kind</c> is <c>redirect</c> (go to <c>url</c>) or <c>instructions</c> (show them).</summary>
public sealed record PaymentStartResponse(string Provider, string Label, string Kind, string? Url, string? Method, string? Instructions);

/// <summary><c>payment</c> is null when a retry finds the order no longer reserved (paid, expired or cancelled).</summary>
public sealed record PublicOrderCreated(Guid OrderId, string Code, string AccessToken, string Status, long TotalMinor,
    long ShippingMinor, string Currency, DateTimeOffset ExpiresAt, PaymentStartResponse? Payment);

public sealed record PublicOrderStatus(string Code, string Status, long TotalMinor, string Currency, DateTimeOffset ExpiresAt,
    PublicOrderLine[] Lines);

/// <summary>The public routes answer this instead of <see cref="ProblemResponse"/>, so a buyer sees which SKU ran out.</summary>
public sealed record PublicProblem(string Code, string Message, string TraceId, string? Sku = null);

/// <summary>Staff records a payment checked by hand (bank transfer, Compra-Click). It is not a card payment.</summary>
public sealed record ManualPaymentRequest(long AmountMinor, string Currency, string Reference);

/// <summary>A branch hands store stock to the web. <c>consignmentId</c> makes a retry safe.</summary>
public sealed record WebConsignmentRequest(Guid ConsignmentId, Guid ItemId, int Qty, Guid FromLocationId);

/// <summary>Staff on the hub returns web stock to the store it came from.</summary>
public sealed record WebReleaseRequest(Guid ReleaseId, Guid ItemId, Guid ToLocationId, int Qty, string Reason);

public sealed record WebOrderRow(Guid Id, string Code, string Status, long TotalMinor, long ShippingMinor, string Currency,
    DateTimeOffset CreatedAt, DateTimeOffset? ExpiresAt, string? Provider, string? Zone, string Name, string Email, string? Phone,
    string City, string Address, string? Notes, string? SourceStore, PublicOrderLine[] Lines);
