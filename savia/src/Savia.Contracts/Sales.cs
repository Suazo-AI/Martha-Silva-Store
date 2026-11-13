namespace Savia.Contracts;

public sealed record SaleLine(int LineNumber, Guid ItemId, int Quantity, long UnitPriceMinor, long DiscountMinor = 0, Guid? SellerId = null);
public sealed record SaleTender(int TenderNumber, string TenderKind, long AmountMinor, long? ReceivedMinor = null,
    long? ChangeMinor = null, string? Reference = null, Guid? CreditId = null);
public sealed record PostSaleRequest(Guid SaleId, Guid TillId, string CurrencyCode, SaleLine[] Lines, SaleTender[] Tenders,
    Guid? CustomerId = null, string? DiscountReason = null, string? StockExceptionNote = null);
public sealed record SaleResponse(Guid SaleId, long SubtotalMinor, long DiscountMinor, long TaxMinor, long TotalMinor, string Status);
public sealed record SalesPage(int Page, int PageSize, int Total, SaleHistoryRow[] Items);
public sealed record SaleHistoryRow(Guid SaleId, DateTime CreatedAt, string Status, string CurrencyCode, long TotalMinor,
    Guid? CustomerId, string? CustomerName, Guid CashierId, string CashierName, Guid? TillId);
public sealed record SaleDetailResponse(Guid SaleId, long SubtotalMinor, long DiscountMinor, long TaxMinor, long TotalMinor,
    string Status, string CurrencyCode, DateTime CreatedAt, Guid? CustomerId, string? CustomerName, Guid CashierId,
    string CashierName, Guid? TillId, string? RegisterName, SaleDetailLine[] Lines, SaleDetailTender[] Tenders, SaleReversal[] Reversals,
    string? ReceiptNumber = null, Guid? DiscountApprovedBy = null, string? DiscountReason = null);
public sealed record SaleDetailLine(Guid SaleLineId, int LineNumber, Guid ItemId, string Sku, string Name, string? SizeCode,
    int Quantity, int ReturnedQuantity, long UnitPriceMinor, long DiscountMinor, long TaxMinor, long TotalMinor,
    Guid? SellerId = null, string? SellerName = null);
public sealed record SaleDetailTender(Guid TenderId, string TenderKind, long AmountMinor, long? ReceivedMinor, long? ChangeMinor,
    string? Reference, Guid? CreditId, string Status);
public sealed record SaleReversal(Guid ReversalId, string Kind, string SettlementKind, string Reason, long CreditMinor,
    string CurrencyCode, string Status, DateTime CreatedAt, Guid? ApprovedBy, Guid ActorId, Guid? TillId, Guid? CreditId, ReversalLine[] Lines);
public sealed record ReversalLine(Guid SaleLineId, int Quantity, long CreditMinor, string RestockPool);
