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
        await sql.ExecProcAsync("sales.usp_OpenTill", ct, P("@TillId", request.TillId), P("@RegisterId", request.RegisterId),
            P("@CashierId", cashierId), P("@CurrencyCode", request.CurrencyCode), P("@OpeningMinor", request.OpeningMinor),
            P("@OriginNodeId", nodeId));

    public Task PostSaleAsync(PostSaleRequest request, Guid branchId, Guid locationId, Guid cashierId, Guid nodeId, CancellationToken ct)
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
            Table("@Tenders", "sales.SaleTenderRequest", tenders), P("@CustomerId", request.CustomerId), P("@TillId", request.TillId));
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
}
