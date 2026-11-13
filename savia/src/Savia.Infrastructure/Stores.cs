using System.Data;
using System.Text.Json;
using Savia.Application;
using Savia.Contracts;
using Savia.Domain;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

// Ports implemented with stored procedures (writes) and plain SELECT (reads).
// A write never touches an operational table directly: the procedure owns the rule (ADR-001 D2).

public sealed class CatalogStore(SqlGateway sql) : ICatalogStore
{
    public async Task<IReadOnlyList<CatalogProduct>> ListAsync(Guid locationId, CancellationToken ct)
    {
        var rows = await sql.QueryProcAsync("catalog.usp_ListSaleCatalog", r => r.GetString(0), ct, P("@LocationId", locationId));
        return JsonSerializer.Deserialize<CatalogProduct[]>(string.Concat(rows), new JsonSerializerOptions(JsonSerializerDefaults.Web)) ?? [];
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
}

public sealed class ReceivingStore(SqlGateway sql) : IReceivingStore
{
    public Task OpenSessionAsync(OpenScanSessionRequest request, Guid locationId, Guid actorId, CancellationToken ct) =>
        sql.ExecProcAsync("receiving.usp_OpenScanSession", ct, P("@ContainerId", request.ContainerId),
            P("@ScanSessionId", request.ScanSessionId), P("@Reference", request.Reference), P("@SupplierId", request.SupplierId),
            P("@LocationId", locationId), P("@ActorId", actorId), P("@DeviceCode", request.DeviceCode));

    public async Task<ScanResult> RecordScanAsync(Guid sessionId, RecordScanRequest request, Guid actorId, CancellationToken ct)
    {
        // The procedure names its first column ScanId on the first call and Id on a retry; read by position.
        var rows = await sql.QueryProcAsync("receiving.usp_RecordScan",
            r => new ScanResult(r.GetGuid(0), r.GuidOrNull(1), r.GetString(2), r.GetInt32(3)), ct,
            P("@ScanId", request.ScanId), P("@ScanSessionId", sessionId), P("@RawCode", request.RawCode),
            P("@Quantity", request.Quantity), P("@DeviceCode", request.DeviceCode), P("@ActorId", actorId));
        return rows.Count == 1 ? rows[0] : throw new SaviaException(DbErrors.FromSql(0, ""));
    }

    public Task ApproveAsync(Guid sessionId, Guid reviewerId, CancellationToken ct) =>
        sql.ExecProcAsync("receiving.usp_ApproveScanSession", ct, P("@ScanSessionId", sessionId), P("@ReviewerId", reviewerId));

    public async Task<Guid> PostAsync(Guid sessionId, Guid actorId, Guid nodeId, string currencyCode, CancellationToken ct)
    {
        var receipt = Out("@ReceiptId", SqlDbType.UniqueIdentifier);
        await sql.ExecProcAsync("receiving.usp_PostScanSession", ct, P("@ScanSessionId", sessionId), P("@ActorId", actorId),
            P("@OriginNodeId", nodeId), receipt, P("@CurrencyCode", currencyCode));
        return (Guid)receipt.Value;
    }

    public Task<ScanSessionProgress?> GetProgressAsync(Guid sessionId, Guid locationId, CancellationToken ct) => sql.FirstAsync(
        "SELECT ScanSessionId,ContainerId,Reference,Status,ScanEvents,MatchedUnits,UnitsPendingReview FROM receiving.vw_SessionProgress WHERE ScanSessionId=@id AND LocationId=@location",
        r => new ScanSessionProgress(r.GetGuid(0), r.GetGuid(1), r.GetString(2), r.GetString(3), r.GetInt32(4), r.GetInt64(5), r.GetInt64(6)),
        ct, P("@id", sessionId), P("@location", locationId));

    public async Task<IReadOnlyList<ScanSessionSummary>> ListSessionsAsync(Guid locationId, bool openOnly, int limit, CancellationToken ct) =>
        await sql.QueryAsync("""
            SELECT TOP (@limit) v.ScanSessionId,v.ContainerId,v.Reference,v.Status,c.SupplierId,su.DisplayName,s.CreatedAt,
                   v.ScanEvents,v.MatchedUnits,v.UnitsPendingReview
            FROM receiving.vw_SessionProgress v
            JOIN receiving.ScanSessions s ON s.Id=v.ScanSessionId
            JOIN receiving.ImportContainers c ON c.Id=v.ContainerId
            JOIN sourcing.Suppliers su ON su.Id=c.SupplierId
            WHERE v.LocationId=@location AND (@open=0 OR v.Status NOT IN ('posted','cancelled'))
            ORDER BY s.CreatedAt DESC,s.Id
            """, r => new ScanSessionSummary(r.GetGuid(0), r.GetGuid(1), r.GetString(2), r.GetString(3), r.GetGuid(4), r.GetString(5),
                r.Utc(6), r.GetInt32(7), r.GetInt64(8), r.GetInt64(9)),
            ct, P("@limit", limit), P("@location", locationId), P("@open", openOnly));

    // Matched readings collapse to one line per variant and code. Any other reading stays its own line with its id,
    // because a reviewer resolves readings one by one.
    public async Task<IReadOnlyList<ScanSessionLine>> GetLinesAsync(Guid sessionId, CancellationToken ct) => await sql.QueryAsync("""
        SELECT ScanId,ItemId,RawCode,MatchStatus,Quantity,Scans,Sku,VariantName FROM (
          SELECT CAST(NULL AS uniqueidentifier) AS ScanId,e.ItemId,e.RawCode,e.MatchStatus,CAST(SUM(e.Quantity) AS bigint) AS Quantity,
                 COUNT(*) AS Scans,i.Sku,i.VariantName,MIN(e.CreatedAt) AS FirstAt
          FROM receiving.ScanEvents e JOIN catalog.Items i ON i.Id=e.ItemId
          WHERE e.ScanSessionId=@id AND e.MatchStatus='matched'
          GROUP BY e.ItemId,e.RawCode,e.MatchStatus,i.Sku,i.VariantName
          UNION ALL
          SELECT e.Id,e.ItemId,e.RawCode,e.MatchStatus,CAST(e.Quantity AS bigint),1,NULL,NULL,e.CreatedAt
          FROM receiving.ScanEvents e WHERE e.ScanSessionId=@id AND e.MatchStatus<>'matched') x
        ORDER BY FirstAt,RawCode,ScanId
        """, r => new ScanSessionLine(r.GuidOrNull(0), r.GuidOrNull(1), r.GetString(2), r.GetString(3), r.GetInt64(4), r.GetInt32(5),
            r.StringOrNull(6), r.StringOrNull(7)), ct, P("@id", sessionId));

    public async Task<bool> ScanInSessionAsync(Guid scanId, Guid sessionId, CancellationToken ct) =>
        (await sql.QueryAsync("SELECT 1 FROM receiving.ScanEvents WHERE Id=@scan AND ScanSessionId=@session", _ => 1, ct,
            P("@scan", scanId), P("@session", sessionId))).Count == 1;

    public Task ResolveScanAsync(Guid scanId, Guid itemId, Guid reviewerId, string reason, CancellationToken ct) =>
        sql.ExecProcAsync("receiving.usp_ResolveScan", ct, P("@ScanId", scanId), P("@ItemId", itemId),
            P("@ReviewerId", reviewerId), P("@Reason", reason));

    public Task RejectScanAsync(Guid scanId, Guid reviewerId, string reason, CancellationToken ct) =>
        sql.ExecProcAsync("receiving.usp_RejectScan", ct, P("@ScanId", scanId), P("@ReviewerId", reviewerId), P("@Reason", reason));

    public async Task<IReadOnlyList<SupplierRow>> ListSuppliersAsync(CancellationToken ct) => await sql.QueryAsync(
        "SELECT Id,DisplayName FROM sourcing.Suppliers WHERE IsActive=1 ORDER BY DisplayName,Id",
        r => new SupplierRow(r.GetGuid(0), r.GetString(1)), ct);
}

public sealed class InventoryStore(SqlGateway sql) : IInventoryStore
{
    public async Task<IReadOnlyList<StockRow>> GetStockAsync(Guid? branchId, Guid? itemId, CancellationToken ct) => await sql.QueryAsync("""
        SELECT ItemId,Sku,VariantName,LocationId,Pool,OnHand,Reserved,Available FROM inventory.vw_StockAvailable
        WHERE (@branch IS NULL OR BranchId=@branch) AND (@item IS NULL OR ItemId=@item) ORDER BY Sku,LocationId,Pool
        """, r => new StockRow(r.GetGuid(0), r.GetString(1), r.GetString(2), r.GetGuid(3), r.GetString(4), r.GetInt32(5), r.GetInt32(6), r.GetInt32(7)),
        ct, P("@branch", branchId), P("@item", itemId));

    public async Task<IReadOnlyList<LabelJob>> GetLabelJobsAsync(Guid branchId, string? status, CancellationToken ct) => await sql.QueryAsync("""
        SELECT Id,ItemId,StoreNameSnapshot,SkuSnapshot,BarcodeSnapshot,CopiesRequested,CopiesAcknowledged,Status
        FROM labels.PrintJobs WHERE BranchId=@branch AND (@status IS NULL OR Status=@status) ORDER BY CreatedAt,Id
        """, r => new LabelJob(r.GetGuid(0), r.GetGuid(1), r.GetString(2), r.GetString(3), r.GetString(4), r.GetInt32(5), r.GetInt32(6), r.GetString(7)),
        ct, P("@branch", branchId), P("@status", status));

    public async Task AcknowledgePrintAsync(Guid printJobId, Guid branchId, AckPrintRequest request, CancellationToken ct)
    {
        var here = await sql.QueryAsync("SELECT 1 FROM labels.PrintJobs WHERE Id=@id AND BranchId=@branch", _ => 1, ct,
            P("@id", printJobId), P("@branch", branchId));
        if (here.Count == 0) throw Errors.NotFound("labels.job_not_found", "El trabajo de etiqueta no existe en esta sucursal.");
        await sql.ExecProcAsync("labels.usp_AcknowledgePrint", ct, P("@PrintJobId", printJobId), P("@AttemptId", request.AttemptId),
            P("@AttemptNo", request.AttemptNo), P("@Successful", request.Successful), P("@PrinterResponse", request.PrinterResponse));
    }
}

public sealed class SalesStore(SqlGateway sql) : ISalesStore
{
    private static readonly JsonSerializerOptions Camel = new(JsonSerializerDefaults.Web);

    public async Task OpenTillAsync(OpenTillRequest request, Guid cashierId, Guid nodeId, CancellationToken ct) =>
        await sql.ExecProcAsync("sales.usp_OpenTillCounted", ct, P("@TillId", request.TillId), P("@RegisterId", request.RegisterId),
            P("@CashierId", cashierId), P("@CurrencyCode", request.CurrencyCode), P("@OpeningMinor", request.OpeningMinor),
            P("@OriginNodeId", nodeId), P("@LinesJson", JsonSerializer.Serialize(request.Lines, Camel)));

    public Task PostSaleAsync(PostSaleRequest request, Guid branchId, Guid locationId, Guid cashierId, Guid nodeId, Guid? discountApproverId, CancellationToken ct)
    {
        var lines = new DataTable();
        lines.Columns.Add("LineNumber", typeof(int)); lines.Columns.Add("ItemId", typeof(Guid));
        lines.Columns.Add("Quantity", typeof(int)); lines.Columns.Add("UnitPriceMinor", typeof(long));
        lines.Columns.Add("DiscountMinor", typeof(long));
        foreach (var l in request.Lines.OrderBy(l => l.LineNumber))
            lines.Rows.Add(l.LineNumber, l.ItemId, l.Quantity, l.UnitPriceMinor, l.DiscountMinor);

        var tenders = new DataTable();
        tenders.Columns.Add("TenderNumber", typeof(int)); tenders.Columns.Add("TenderKind", typeof(string));
        tenders.Columns.Add("AmountMinor", typeof(long)); tenders.Columns.Add("CreditId", typeof(Guid));
        tenders.Columns.Add("ReceivedMinor", typeof(long)); tenders.Columns.Add("ChangeMinor", typeof(long));
        tenders.Columns.Add("Reference", typeof(string));
        foreach (var t in request.Tenders.OrderBy(t => t.TenderNumber))
            tenders.Rows.Add(t.TenderNumber, t.TenderKind, t.AmountMinor, (object?)t.CreditId ?? DBNull.Value,
                (object?)t.ReceivedMinor ?? DBNull.Value, (object?)t.ChangeMinor ?? DBNull.Value, (object?)t.Reference ?? DBNull.Value);

        return sql.ExecProcAsync("sales.usp_PostSale", ct, P("@SaleId", request.SaleId), P("@BranchId", branchId),
            P("@LocationId", locationId), P("@CashierId", cashierId), P("@CurrencyCode", request.CurrencyCode),
            P("@OriginNodeId", nodeId), Table("@Lines", "sales.SaleLineRequest", lines),
            Table("@Tenders", "sales.SaleTenderRequest", tenders), P("@CustomerId", request.CustomerId), P("@TillId", request.TillId), P("@DiscountApproverId", discountApproverId), P("@DiscountReason", request.DiscountReason), P("@StockExceptionNote", request.StockExceptionNote));
    }

    public Task<SaleResponse?> GetSaleAsync(Guid saleId, Guid branchId, CancellationToken ct) => sql.FirstAsync(
        "SELECT Id,SubtotalMinor,DiscountMinor,TaxMinor,TotalMinor,Status FROM sales.Sales WHERE Id=@id AND BranchId=@branch",
        r => new SaleResponse(r.GetGuid(0), r.GetInt64(1), r.GetInt64(2), r.GetInt64(3), r.GetInt64(4), r.GetString(5)),
        ct, P("@id", saleId), P("@branch", branchId));

    public Task RecordCashCountAsync(Guid tillId, RecordCashCountRequest request, Guid actorId, CancellationToken ct) =>
        sql.ExecProcAsync("sales.usp_RecordCashCount", ct, P("@CashCountId", request.CashCountId), P("@TillId", tillId),
            P("@ActorId", actorId), P("@LinesJson", JsonSerializer.Serialize(request.Lines, Camel)));

    public Task CloseTillAsync(Guid tillId, CloseTillRequest request, Guid actorId, Guid nodeId, CancellationToken ct) =>
        sql.ExecProcAsync("sales.usp_CloseTill", ct, P("@ClosureId", request.ClosureId), P("@TillId", tillId),
            P("@CashCountId", request.CashCountId), P("@ActorId", actorId), P("@OriginNodeId", nodeId));

    public Task<CloseTillResponse?> GetClosureAsync(Guid tillId, CancellationToken ct) => sql.FirstAsync(
        "SELECT Id,ExpectedMinor,CountedMinor,DifferenceMinor FROM sales.CashClosures WHERE TillId=@till",
        r => new CloseTillResponse(r.GetGuid(0), r.GetInt64(1), r.GetInt64(2), r.GetInt64(3)), ct, P("@till", tillId));

    public async Task<Guid?> GetTillBranchAsync(Guid tillId, CancellationToken ct)
    {
        var rows = await sql.QueryAsync(
            "SELECT r.BranchId FROM sales.CashTills t JOIN sales.CashRegisters r ON r.Id=t.RegisterId WHERE t.Id=@id",
            r => r.GetGuid(0), ct, P("@id", tillId));
        return rows.Count == 1 ? rows[0] : null;
    }

    public async Task<Guid?> GetRegisterBranchAsync(Guid registerId, CancellationToken ct)
    {
        var rows = await sql.QueryAsync("SELECT BranchId FROM sales.CashRegisters WHERE Id=@id AND IsActive=1",
            r => r.GetGuid(0), ct, P("@id", registerId));
        return rows.Count == 1 ? rows[0] : null;
    }

    public async Task<IReadOnlyList<RegisterRow>> ListRegistersAsync(Guid branchId, CancellationToken ct) => await sql.QueryAsync("""
        SELECT r.Id,r.Code,r.Name,r.LocationId,t.Id,t.CashierId FROM sales.CashRegisters r
        OUTER APPLY (SELECT TOP (1) ct.Id,ct.CashierId FROM sales.CashTills ct
                     WHERE ct.RegisterId=r.Id AND ct.Status='open' ORDER BY ct.OpenedAt DESC,ct.Id) t
        WHERE r.BranchId=@branch AND r.IsActive=1 ORDER BY r.Code,r.Id
        """, r => new RegisterRow(r.GetGuid(0), r.GetString(1), r.GetString(2), r.GetGuid(3), r.GuidOrNull(4), r.GuidOrNull(5)),
        ct, P("@branch", branchId));

    public async Task<Guid?> FindOpenTillAsync(Guid cashierId, Guid branchId, CancellationToken ct)
    {
        var rows = await sql.QueryAsync("""
            SELECT TOP (1) t.Id FROM sales.CashTills t JOIN sales.CashRegisters r ON r.Id=t.RegisterId
            WHERE t.CashierId=@cashier AND r.BranchId=@branch AND t.Status='open' ORDER BY t.OpenedAt DESC,t.Id
            """, r => r.GetGuid(0), ct, P("@cashier", cashierId), P("@branch", branchId));
        return rows.Count == 1 ? rows[0] : null;
    }

    // Expected cash is the sum of every cash entry of the till, the figure sales.usp_CloseTill stores.
    public Task<TillSummary?> GetTillSummaryAsync(Guid tillId, Guid branchId, CancellationToken ct) => sql.FirstAsync("""
        SELECT t.Id,t.RegisterId,r.Name,t.CashierId,st.DisplayName,t.Status,t.CurrencyCode,t.OpenedAt,
               ISNULL(e.Opening,0),ISNULL(e.Sales,0),ISNULL(e.Refunds,0),ISNULL(e.Other,0),ISNULL(e.Expected,0),
               s.SaleCount,s.SalesTotal,(SELECT TOP (1) cc.Id FROM sales.CashClosures cc WHERE cc.TillId=t.Id),
               (SELECT l.DenominationMinor AS denominationMinor,l.Quantity AS quantity FROM sales.CashCounts c JOIN sales.CashCountLines l ON l.CashCountId=c.Id WHERE c.TillId=t.Id AND c.CountKind='opening' ORDER BY l.DenominationMinor DESC FOR JSON PATH)
        FROM sales.CashTills t
        JOIN sales.CashRegisters r ON r.Id=t.RegisterId
        JOIN security.Staff st ON st.Id=t.CashierId
        OUTER APPLY (SELECT SUM(CASE WHEN Kind='opening' THEN DeltaMinor ELSE 0 END) AS Opening,
                            SUM(CASE WHEN Kind='sale' THEN DeltaMinor ELSE 0 END) AS Sales,
                            SUM(CASE WHEN Kind='refund' THEN DeltaMinor ELSE 0 END) AS Refunds,
                            SUM(CASE WHEN Kind NOT IN ('opening','sale','refund') THEN DeltaMinor ELSE 0 END) AS Other,
                            SUM(DeltaMinor) AS Expected
                     FROM sales.CashEntries WHERE TillId=t.Id) e
        OUTER APPLY (SELECT COUNT(*) AS SaleCount,ISNULL(SUM(TotalMinor),0) AS SalesTotal
                     FROM sales.Sales WHERE TillId=t.Id AND Status<>'cancelled') s
        WHERE t.Id=@id AND r.BranchId=@branch
        """, r => new TillSummary(r.GetGuid(0), r.GetGuid(1), r.GetString(2), r.GetGuid(3), r.GetString(4), r.GetString(5),
            r.GetString(6), r.Utc(7), r.GetInt64(8), r.GetInt64(9), r.GetInt64(10), r.GetInt64(11), r.GetInt64(12), r.GetInt32(13),
            r.GetInt64(14), r.GuidOrNull(15), JsonSerializer.Deserialize<CashCountLine[]>(r.GetString(16), Camel)), ct, P("@id", tillId), P("@branch", branchId));
}

public sealed class SiteStore(SqlGateway sql) : ISiteStore
{
    public Task<SiteInfo?> GetSiteAsync(Guid branchId, Guid? locationId, CancellationToken ct) => sql.FirstAsync(
        "SELECT b.Name,b.StoreDisplayName,l.Name FROM core.Branches b LEFT JOIN core.Locations l ON l.Id=@location AND l.BranchId=b.Id WHERE b.Id=@branch",
        r => new SiteInfo(r.GetString(0), r.GetString(1), r.StringOrNull(2)), ct, P("@branch", branchId), P("@location", locationId));
}
