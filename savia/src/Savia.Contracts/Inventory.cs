namespace Savia.Contracts;

public sealed record StockRow(Guid ItemId, string Sku, string VariantName, Guid LocationId, string Pool, int OnHand, int Reserved, int Available);
public sealed record LabelJob(Guid Id, Guid ItemId, string StoreName, string Sku, string Barcode, int CopiesRequested,
    int CopiesAcknowledged, string Status);
public sealed record AckPrintRequest(Guid AttemptId, int AttemptNo, bool Successful, string? PrinterResponse = null);
public sealed record ResolveExceptionRequest(string Reason);
