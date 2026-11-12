namespace Savia.Contracts;

// HTTP contract of the SAVIA API, version 1. Clients are generated from the OpenAPI document.
// Money is always in minor units (centavos). Ids are created by the client so a retry is safe.

/// <summary>Body of every error response.</summary>
public sealed record ProblemResponse(string Code, string Message, string? TraceId);

// ---- auth
public sealed record LoginRequest(string LoginName, string Password);
public sealed record LoginResponse(string Token, DateTimeOffset ExpiresAt, Guid StaffId, string DisplayName, string[] Roles);
public sealed record MeResponse(Guid StaffId, string DisplayName, string[] Roles, string NodeKind, Guid NodeId, Guid? BranchId);

// ---- catalog
public sealed record ItemLookup(Guid ItemId, string Sku, string VariantName, long UnitPriceMinor, string CurrencyCode,
    string Status, string ProductName, string? SizeCode, string? ColorCode);
public sealed record RegisterProductRequest(Guid ProductId, string Name);
public sealed record RegisterItemRequest(Guid ItemId, Guid ProductId, string Sku, string VariantName, string CurrencyCode,
    long UnitPriceMinor, long? UnitCostMinor, string? Barcode, Guid? SizeId = null, Guid? ColorId = null,
    Guid? SupplierId = null, string? SupplierSku = null);

// ---- receiving
public sealed record OpenScanSessionRequest(Guid ContainerId, Guid ScanSessionId, string Reference, Guid SupplierId, string? DeviceCode = null);
public sealed record RecordScanRequest(Guid ScanId, string RawCode, int Quantity = 1, string? DeviceCode = null);
public sealed record ScanResult(Guid ScanId, Guid? ItemId, string MatchStatus, int Quantity);
public sealed record ScanSessionProgress(Guid ScanSessionId, Guid ContainerId, string Reference, string Status,
    int ScanEvents, long MatchedUnits, long UnitsPendingReview);
public sealed record PostScanSessionResponse(Guid ReceiptId);

// ---- stock and labels
public sealed record StockRow(Guid ItemId, string Sku, string VariantName, Guid LocationId, string Pool, int OnHand, int Reserved, int Available);
public sealed record LabelJob(Guid Id, Guid ItemId, string StoreName, string Sku, string Barcode, int CopiesRequested,
    int CopiesAcknowledged, string Status);
public sealed record AckPrintRequest(Guid AttemptId, int AttemptNo, bool Successful, string? PrinterResponse = null);

// ---- cash and sales
public sealed record OpenTillRequest(Guid TillId, Guid RegisterId, string CurrencyCode, long OpeningMinor);
public sealed record SaleLine(int LineNumber, Guid ItemId, int Quantity, long UnitPriceMinor, long DiscountMinor = 0);
public sealed record SaleTender(int TenderNumber, string TenderKind, long AmountMinor, long? ReceivedMinor = null,
    long? ChangeMinor = null, string? Reference = null, Guid? CreditId = null);
public sealed record PostSaleRequest(Guid SaleId, Guid TillId, string CurrencyCode, SaleLine[] Lines, SaleTender[] Tenders, Guid? CustomerId = null);
public sealed record SaleResponse(Guid SaleId, long SubtotalMinor, long DiscountMinor, long TaxMinor, long TotalMinor, string Status);
public sealed record CashCountLine(long DenominationMinor, int Quantity);
public sealed record RecordCashCountRequest(Guid CashCountId, CashCountLine[] Lines);
public sealed record CloseTillRequest(Guid ClosureId, Guid CashCountId);
public sealed record CloseTillResponse(Guid ClosureId, long ExpectedMinor, long CountedMinor, long DifferenceMinor);
