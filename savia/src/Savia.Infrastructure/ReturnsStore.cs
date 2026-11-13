using System.Data;
using System.Text.Json;
using Savia.Application;
using Savia.Contracts;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

public sealed class ReturnsStore(SqlGateway sql) : IReturnsStore
{
    public Task ReturnAsync(Guid branch, Guid location, Guid sale, PostCreditReturnRequest request, Guid actor, Guid node, CancellationToken ct)
    {
        var lines = new DataTable();
        lines.Columns.Add("SaleLineId", typeof(Guid)); lines.Columns.Add("Quantity", typeof(int)); lines.Columns.Add("RestockPool", typeof(string));
        foreach (var line in request.Lines) lines.Rows.Add(line.SaleLineId, line.Quantity, line.RestockPool);
        return sql.ExecProcAsync("sales.usp_PostCreditReturn", ct, P("@ReversalId", request.ReversalId), P("@CreditId", request.CreditId),
            P("@SaleId", sale), P("@BranchId", branch), P("@ReturnLocationId", location), P("@TillId", request.TillId),
            P("@ActorId", actor), P("@ApprovedBy", actor), P("@CustomerId", request.CustomerId), P("@Reason", request.Reason),
            P("@OriginNodeId", node), Table("@Lines", "sales.ReturnLineRequest", lines));
    }

    public Task ReturnOutcomeAsync(Guid branch, Guid location, Guid sale, PostReturnOutcomeRequest request, Guid actor, Guid node, CancellationToken ct)
    {
        var lines = new DataTable();
        lines.Columns.Add("SaleLineId", typeof(Guid)); lines.Columns.Add("Quantity", typeof(int)); lines.Columns.Add("RestockPool", typeof(string));
        foreach (var line in request.Lines) lines.Rows.Add(line.SaleLineId, line.Quantity, line.RestockPool);
        var newLines = new DataTable();
        newLines.Columns.Add("LineNumber", typeof(int)); newLines.Columns.Add("ItemId", typeof(Guid));
        newLines.Columns.Add("Quantity", typeof(int)); newLines.Columns.Add("UnitPriceMinor", typeof(long));
        newLines.Columns.Add("DiscountMinor", typeof(long));
        foreach (var l in (request.NewLines ?? []).OrderBy(l => l.LineNumber))
            newLines.Rows.Add(l.LineNumber, l.ItemId, l.Quantity, l.UnitPriceMinor, l.DiscountMinor);
        var tenders = new DataTable();
        tenders.Columns.Add("TenderNumber", typeof(int)); tenders.Columns.Add("TenderKind", typeof(string));
        tenders.Columns.Add("AmountMinor", typeof(long)); tenders.Columns.Add("CreditId", typeof(Guid));
        tenders.Columns.Add("ReceivedMinor", typeof(long)); tenders.Columns.Add("ChangeMinor", typeof(long)); tenders.Columns.Add("Reference", typeof(string));
        foreach (var t in (request.NewTenders ?? []).OrderBy(t => t.TenderNumber))
            tenders.Rows.Add(t.TenderNumber, t.TenderKind, t.AmountMinor, (object?)t.CreditId ?? DBNull.Value,
                (object?)t.ReceivedMinor ?? DBNull.Value, (object?)t.ChangeMinor ?? DBNull.Value, (object?)t.Reference ?? DBNull.Value);
        var sellers = request.NewLines?.Any(l => l.SellerId is not null) == true
            ? JsonSerializer.Serialize(request.NewLines.OrderBy(l => l.LineNumber).Select(l => new { l.LineNumber, l.SellerId }), SqlJson.Web) : null;
        return sql.ExecProcAsync("sales.usp_PostReturnOutcome", ct, P("@ReversalId", request.ReversalId), P("@SaleId", sale), P("@BranchId", branch),
            P("@LocationId", location), P("@TillId", request.TillId), P("@ActorId", actor), P("@Outcome", request.Outcome), P("@Reason", request.Reason),
            P("@Reference", request.Reference), P("@OriginNodeId", node), Table("@Lines", "sales.ReturnLineRequest", lines),
            P("@ExchangeSaleId", request.ExchangeSaleId), Table("@NewLines", "sales.SaleLineRequest", newLines),
            Table("@NewTenders", "sales.SaleTenderRequest", tenders),
            P("@SellersJson", sellers), P("@DifferenceKind", request.DifferenceKind), P("@DifferenceReference", request.DifferenceReference));
    }

    public Task<JsonElement> ReturnPolicyAsync(Guid branch, CancellationToken ct) =>
        sql.ReadElement("sales.usp_GetReturnPolicy", ct, P("@BranchId", branch));

    public Task SetReturnWindowAsync(Guid branch, ReturnWindowRequest request, Guid actor, CancellationToken ct) =>
        sql.ExecProcAsync("sales.usp_SetReturnWindow", ct, P("@ChangeId", request.ChangeId), P("@BranchId", branch),
            P("@WindowDays", request.WindowDays), P("@ActorId", actor), P("@Reason", request.Reason));
}
