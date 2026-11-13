namespace Savia.Contracts;

public sealed record ItemLookup(Guid ItemId, string Sku, string VariantName, long? UnitPriceMinor, string CurrencyCode,
    string Status, string ProductName, string? SizeCode, string? ColorCode);
/// <summary>One variant found by name, SKU or code fragment. Stock is the store pool of this node's location; null on the cloud.</summary>
public sealed record ProductSearchRow(Guid ItemId, string Sku, string ProductName, string VariantName, string? SizeCode,
    string? ColorCode, string? Barcode, long? UnitPriceMinor, string CurrencyCode, string Status, int? OnHand, int? Available);
public sealed record CatalogProduct(Guid ProductId, string Name, string Type, ProductSearchRow[] Variants);
public sealed record RegisterProductRequest(Guid ProductId, string Name);
public sealed record RegisterItemRequest(Guid ItemId, Guid ProductId, string Sku, string VariantName, string CurrencyCode,
    long UnitPriceMinor, long? UnitCostMinor, string? Barcode, Guid? SizeId = null, Guid? ColorId = null,
    Guid? SupplierId = null, string? SupplierSku = null);
public sealed record ItemValuesRequest(Guid ChangeId, long PriceMinor, long CostMinor, string Reason);
public sealed record ImportFileRequest(string FileName, string ContentBase64);
public sealed record ImportFile(string FileName, string[] Headers, string[][] Rows);
public sealed record ImportRow(int Row, string? Code, string? Sku, string? Name, string? Type, string? Size, string? Color,
    string? Cost, string? Price, string? Stock);
public sealed record ImportCatalogRequest(Guid BatchId, string FileName, ImportRow[] Rows);
