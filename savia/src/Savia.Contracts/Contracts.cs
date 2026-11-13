namespace Savia.Contracts;

// HTTP contract of the SAVIA API, version 1. Clients are generated from the OpenAPI document.
// Money is always in minor units (centavos). Ids are created by the client so a retry is safe.

/// <summary>Body of every error response.</summary>
public sealed record ProblemResponse(string Code, string Message, string? TraceId);

// ---- auth
public sealed record LoginRequest(string LoginName, string Password);
public sealed record LoginResponse(string Token, DateTimeOffset ExpiresAt, Guid StaffId, string DisplayName, string[] Roles);
/// <summary>Who is signed in and where this node runs. Branch, location and names are null on the cloud node.</summary>
public sealed record MeResponse(Guid StaffId, string DisplayName, string[] Roles, string NodeKind, Guid NodeId, Guid? BranchId,
    Guid? LocationId = null, string? BranchName = null, string? StoreDisplayName = null, string? LocationName = null);

// ---- catalog
public sealed record ItemLookup(Guid ItemId, string Sku, string VariantName, long UnitPriceMinor, string CurrencyCode,
    string Status, string ProductName, string? SizeCode, string? ColorCode);
/// <summary>One variant found by name, SKU or code fragment. Stock is the store pool of this node's location; null on the cloud.</summary>
public sealed record ProductSearchRow(Guid ItemId, string Sku, string ProductName, string VariantName, string? SizeCode,
    string? ColorCode, string? Barcode, long UnitPriceMinor, string CurrencyCode, string Status, int? OnHand, int? Available);
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
public sealed record ScanSessionSummary(Guid ScanSessionId, Guid ContainerId, string Reference, string Status, Guid SupplierId,
    string SupplierName, DateTimeOffset CreatedAt, int ScanEvents, long MatchedUnits, long UnitsPendingReview);
/// <summary>
/// A matched line adds up every reading of one code for one variant (ScanId is null).
/// A code that is not matched is one line per reading, with its ScanId, so it can be resolved.
/// </summary>
public sealed record ScanSessionLine(Guid? ScanId, Guid? ItemId, string RawCode, string MatchStatus, long Quantity, int Scans,
    string? Sku, string? VariantName);
public sealed record ResolveScanRequest(Guid ItemId, string Reason);
public sealed record RejectScanRequest(string Reason);
public sealed record SupplierRow(Guid SupplierId, string Name);

// ---- stock and labels
public sealed record StockRow(Guid ItemId, string Sku, string VariantName, Guid LocationId, string Pool, int OnHand, int Reserved, int Available);
public sealed record LabelJob(Guid Id, Guid ItemId, string StoreName, string Sku, string Barcode, int CopiesRequested,
    int CopiesAcknowledged, string Status);
public sealed record AckPrintRequest(Guid AttemptId, int AttemptNo, bool Successful, string? PrinterResponse = null);

// ---- cash and sales
public sealed record OpenTillRequest(Guid TillId, Guid RegisterId, string CurrencyCode, long OpeningMinor, CashCountLine[]? Lines = null);
public sealed record SaleLine(int LineNumber, Guid ItemId, int Quantity, long UnitPriceMinor, long DiscountMinor = 0);
public sealed record SaleTender(int TenderNumber, string TenderKind, long AmountMinor, long? ReceivedMinor = null,
    long? ChangeMinor = null, string? Reference = null, Guid? CreditId = null);
public sealed record PostSaleRequest(Guid SaleId, Guid TillId, string CurrencyCode, SaleLine[] Lines, SaleTender[] Tenders, Guid? CustomerId = null, string? DiscountReason = null, string? StockExceptionNote = null);
public sealed record SaleResponse(Guid SaleId, long SubtotalMinor, long DiscountMinor, long TaxMinor, long TotalMinor, string Status);
public sealed record CashCountLine(long DenominationMinor, int Quantity);
public sealed record RecordCashCountRequest(Guid CashCountId, CashCountLine[] Lines);
public sealed record CloseTillRequest(Guid ClosureId, Guid CashCountId);
public sealed record CloseTillResponse(Guid ClosureId, long ExpectedMinor, long CountedMinor, long DifferenceMinor);
public sealed record RegisterRow(Guid RegisterId, string Code, string Name, Guid LocationId, Guid? OpenTillId, Guid? OpenTillCashierId);
/// <summary>Cash of one till. ExpectedCashMinor is the sum of its cash entries, the same figure the close uses.</summary>
public sealed record TillSummary(Guid TillId, Guid RegisterId, string RegisterName, Guid CashierId, string CashierName, string Status,
    string CurrencyCode, DateTimeOffset OpenedAt, long OpeningMinor, long CashSalesMinor, long CashRefundsMinor, long OtherCashMinor,
    long ExpectedCashMinor, int SaleCount, long SalesTotalMinor, Guid? ClosureId, CashCountLine[]? OpeningLines = null);

public sealed record CatalogProduct(Guid ProductId, string Name, string Type, ProductSearchRow[] Variants);
