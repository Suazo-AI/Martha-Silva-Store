using System.Text.Json;
using Savia.Application;
using Savia.Contracts;
using Savia.Domain;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

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

    public Task<JsonElement> ExceptionsAsync(Guid branch, CancellationToken ct) =>
        sql.ReadElement("sales.usp_ListStockExceptions", ct, P("@BranchId", branch));

    public Task ReviewExceptionAsync(Guid branch, Guid exceptionId, Guid actor, string reason, CancellationToken ct) =>
        sql.ExecProcAsync("sales.usp_ReviewStockException", ct, P("@BranchId", branch), P("@ExceptionId", exceptionId),
            P("@ActorId", actor), P("@Reason", reason));
}
