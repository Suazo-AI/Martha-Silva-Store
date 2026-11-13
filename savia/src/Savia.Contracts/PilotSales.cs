namespace Savia.Contracts;
public sealed record ResolveExceptionRequest(string Reason);

public sealed record SalesPage(int Page, int PageSize, int Total, SaleHistoryRow[] Items);
public sealed record SaleHistoryRow(Guid SaleId, DateTime CreatedAt, string Status, string CurrencyCode, long TotalMinor,
    Guid? CustomerId, string? CustomerName, Guid CashierId, string CashierName, Guid? TillId);
public sealed record SaleDetailResponse(Guid SaleId, long SubtotalMinor, long DiscountMinor, long TaxMinor, long TotalMinor,
    string Status, string CurrencyCode, DateTime CreatedAt, Guid? CustomerId, string? CustomerName, Guid CashierId,
    string CashierName, Guid? TillId, string? RegisterName, SaleDetailLine[] Lines, SaleDetailTender[] Tenders, SaleReversal[] Reversals, string? ReceiptNumber = null, Guid? DiscountApprovedBy = null, string? DiscountReason = null);
public sealed record SaleDetailLine(Guid SaleLineId, int LineNumber, Guid ItemId, string Sku, string Name, string? SizeCode,
    int Quantity, int ReturnedQuantity, long UnitPriceMinor, long DiscountMinor, long TaxMinor, long TotalMinor, Guid? SellerId = null, string? SellerName = null);
public sealed record SaleDetailTender(Guid TenderId, string TenderKind, long AmountMinor, long? ReceivedMinor, long? ChangeMinor,
    string? Reference, Guid? CreditId, string Status);
public sealed record ReturnLine(Guid SaleLineId, int Quantity, string RestockPool);
public sealed record PostCreditReturnRequest(Guid ReversalId, Guid CreditId, Guid TillId, Guid CustomerId, string Reason, ReturnLine[] Lines);
public sealed record SaleReversal(Guid ReversalId, string Kind, string SettlementKind, string Reason, long CreditMinor,
    string CurrencyCode, string Status, DateTime CreatedAt, Guid? ApprovedBy, Guid ActorId, Guid? TillId, Guid? CreditId, ReversalLine[] Lines);
public sealed record ReversalLine(Guid SaleLineId, int Quantity, long CreditMinor, string RestockPool);
public sealed record CustomerRow(Guid CustomerId, string? CustomerCode, string DisplayName, string? Phone, string? Email);
public sealed record CustomerCreditRow(Guid CustomerId, string DisplayName, string? Phone, string? Email, Guid CreditId,
    string CurrencyCode, Guid BranchId, string BranchName, long AvailableMinor);
public sealed record DayReport(DateOnly Date, Guid BranchId, int SalesCount, long UnitsSold, DayTotal[] Totals,
    DayTenderTotal[] Tenders, DayReturn[] Returns, DayTill[] Tills, DayTopItem[] TopItems, DayRefundKind[]? RefundsByKind = null);
/// <summary>Returns of one day grouped by till and outcome: credit, cash, transfer or exchange.</summary>
public sealed record DayRefundKind(Guid? TillId, string Kind, int ReturnsCount, long AmountMinor, long CashOutMinor);
/// <summary>Cash refund, bank transfer refund or exchange. Store credit keeps <see cref="PostCreditReturnRequest"/>.</summary>
public sealed record PostReturnOutcomeRequest(Guid ReversalId, string Outcome, Guid TillId, string Reason, ReturnLine[] Lines,
    string? Reference = null, Guid? ExchangeSaleId = null, SaleLine[]? NewLines = null, SaleTender[]? NewTenders = null,
    string? DifferenceKind = null, string? DifferenceReference = null);
public sealed record ReturnWindowRequest(Guid ChangeId, int WindowDays, string Reason);
public sealed record ImportFileRequest(string FileName, string ContentBase64);
public sealed record ImportFile(string FileName, string[] Headers, string[][] Rows);
public sealed record ImportRow(int Row, string? Code, string? Sku, string? Name, string? Type, string? Size, string? Color,
    string? Cost, string? Price, string? Stock);
public sealed record ImportCatalogRequest(Guid BatchId, string FileName, ImportRow[] Rows);
public sealed record DayTotal(string CurrencyCode, int SaleCount, long TotalMinor);
public sealed record DayTenderTotal(string CurrencyCode, string TenderKind, int SaleCount, long TotalMinor);
public sealed record DayReturn(Guid ReversalId, Guid SaleId, string CurrencyCode, string SettlementKind, long CreditMinor, long UnitsReturned);
public sealed record DayTill(Guid TillId, Guid CashierId, string CashierName, string RegisterName, string CurrencyCode,
    string Status, DateTime OpenedAt, DateTime? ClosedAt, long ExpectedMinor, long? CountedMinor, long? DifferenceMinor,
    Guid? ClosureId, Guid? AccountingDocumentId, string? DocumentNumber, string? AccountingStatus,
    long? SaleGrossMinor, long? ReturnGrossMinor, long? NetSalesMinor);
public sealed record DayTopItem(Guid ItemId, string Sku, string Name, long UnitsSold);
