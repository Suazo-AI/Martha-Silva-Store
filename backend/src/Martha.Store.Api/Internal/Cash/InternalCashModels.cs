using System.Text.Json.Serialization;

namespace Martha.Store.Api.Internal;

public sealed class InternalCashTill
{
    public Guid Id { get; set; }
    public Guid CashierId { get; set; }
    public Guid LocationId { get; set; }
    public string Currency { get; set; } = "";
    public int Exponent { get; set; }
    public DateTimeOffset OpenedAt { get; set; }
    public DateTimeOffset? ClosedAt { get; set; }
}
public sealed class InternalCashEntry
{
    public Guid Id { get; set; }
    public Guid TillId { get; set; }
    public Guid CashierId { get; set; }
    public Guid ActorId { get; set; }
    public string Currency { get; set; } = "";
    public int Exponent { get; set; }
    public string Kind { get; set; } = "";
    public long DeltaMinor { get; set; }
    public long ReceivedMinor { get; set; }
    public long ChangeMinor { get; set; }
    public Guid? SaleId { get; set; }
    public Guid? ReversalId { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}
public sealed class InternalCashClose
{
    public Guid Id { get; set; }
    public Guid TillId { get; set; }
    public Guid ActorId { get; set; }
    public long ExpectedMinor { get; set; }
    public long CountedMinor { get; set; }
    public long DifferenceMinor { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

// No default currency or exponent: deployment must explicitly select both.
public sealed record InternalCashOptions(string Currency, int Exponent)
{
    public bool Valid => InternalRules.ValidCurrency(Currency) && Exponent is >= 0 and <= 6;
}
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
[JsonNumberHandling(JsonNumberHandling.Strict)]
public sealed record InternalCashOpenRequest(Guid LocationId, string Currency, [property: JsonRequired] long OpeningMinor);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
[JsonNumberHandling(JsonNumberHandling.Strict)]
public sealed record InternalCashSaleRequest(Guid TillId, Guid? CustomerId,
    IReadOnlyList<InternalSaleLineRequest>? Lines, string Currency, [property: JsonRequired] long ReceivedMinor);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
[JsonNumberHandling(JsonNumberHandling.Strict)]
public sealed record InternalCashRefundRequest(Guid PayingTillId, string Currency, string? Reason,
    IReadOnlyList<InternalSaleReturnLineRequest>? Lines);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
[JsonNumberHandling(JsonNumberHandling.Strict)]
public sealed record InternalCashCloseRequest([property: JsonRequired] long CountedMinor);

public sealed record InternalCashOpenReceipt(InternalCashTill Till, InternalCashEntry Opening);
public sealed record InternalCashSaleReceipt(InternalSaleReceipt Sale, InternalCashEntry Payment,
    Guid LocationId, int Exponent, long ChangeMinor, string PaymentStatus);
public sealed record InternalCashRefundReceipt(InternalSaleReversalReceipt Reversal, InternalCashEntry Refund,
    Guid LocationId, long RefundableMinor, string PaymentStatus);
public sealed record InternalCashCloseReceipt(InternalCashTill Till, InternalCashClose Close);

public static class InternalCashRules
{
    public static bool Amount(long value) => value is >= 0 and <= InternalRules.MaxMinor;
    public static bool TryChange(long total, long received, out long change)
    {
        change = 0;
        if (!Amount(total) || !Amount(received) || received < total) return false;
        change = checked(received - total); return true;
    }
    public static bool TryBalance(IEnumerable<long> deltas, out long balance)
    {
        balance = 0;
        try { foreach (var delta in deltas) balance = checked(balance + delta); }
        catch (OverflowException) { return false; }
        return Amount(balance);
    }
}
