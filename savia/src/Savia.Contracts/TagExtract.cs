namespace Savia.Contracts;

/// <summary>
/// Answer of POST /api/v1/inventory/tag-extract. Every field may be null: the phone form stays editable.
/// <see cref="Confidence"/> holds 0..1 per field name (barcode, sku, name, brand, size, color, priceMinor, composition).
/// <see cref="MatchedItem"/> is set when the barcode or the SKU already exists; then the client adds to the reception
/// instead of creating a duplicate. <see cref="Source"/> is "match" (OCR skipped), "ocr" or "none" (OCR failed).
/// </summary>
public sealed record TagExtractResponse(
    string? Barcode, string? Sku, string? Name, string? Brand, string? Size, string? Color, long? PriceMinor,
    string? Composition, IReadOnlyDictionary<string, double> Confidence, string RawText, TagMatchedItem? MatchedItem,
    string Source, string Engine, int ElapsedMs, string? Warning);

/// <summary>An existing variant found by barcode or SKU. <see cref="MatchedBy"/> is "barcode" or "sku".</summary>
public sealed record TagMatchedItem(Guid ItemId, string Sku, string ProductName, string VariantName, string? SizeCode,
    string? ColorCode, long? UnitPriceMinor, string MatchedBy);
