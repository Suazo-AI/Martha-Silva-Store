using System.Data;
using Microsoft.Data.SqlClient;
using Savia.Application;
using Savia.Contracts;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

public sealed class WebStoreStore(SqlGateway sql) : IWebStoreStore
{
    public async Task<PublicCatalogItem[]> CatalogAsync(CancellationToken ct) =>
        await sql.ReadJson<PublicCatalogItem[]>("webstore.usp_PublicCatalogJson", ct) ?? [];

    public Task<WebOrderView?> FindOrderAsync(Guid orderId, byte[] accessTokenHash, CancellationToken ct) =>
        sql.ReadJson<WebOrderView>("webstore.usp_WebOrderJson", ct, P("@OrderId", orderId), P("@AccessTokenHash", accessTokenHash));

    public async Task<WebOrderPlaced> CreateOrderAsync(NewWebOrder order, Guid originNode, CancellationToken ct)
    {
        var request = order.Request;
        var rows = await sql.QueryProcAsync("webstore.usp_CreateWebOrder",
            r => new WebOrderPlaced(r.GetGuid(0), r.GetString(1), r.GetString(2), r.GetInt64(3), r.GetInt64(4), r.GetString(5),
                r.Utc(6), r.GetBoolean(7)),
            ct, P("@OrderId", order.OrderId), P("@RequestHash", order.RequestHash), P("@AccessTokenHash", order.AccessTokenHash),
            Hash("@ClientHash", order.ClientHash), Table("@Lines", "webstore.WebOrderLine", Lines(request.Lines)),
            P("@Name", request.Contact.Name), P("@Email", request.Contact.Email), P("@Phone", request.Contact.Phone),
            P("@ZoneCode", request.Shipping.Zone), P("@Address", request.Shipping.Address), P("@City", request.Shipping.City),
            P("@Notes", request.Shipping.Notes), P("@Provider", order.ProviderCode), P("@OriginNodeId", originNode),
            P("@EventId", Guid.NewGuid()));
        return rows.Single();
    }

    public async Task<WebOrderRow[]> ListOrdersAsync(string? status, CancellationToken ct) =>
        await sql.ReadJson<WebOrderRow[]>("webstore.usp_WebOrdersJson", ct, P("@Status", status)) ?? [];

    public async Task<DueWebOrder[]> DueOrdersAsync(CancellationToken ct) =>
        await sql.ReadJson<DueWebOrder[]>("webstore.usp_DueWebOrdersJson", ct) ?? [];

    public async Task<bool> ExpireAsync(Guid orderId, CancellationToken ct) =>
        (await sql.QueryProcAsync("webstore.usp_ExpireReservation", r => r.GetInt32(0), ct, P("@OrderId", orderId))).Single() == 1;

    public Task RecordPaymentAsync(VerifiedPayment payment, Guid paymentId, Guid originNode, Guid? actor, CancellationToken ct) =>
        sql.ExecProcAsync("webstore.usp_RecordVerifiedPayment", ct, P("@PaymentId", paymentId), P("@OrderId", payment.OrderId),
            P("@Provider", payment.Provider), P("@ExternalPaymentId", payment.ExternalPaymentId), P("@AmountMinor", payment.AmountMinor),
            P("@CurrencyCode", payment.Currency), P("@VerifiedByTrustedService", true), P("@OriginNodeId", originNode),
            P("@EventId", Guid.NewGuid()), P("@ActorId", actor));

    public async Task<CaptureOutcome> RecordCaptureAsync(VerifiedPayment payment, Guid paymentId, Guid originNode, CancellationToken ct)
    {
        var outcome = await sql.QueryProcAsync("webstore.usp_RecordCapturedPayment", r => r.GetString(0), ct, P("@PaymentId", paymentId),
            P("@OrderId", payment.OrderId), P("@Provider", payment.Provider), P("@ExternalPaymentId", payment.ExternalPaymentId),
            P("@AmountMinor", payment.AmountMinor), P("@CurrencyCode", payment.Currency), P("@OriginNodeId", originNode),
            P("@EventId", Guid.NewGuid()));
        return Enum.Parse<CaptureOutcome>(outcome.Single(), ignoreCase: true);
    }

    public Task RefundReviewAsync(Guid orderId, string reference, Guid actor, CancellationToken ct) =>
        sql.ExecProcAsync("webstore.usp_RefundPaymentReview", ct, P("@OrderId", orderId), P("@RefundReference", reference),
            P("@ActorId", actor));

    public Task AcceptReviewAsync(Guid orderId, Guid originNode, Guid actor, CancellationToken ct) =>
        sql.ExecProcAsync("webstore.usp_AcceptPaymentReview", ct, P("@OrderId", orderId), P("@OriginNodeId", originNode),
            P("@EventId", Guid.NewGuid()), P("@ActorId", actor));

    public Task CancelAsync(Guid orderId, Guid actor, CancellationToken ct) =>
        sql.ExecProcAsync("webstore.usp_CancelWebOrder", ct, P("@OrderId", orderId), P("@ActorId", actor));

    public Task FulfillAsync(Guid orderId, Guid originNode, Guid actor, CancellationToken ct) =>
        sql.ExecProcAsync("webstore.usp_FulfillPaidOrder", ct, P("@OrderId", orderId), P("@OriginNodeId", originNode),
            P("@EventId", Guid.NewGuid()), P("@ActorId", actor));

    public Task ConsignAsync(WebConsignmentRequest request, Guid actor, CancellationToken ct) =>
        sql.ExecProcAsync("inventory.usp_ConsignToWeb", ct, P("@ConsignmentId", request.ConsignmentId), P("@ItemId", request.ItemId),
            P("@FromLocationId", request.FromLocationId), P("@Quantity", request.Qty), P("@ActorId", actor));

    public Task ReleaseAsync(WebReleaseRequest request, Guid actor, CancellationToken ct) =>
        sql.ExecProcAsync("inventory.usp_ReleaseFromWeb", ct, P("@ReleaseId", request.ReleaseId), P("@ItemId", request.ItemId),
            P("@TargetLocationId", request.ToLocationId), P("@Quantity", request.Qty), P("@Reason", request.Reason), P("@ActorId", actor));

    public Task ApplyConsignmentsAsync(CancellationToken ct) => sql.ExecProcAsync("inventory.usp_ApplyWebConsignments", ct);

    public Task ApplyReleasesAsync(CancellationToken ct) => sql.ExecProcAsync("inventory.usp_ApplyWebReleases", ct);

    private static DataTable Lines(PublicOrderLine[] lines)
    {
        var table = new DataTable();
        table.Columns.Add("LineNumber", typeof(int));
        table.Columns.Add("Sku", typeof(string));
        table.Columns.Add("Quantity", typeof(int));
        for (var i = 0; i < lines.Length; i++) table.Rows.Add(i + 1, lines[i].Sku, lines[i].Qty);
        return table;
    }

    // A null byte[] would go as nvarchar NULL, which SQL will not convert to varbinary.
    private static SqlParameter Hash(string name, byte[]? value) =>
        new(name, SqlDbType.VarBinary, 32) { Value = (object?)value ?? DBNull.Value };
}
