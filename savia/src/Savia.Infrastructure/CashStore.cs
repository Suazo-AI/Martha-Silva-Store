using System.Text.Json;
using Savia.Application;
using Savia.Contracts;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

public sealed class CashStore(SqlGateway sql) : ICashStore
{
    public async Task OpenTillAsync(OpenTillRequest request, Guid cashierId, Guid nodeId, CancellationToken ct) =>
        await sql.ExecProcAsync("sales.usp_OpenTillCounted", ct, P("@TillId", request.TillId), P("@RegisterId", request.RegisterId),
            P("@CashierId", cashierId), P("@CurrencyCode", request.CurrencyCode), P("@OpeningMinor", request.OpeningMinor),
            P("@OriginNodeId", nodeId), P("@LinesJson", JsonSerializer.Serialize(request.Lines, SqlJson.Web)),
            P("@UsdLinesJson", request.UsdLines is null ? null : JsonSerializer.Serialize(request.UsdLines, SqlJson.Web)));

    public Task RecordCashCountAsync(Guid tillId, RecordCashCountRequest request, Guid actorId, CancellationToken ct) =>
        sql.ExecProcAsync("sales.usp_RecordCashCount", ct, P("@CashCountId", request.CashCountId), P("@TillId", tillId),
            P("@UsdCashCountId", request.UsdCashCountId), P("@ActorId", actorId), P("@LinesJson", JsonSerializer.Serialize(request.Lines, SqlJson.Web)),
            P("@UsdLinesJson", request.UsdLines is null ? null : JsonSerializer.Serialize(request.UsdLines, SqlJson.Web)));

    public Task CloseTillAsync(Guid tillId, CloseTillRequest request, Guid actorId, Guid nodeId, CancellationToken ct) =>
        sql.ExecProcAsync("sales.usp_CloseTill", ct, P("@ClosureId", request.ClosureId), P("@TillId", tillId),
            P("@CashCountId", request.CashCountId), P("@ActorId", actorId), P("@OriginNodeId", nodeId),
            P("@UsdCashCountId", request.UsdCashCountId));

    public Task<CloseTillResponse?> GetClosureAsync(Guid tillId, CancellationToken ct) => sql.FirstAsync(
        """
        SELECT c.Id,c.ExpectedMinor,c.CountedMinor,c.DifferenceMinor,u.ExpectedMinor,u.CountedMinor,u.DifferenceMinor
        FROM sales.CashClosures c JOIN sales.CashTills t ON t.Id=c.TillId
        LEFT JOIN sales.CashTills child ON child.ParentTillId=t.Id
        LEFT JOIN sales.CashClosures u ON u.TillId=child.Id WHERE t.ParentTillId IS NULL AND c.TillId=@till
        """,
        r => new CloseTillResponse(r.GetGuid(0), r.GetInt64(1), r.GetInt64(2), r.GetInt64(3),
            r.IsDBNull(4) ? null : r.GetInt64(4), r.IsDBNull(5) ? null : r.GetInt64(5), r.IsDBNull(6) ? null : r.GetInt64(6)), ct, P("@till", tillId));

    public async Task<Guid?> GetTillBranchAsync(Guid tillId, CancellationToken ct)
    {
        var rows = await sql.QueryAsync(
            "SELECT r.BranchId FROM sales.CashTills t JOIN sales.CashRegisters r ON r.Id=t.RegisterId WHERE t.ParentTillId IS NULL AND t.Id=@id",
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
                     WHERE ct.RegisterId=r.Id AND ct.Status='open' AND ct.ParentTillId IS NULL ORDER BY ct.OpenedAt DESC,ct.Id) t
        WHERE r.BranchId=@branch AND r.IsActive=1 ORDER BY r.Code,r.Id
        """, r => new RegisterRow(r.GetGuid(0), r.GetString(1), r.GetString(2), r.GetGuid(3), r.GuidOrNull(4), r.GuidOrNull(5)),
        ct, P("@branch", branchId));

    public async Task<Guid?> FindOpenTillAsync(Guid cashierId, Guid branchId, CancellationToken ct)
    {
        var rows = await sql.QueryAsync("""
            SELECT TOP (1) t.Id FROM sales.CashTills t JOIN sales.CashRegisters r ON r.Id=t.RegisterId
            WHERE t.CashierId=@cashier AND r.BranchId=@branch AND t.Status='open' AND t.ParentTillId IS NULL ORDER BY t.OpenedAt DESC,t.Id
            """, r => r.GetGuid(0), ct, P("@cashier", cashierId), P("@branch", branchId));
        return rows.Count == 1 ? rows[0] : null;
    }

    // Expected cash is the sum of every cash entry of the till, the figure sales.usp_CloseTill stores.
    public Task<TillSummary?> GetTillSummaryAsync(Guid tillId, Guid branchId, CancellationToken ct) => sql.FirstAsync("""
        SELECT t.Id,t.RegisterId,r.Name,t.CashierId,st.DisplayName,t.Status,t.CurrencyCode,t.OpenedAt,
               ISNULL(e.Opening,0),ISNULL(e.Sales,0),ISNULL(e.Refunds,0),ISNULL(e.Other,0),ISNULL(e.Expected,0),
               s.SaleCount,s.SalesTotal,(SELECT TOP (1) cc.Id FROM sales.CashClosures cc WHERE cc.TillId=t.Id),
               (SELECT l.DenominationMinor AS denominationMinor,l.Quantity AS quantity
                FROM sales.CashCounts c JOIN sales.CashCountLines l ON l.CashCountId=c.Id
                WHERE c.TillId=t.Id AND c.CountKind='opening' ORDER BY l.DenominationMinor DESC FOR JSON PATH),
               (SELECT SUM(e.DeltaMinor) FROM sales.CashTills child JOIN sales.CashEntries e ON e.TillId=child.Id WHERE child.ParentTillId=t.Id)
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
        WHERE t.ParentTillId IS NULL AND t.Id=@id AND r.BranchId=@branch
        """, r => new TillSummary(r.GetGuid(0), r.GetGuid(1), r.GetString(2), r.GetGuid(3), r.GetString(4), r.GetString(5),
            r.GetString(6), r.Utc(7), r.GetInt64(8), r.GetInt64(9), r.GetInt64(10), r.GetInt64(11), r.GetInt64(12), r.GetInt32(13),
            r.GetInt64(14), r.GuidOrNull(15), JsonSerializer.Deserialize<CashCountLine[]>(r.GetString(16), SqlJson.Web),
            r.IsDBNull(17) ? null : r.GetInt64(17)),
        ct, P("@id", tillId), P("@branch", branchId));

    public async Task<IReadOnlyList<long>> DenominationsAsync(CancellationToken ct) =>
        await sql.QueryAsync("SELECT DenominationMinor FROM sales.CashDenominations WHERE CurrencyCode='NIO' ORDER BY DenominationMinor DESC",
            r => r.GetInt64(0), ct);
}
