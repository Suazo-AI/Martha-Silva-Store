using System.Text.Json.Serialization;

namespace Martha.Store.Api.Internal;

public sealed class InternalStockBalance
{
    public Guid ItemId { get; set; }
    public Guid LocationId { get; set; }
    public int OnHand { get; set; }
    public int Reserved { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public sealed class InternalStockMovement
{
    public Guid Id { get; set; }
    public Guid ItemId { get; set; }
    public Guid LocationId { get; set; }
    public Guid ActorId { get; set; }
    public Guid OperationId { get; set; }
    public string Kind { get; set; } = "";
    public int OnHandDelta { get; set; }
    public int ReservedDelta { get; set; }
    public int OnHandAfter { get; set; }
    public int ReservedAfter { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

public sealed class InternalStockAdjustment
{
    public Guid Id { get; set; }
    public Guid ItemId { get; set; }
    public Guid LocationId { get; set; }
    public int OnHandDelta { get; set; }
    public Guid ActorId { get; set; }
    public string Reason { get; set; } = "";
    public DateTimeOffset CreatedAt { get; set; }
}

public sealed class InternalSale
{
    public Guid Id { get; set; }
    public Guid LocationId { get; set; }
    public Guid? CustomerId { get; set; }
    public Guid ActorId { get; set; }
    public string Currency { get; set; } = "";
    public long TotalMinor { get; set; }
    public string State { get; set; } = "recorded";
    public DateTimeOffset CreatedAt { get; set; }
    public List<InternalSaleLine> Lines { get; set; } = [];
}

public sealed class InternalSaleLine
{
    public Guid Id { get; set; }
    public Guid SaleId { get; set; }
    public Guid ItemId { get; set; }
    public string Sku { get; set; } = "";
    public string Name { get; set; } = "";
    public int Quantity { get; set; }
    public int ReturnedQuantity { get; set; }
    public long UnitPriceMinor { get; set; }
    public long TotalMinor { get; set; }
}

// An internal record/stock reversal only. No bank, card processor or fiscal invoice is involved.
public sealed class InternalSaleReversal
{
    public Guid Id { get; set; }
    public Guid SaleId { get; set; }
    public Guid ActorId { get; set; }
    public string Kind { get; set; } = "";
    public string Reason { get; set; } = "";
    public long RecordedCreditMinor { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public List<InternalSaleReversalLine> Lines { get; set; } = [];
}

public sealed class InternalSaleReversalLine
{
    public Guid Id { get; set; }
    public Guid ReversalId { get; set; }
    public Guid SaleLineId { get; set; }
    public int Quantity { get; set; }
    public long RecordedCreditMinor { get; set; }
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record InternalSaleLineRequest(Guid ItemId, int Quantity);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record InternalSaleRequest(Guid LocationId, Guid? CustomerId, IReadOnlyList<InternalSaleLineRequest>? Lines);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record InternalStockAdjustmentRequest(Guid ItemId, Guid LocationId, int OnHandDelta, string? Reason);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record InternalSaleCancelRequest(string? Reason);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record InternalSaleReturnLineRequest(Guid SaleLineId, int Quantity);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record InternalSaleReturnRequest(string? Reason, IReadOnlyList<InternalSaleReturnLineRequest>? Lines);

public sealed record InternalStockView(Guid ItemId, Guid LocationId, int OnHand, int Reserved, int Available, DateTimeOffset UpdatedAt);
public sealed record InternalStockAdjustmentReceipt(Guid AdjustmentId, Guid ItemId, Guid LocationId, int OnHandDelta, Guid ActorId, string Reason, DateTimeOffset CreatedAt);
public sealed record InternalSaleLineReceipt(Guid SaleLineId, Guid ItemId, string Sku, string Name, int Quantity, int ReturnedQuantity, long UnitPriceMinor, long TotalMinor);
public sealed record InternalSaleReceipt(Guid SaleId, Guid LocationId, Guid? CustomerId, Guid ActorId, string Currency, long TotalMinor, string State,
    string PaymentStatus, DateTimeOffset CreatedAt, IReadOnlyList<InternalSaleLineReceipt> Lines);
public sealed record InternalSaleReversalLineReceipt(Guid SaleLineId, int Quantity, long RecordedCreditMinor);
public sealed record InternalSaleReversalReceipt(Guid ReversalId, Guid SaleId, Guid ActorId, string Kind, string SaleState, string Currency,
    long RecordedCreditMinor, string BankRefundStatus, string Reason, DateTimeOffset CreatedAt, IReadOnlyList<InternalSaleReversalLineReceipt> Lines);

public sealed record InternalCommercePage<T>(IReadOnlyList<T> Items, int Total, int Skip, int Take);
