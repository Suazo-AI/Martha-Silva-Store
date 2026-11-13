using System.Data;
using System.Text.Json;
using Savia.Application;
using Savia.Contracts;
using Savia.Domain;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

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
        "SELECT ScanSessionId,ContainerId,Reference,Status,ScanEvents,MatchedUnits,UnitsPendingReview FROM receiving.vw_SessionProgress "
        + "WHERE ScanSessionId=@id AND LocationId=@location",
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

    public Task RecordQualityAsync(Guid session, QualityRequest request, Guid actor, Guid location, CancellationToken ct) =>
        sql.ExecProcAsync("receiving.usp_RecordQuality", ct, P("@CheckId", request.CheckId), P("@ScanSessionId", session), P("@ItemId", request.ItemId),
            P("@Good", request.Buena), P("@Damaged", request.Danada), P("@Stained", request.Manchada), P("@Odor", request.MalOlor),
            P("@Missing", request.Faltante), P("@Reason", request.Reason), P("@ActorId", actor), P("@LocationId", location));

    public Task<JsonElement> QualityAsync(Guid session, Guid location, CancellationToken ct) =>
        sql.ReadElement("receiving.usp_GetQuality", ct, P("@ScanSessionId", session), P("@LocationId", location));
}
