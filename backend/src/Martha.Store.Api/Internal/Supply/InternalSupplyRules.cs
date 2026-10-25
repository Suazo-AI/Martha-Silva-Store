namespace Martha.Store.Api.Internal;

public static class InternalSupplyRules
{
    public const int MaxLines = 100;
    public const int MaxQuantity = 1_000_000;

    public static string? Validate(InternalPurchaseOrderRequest? request)
    {
        if (request is null || request.SupplierId == Guid.Empty || request.LocationId == Guid.Empty ||
            !InternalRules.ValidCurrency(request.Currency) || request.Reference is { Length: > 100 } ||
            request.Reference?.Any(char.IsControl) == true || request.Lines is not { Count: >= 1 and <= MaxLines })
            return "invalid_purchase_order";
        var items = new HashSet<Guid>();
        long total = 0;
        foreach (var line in request.Lines)
        {
            if (line is null || line.ItemId == Guid.Empty || !items.Add(line.ItemId) ||
                line.Quantity is < 1 or > MaxQuantity || line.UnitCostMinor < 0 ||
                line.UnitCostMinor > InternalRules.MaxMinor / line.Quantity)
                return "invalid_purchase_line";
            var cost = line.UnitCostMinor * line.Quantity;
            if (cost > InternalRules.MaxMinor - total) return "purchase_total_too_large";
            total += cost;
        }
        return null;
    }

    public static string? Validate(InternalPurchaseReceiptRequest? request)
    {
        if (request is null || request.ReceiptId == Guid.Empty || request.Lines is not { Count: >= 1 and <= MaxLines })
            return "invalid_purchase_receipt";
        var lines = new HashSet<Guid>();
        return request.Lines.Any(x => x is null || x.PurchaseOrderLineId == Guid.Empty ||
            !lines.Add(x.PurchaseOrderLineId) || x.Quantity is < 1 or > MaxQuantity) ? "invalid_receipt_line" : null;
    }

    public static string? Validate(InternalPurchaseCancelRequest? request) =>
        request is null || string.IsNullOrWhiteSpace(request.Reason) || request.Reason.Length > 500 ||
        request.Reason.Any(char.IsControl) ? "invalid_cancellation_reason" : null;

    public static bool CanReceive(int ordered, int received, int quantity) =>
        ordered is >= 1 and <= MaxQuantity && received >= 0 && received <= ordered &&
        quantity is >= 1 and <= MaxQuantity && quantity <= ordered - received;

    public static string ReceiptFingerprint(Guid orderId, InternalPurchaseReceiptRequest request) =>
        InternalRules.Fingerprint(new { OrderId = orderId, request.ReceiptId,
            Lines = request.Lines!.OrderBy(x => x.PurchaseOrderLineId).ToArray() });

    public static string OrderFingerprint(InternalPurchaseOrderRequest request) =>
        InternalRules.Fingerprint(new { request.SupplierId, request.LocationId, request.Currency,
            Reference = request.Reference?.Trim(), Lines = request.Lines!.OrderBy(x => x.ItemId).ToArray() });
}
