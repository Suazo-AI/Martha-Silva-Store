namespace Savia.Contracts;

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
public sealed record QualityRequest(Guid CheckId, Guid ItemId, int Buena, int Danada, int Manchada, int MalOlor, int Faltante, string Reason);
