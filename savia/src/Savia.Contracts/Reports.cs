namespace Savia.Contracts;

public sealed record DayReport(DateOnly Date, Guid BranchId, int SalesCount, long UnitsSold, DayTotal[] Totals,
    DayTenderTotal[] Tenders, DayReturn[] Returns, DayTill[] Tills, DayTopItem[] TopItems, DayRefundKind[]? RefundsByKind = null);
/// <summary>Returns of one day grouped by till and outcome: credit, cash, transfer or exchange.</summary>
public sealed record DayRefundKind(Guid? TillId, string Kind, int ReturnsCount, long AmountMinor, long CashOutMinor);
public sealed record DayTotal(string CurrencyCode, int SaleCount, long TotalMinor);
public sealed record DayTenderTotal(string CurrencyCode, string TenderKind, int SaleCount, long TotalMinor);
public sealed record DayReturn(Guid ReversalId, Guid SaleId, string CurrencyCode, string SettlementKind, long CreditMinor, long UnitsReturned);
public sealed record DayTill(Guid TillId, Guid CashierId, string CashierName, string RegisterName, string CurrencyCode,
    string Status, DateTime OpenedAt, DateTime? ClosedAt, long ExpectedMinor, long? CountedMinor, long? DifferenceMinor,
    Guid? ClosureId, Guid? AccountingDocumentId, string? DocumentNumber, string? AccountingStatus,
    long? SaleGrossMinor, long? ReturnGrossMinor, long? NetSalesMinor,
    long? UsdExpectedMinor = null, long? UsdCountedMinor = null, long? UsdDifferenceMinor = null);
public sealed record DayTopItem(Guid ItemId, string Sku, string Name, long UnitsSold);
