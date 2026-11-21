using System.Text.Json;
using Savia.Application;
using Savia.Contracts;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

public sealed class CatalogStore(SqlGateway sql) : ICatalogStore, ICatalogMaintenanceStore
{
    public async Task<IReadOnlyList<CatalogProduct>> ListAsync(Guid locationId, CancellationToken ct)
    {
        var rows = await sql.QueryProcAsync("catalog.usp_ListSaleCatalog", r => r.GetString(0), ct, P("@LocationId", locationId));
        return JsonSerializer.Deserialize<CatalogProduct[]>(string.Concat(rows), SqlJson.Web) ?? [];
    }

    public async Task<IReadOnlyList<ItemLookup>> LookupAsync(string rawCode, Guid? supplierId, CancellationToken ct) =>
        await sql.QueryProcAsync("catalog.usp_LookupByScan",
            r => new ItemLookup(r.GetGuid(0), r.GetString(1), r.GetString(2), r.GetInt64(3), r.GetString(4), r.GetString(5),
                r.GetString(6), r.StringOrNull(7), r.StringOrNull(8)),
            ct, P("@RawCode", rawCode), P("@SupplierId", supplierId));

    public Task RegisterProductAsync(RegisterProductRequest request, Guid actorId, Guid nodeId, CancellationToken ct) =>
        sql.ExecProcAsync("catalog.usp_RegisterProduct", ct, P("@ProductId", request.ProductId), P("@Name", request.Name),
            P("@OriginNodeId", nodeId), P("@EventId", Guid.NewGuid()), P("@ActorId", actorId));

    public Task RegisterItemAsync(RegisterItemRequest request, Guid actorId, Guid nodeId, CancellationToken ct) =>
        sql.ExecProcAsync("catalog.usp_RegisterItem", ct, P("@ProductId", request.ProductId), P("@Sku", request.Sku),
            P("@VariantName", request.VariantName), P("@CurrencyCode", request.CurrencyCode),
            P("@UnitPriceMinor", request.UnitPriceMinor), P("@ItemId", request.ItemId), P("@OriginNodeId", nodeId),
            P("@EventId", Guid.NewGuid()), P("@SizeId", request.SizeId), P("@ColorId", request.ColorId),
            P("@Barcode", request.Barcode), P("@SupplierId", request.SupplierId), P("@SupplierSku", request.SupplierSku),
            P("@UnitCostMinor", request.UnitCostMinor), P("@ActorId", actorId));

    // Accent- and case-insensitive containment over product name, variant name, SKU and active codes.
    // Stock is the sellable 'store' pool of this node's location; the cloud node has no location and returns null.
    public async Task<IReadOnlyList<ProductSearchRow>> SearchAsync(string text, Guid? locationId, int limit, CancellationToken ct)
    {
        var pattern = "%" + text.Replace("\\", "\\\\").Replace("%", "\\%").Replace("_", "\\_").Replace("[", "\\[") + "%";
        return await sql.QueryAsync("""
            SELECT TOP (@limit) i.Id,i.Sku,p.Name,i.VariantName,sz.Code,co.Code,
              (SELECT TOP (1) x.RawCode FROM catalog.ItemIdentifiers x
                WHERE x.ItemId=i.Id AND x.Kind='barcode' AND x.IsActive=1 ORDER BY x.IsPrimary DESC,x.CreatedAt,x.Id),
              i.UnitPriceMinor,i.CurrencyCode,i.Status,
              CASE WHEN @location IS NULL THEN NULL ELSE ISNULL(st.OnHand,0) END,
              CASE WHEN @location IS NULL THEN NULL ELSE ISNULL(st.Available,0) END
            FROM catalog.Items i
            JOIN catalog.Products p ON p.Id=i.ProductId
            LEFT JOIN catalog.Sizes sz ON sz.Id=i.SizeId
            LEFT JOIN catalog.Colors co ON co.Id=i.ColorId
            OUTER APPLY (SELECT SUM(v.OnHand) AS OnHand,SUM(v.Available) AS Available FROM inventory.vw_StockAvailable v
                         WHERE v.ItemId=i.Id AND v.LocationId=@location AND v.Pool='store') st
            WHERE i.Status IN ('active','draft')
              AND (p.Name COLLATE Latin1_General_100_CI_AI LIKE @pattern ESCAPE '\'
                OR i.VariantName COLLATE Latin1_General_100_CI_AI LIKE @pattern ESCAPE '\'
                OR i.Sku COLLATE Latin1_General_100_CI_AI LIKE @pattern ESCAPE '\'
                OR EXISTS (SELECT 1 FROM catalog.ItemIdentifiers x WHERE x.ItemId=i.Id AND x.IsActive=1
                           AND x.RawCode COLLATE Latin1_General_100_CI_AI LIKE @pattern ESCAPE '\'))
            ORDER BY p.Name,i.Sku
            """, r => new ProductSearchRow(r.GetGuid(0), r.GetString(1), r.GetString(2), r.GetString(3), r.StringOrNull(4),
                r.StringOrNull(5), r.StringOrNull(6), r.GetInt64(7), r.GetString(8), r.GetString(9), r.IntOrNull(10), r.IntOrNull(11)),
            ct, P("@limit", limit), P("@location", locationId), P("@pattern", pattern));
    }

    public Task<JsonElement> ItemValuesAsync(Guid branch, Guid actor, string query, CancellationToken ct) =>
        sql.ReadElement("catalog.usp_GetItemValues", ct, P("@BranchId", branch), P("@ActorId", actor), P("@Query", query));

    public Task SetItemValuesAsync(Guid item, ItemValuesRequest request, Guid actor, Guid node, CancellationToken ct) =>
        sql.ExecProcAsync("catalog.usp_SetItemValues", ct, P("@ChangeId", request.ChangeId), P("@ItemId", item),
            P("@NewPriceMinor", request.PriceMinor), P("@NewCostMinor", request.CostMinor), P("@ActorId", actor),
            P("@OriginNodeId", node), P("@Reason", request.Reason));

    public Task<JsonElement> ImportCatalogAsync(Guid branch, Guid location, ImportCatalogRequest request,
        Guid actor, Guid node, bool commit, CancellationToken ct) =>
        sql.ReadElement("catalog.usp_ImportCatalog", ct, P("@BatchId", request.BatchId), P("@BranchId", branch), P("@LocationId", location),
            P("@ActorId", actor), P("@FileName", request.FileName), P("@RowsJson", JsonSerializer.Serialize(request.Rows, SqlJson.Web)),
            P("@OriginNodeId", node), P("@Commit", commit));
}
