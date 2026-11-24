using System.Text.Json;
using Savia.Application;
using Savia.Contracts;
using Savia.Domain;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

public sealed class InventoryStore(SqlGateway sql) : IInventoryStore
{
    /// <summary>The page key is the last row's item, location and pool: the order (SKU, location, pool) is unique.</summary>
    public async Task<Page<StockRow>> GetStockAsync(Guid? branchId, Guid? itemId, string? after, int limit, CancellationToken ct)
    {
        var (afterItem, afterLocation, afterPool) = after is null ? (null, null, null) : ParseAfter(after);
        var rows = await sql.QueryAsync("""
            DECLARE @afterSku nvarchar(100)=(SELECT Sku FROM catalog.Items WHERE Id=@afterItem);
            IF @afterItem IS NOT NULL AND @afterSku IS NULL THROW 51230,'Existencias: la pagina anterior no existe.',1;
            SELECT TOP(@limit+1) ItemId,Sku,VariantName,LocationId,Pool,OnHand,Reserved,Available FROM inventory.vw_StockAvailable
            WHERE (@branch IS NULL OR BranchId=@branch) AND (@item IS NULL OR ItemId=@item)
              AND (@afterItem IS NULL OR (Sku>=@afterSku AND (Sku>@afterSku OR LocationId>@afterLocation OR (LocationId=@afterLocation AND Pool>@afterPool))))
            ORDER BY Sku,LocationId,Pool
            -- Recompile per page so the SKU bound becomes an index seek; one shared plan read every earlier row (1.3 s at row 200,000).
            OPTION(RECOMPILE)
            """, r => new StockRow(r.GetGuid(0), r.GetString(1), r.GetString(2), r.GetGuid(3), r.GetString(4), r.GetInt32(5), r.GetInt32(6), r.GetInt32(7)),
            ct, P("@branch", branchId), P("@item", itemId), P("@limit", limit),
            P("@afterItem", afterItem), P("@afterLocation", afterLocation), P("@afterPool", afterPool));
        if (rows.Count <= limit) return new(rows, null);
        var last = rows[limit - 1];
        return new(rows.GetRange(0, limit), $"{last.ItemId}.{last.LocationId}.{last.Pool}");
    }

    private static (Guid?, Guid?, string?) ParseAfter(string after)
    {
        var parts = after.Split('.');
        return parts.Length == 3 && Guid.TryParse(parts[0], out var item) && Guid.TryParse(parts[1], out var location) && parts[2].Length is > 0 and <= 12
            ? (item, location, parts[2])
            : throw Paging.BadAfter();
    }

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

    public Task<JsonElement> ExceptionsAsync(Guid branch, CancellationToken ct) =>
        sql.ReadElement("sales.usp_ListStockExceptions", ct, P("@BranchId", branch));

    public Task ReviewExceptionAsync(Guid branch, Guid exceptionId, Guid actor, string reason, CancellationToken ct) =>
        sql.ExecProcAsync("sales.usp_ReviewStockException", ct, P("@BranchId", branch), P("@ExceptionId", exceptionId),
            P("@ActorId", actor), P("@Reason", reason));
}
