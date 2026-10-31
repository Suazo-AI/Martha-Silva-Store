using System.Text.Json.Serialization;

namespace Martha.Store.Api.Internal;

public static class InternalPurchaseStatus
{
    public const string Open = "open";
    public const string Partial = "partially_received";
    public const string Received = "received";
    public const string Cancelled = "cancelled";
    public static bool Receivable(string status) => status is Open or Partial;
}

public sealed class InternalPurchaseOrder
{
    public Guid Id { get; set; }
    public Guid SupplierId { get; set; }
    public Guid LocationId { get; set; }
    public string SupplierName { get; set; } = "";
    public string Currency { get; set; } = "";
    public string? Reference { get; set; }
    public string Status { get; set; } = InternalPurchaseStatus.Open;
    public long TotalMinor { get; set; }
    public Guid CreatedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public Guid UpdatedBy { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public Guid? CancelledBy { get; set; }
    public DateTimeOffset? CancelledAt { get; set; }
    public string? CancellationReason { get; set; }
    public List<InternalPurchaseOrderLine> Lines { get; set; } = [];
}

public sealed class InternalPurchaseOrderLine
{
    public Guid Id { get; set; }
    public Guid PurchaseOrderId { get; set; }
    public Guid ItemId { get; set; }
    public string ItemSku { get; set; } = "";
    public string ItemName { get; set; } = "";
    public int Quantity { get; set; }
    public int ReceivedQuantity { get; set; }
    public long UnitCostMinor { get; set; }
}

// A physical receipt has its own stable caller-supplied identity, in addition to
// the command runner's idempotency key. It cannot be reused for another payload.
public sealed class InternalPurchaseReceipt
{
    public Guid Id { get; set; }
    public Guid PurchaseOrderId { get; set; }
    public Guid LocationId { get; set; }
    public string Currency { get; set; } = "";
    public long TotalMinor { get; set; }
    public string Fingerprint { get; set; } = "";
    public string OrderStatusAfter { get; set; } = "";
    public Guid ReceivedBy { get; set; }
    public DateTimeOffset ReceivedAt { get; set; }
    public List<InternalPurchaseReceiptLine> Lines { get; set; } = [];
}

public sealed class InternalPurchaseReceiptLine
{
    public Guid Id { get; set; }
    public Guid ReceiptId { get; set; }
    public Guid PurchaseOrderId { get; set; }
    public Guid PurchaseOrderLineId { get; set; }
    public Guid ItemId { get; set; }
    public int Quantity { get; set; }
    public long UnitCostMinor { get; set; }
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record InternalPurchaseLineRequest([property: JsonRequired] Guid ItemId,
    [property: JsonRequired] int Quantity, [property: JsonRequired] long UnitCostMinor);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record InternalPurchaseOrderRequest([property: JsonRequired] Guid SupplierId,
    [property: JsonRequired] Guid LocationId, [property: JsonRequired] string Currency,
    [property: JsonRequired] IReadOnlyList<InternalPurchaseLineRequest>? Lines, string? Reference = null);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record InternalReceiptLineRequest([property: JsonRequired] Guid PurchaseOrderLineId,
    [property: JsonRequired] int Quantity);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record InternalPurchaseReceiptRequest([property: JsonRequired] Guid ReceiptId,
    [property: JsonRequired] IReadOnlyList<InternalReceiptLineRequest>? Lines);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record InternalPurchaseCancelRequest([property: JsonRequired] string Reason);

public sealed record InternalSupplyPage<T>(IReadOnlyList<T> Items, int Skip, int Take, bool HasMore);

public sealed record InternalPurchaseLineView(Guid Id, Guid ItemId, string Sku, string Name,
    int OrderedQuantity, int ReceivedQuantity, int RemainingReceivableQuantity, int CancelledQuantity,
    long UnitCostMinor, long TotalMinor);
public sealed record InternalPurchaseOrderView(Guid Id, Guid SupplierId, string SupplierName, Guid LocationId,
    string Currency, string? Reference, string Status, long TotalMinor, Guid CreatedBy, DateTimeOffset CreatedAt,
    Guid UpdatedBy, DateTimeOffset UpdatedAt, Guid? CancelledBy, DateTimeOffset? CancelledAt, string? CancellationReason,
    IReadOnlyList<InternalPurchaseLineView> Lines)
{
    public static InternalPurchaseOrderView From(InternalPurchaseOrder order) => new(order.Id, order.SupplierId,
        order.SupplierName, order.LocationId, order.Currency, order.Reference, order.Status, order.TotalMinor,
        order.CreatedBy, order.CreatedAt, order.UpdatedBy, order.UpdatedAt, order.CancelledBy, order.CancelledAt,
        order.CancellationReason, order.Lines.OrderBy(x => x.ItemSku).ThenBy(x => x.Id).Select(x => new InternalPurchaseLineView(
            x.Id, x.ItemId, x.ItemSku, x.ItemName, x.Quantity, x.ReceivedQuantity,
            InternalPurchaseStatus.Receivable(order.Status) ? x.Quantity - x.ReceivedQuantity : 0,
            order.Status == InternalPurchaseStatus.Cancelled ? x.Quantity - x.ReceivedQuantity : 0,
            x.UnitCostMinor, checked(x.UnitCostMinor * x.Quantity))).ToArray());
}
public sealed record InternalReceiptLineView(Guid PurchaseOrderLineId, Guid ItemId, int Quantity, long UnitCostMinor);
public sealed record InternalPurchaseReceiptView(Guid Id, Guid PurchaseOrderId, Guid LocationId, string Currency,
    long TotalMinor, string OrderStatusAfter, Guid ReceivedBy, DateTimeOffset ReceivedAt, IReadOnlyList<InternalReceiptLineView> Lines)
{
    public static InternalPurchaseReceiptView From(InternalPurchaseReceipt receipt) => new(receipt.Id,
        receipt.PurchaseOrderId, receipt.LocationId, receipt.Currency, receipt.TotalMinor, receipt.OrderStatusAfter,
        receipt.ReceivedBy, receipt.ReceivedAt, receipt.Lines.OrderBy(x => x.ItemId).Select(x => new InternalReceiptLineView(
            x.PurchaseOrderLineId, x.ItemId, x.Quantity, x.UnitCostMinor)).ToArray());
}
