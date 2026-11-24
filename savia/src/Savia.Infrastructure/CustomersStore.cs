using Savia.Application;
using Savia.Contracts;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

public sealed class CustomersStore(SqlGateway sql) : ICustomersStore
{
    public async Task<IReadOnlyList<CustomerRow>> CustomersAsync(string query, CancellationToken ct) =>
        await sql.QueryProcAsync("crm.usp_SearchCustomers",
            r => new CustomerRow(r.GetGuid(0), r.StringOrNull(1), r.GetString(2), r.StringOrNull(3), r.StringOrNull(4)), ct, P("@Query", query));

    public async Task<IReadOnlyList<CustomerCreditRow>> CreditsAsync(string query, Guid actor, CancellationToken ct) =>
        await sql.QueryProcAsync("credits.usp_FindCustomerCredits",
            r => new CustomerCreditRow(r.GetGuid(0), r.GetString(1), r.StringOrNull(2), r.StringOrNull(3),
            r.GetGuid(4), r.GetString(5), r.GetGuid(6), r.GetString(7), r.GetInt64(8)), ct, P("@Query", query), P("@ActorId", actor));

    public Task CreateAsync(CreateCustomerRequest request, Guid actor, CancellationToken ct) =>
        sql.ExecProcAsync("crm.usp_CreateCustomer", ct, P("@CustomerId", request.CustomerId), P("@DisplayName", request.DisplayName),
            P("@DocumentNumber", request.DocumentNumber), P("@Phone", request.Phone), P("@Email", request.Email), P("@ActorId", actor));

    public async Task<IReadOnlyList<CreditTransferRow>> TransfersAsync(Guid? branch, CancellationToken ct) =>
        await sql.QueryProcAsync("credits.usp_ListTransfers",
            r => new CreditTransferRow(r.GetGuid(0), r.GetGuid(1), r.GetString(2), r.GetGuid(3), r.GetString(4), r.GetGuid(5),
            r.GetString(6), r.GetInt64(7), r.GetString(8), r.GetString(9), r.GetString(10), r.Utc(11)), ct, P("@BranchId", branch));

    public Task RequestTransferAsync(RequestCreditTransferRequest request, Guid actor, Guid node, CancellationToken ct) =>
        sql.ExecProcAsync("credits.usp_TransferRequest", ct, P("@TransferId", request.TransferId), P("@CreditId", request.CreditId),
            P("@FromBranchId", request.FromBranchId), P("@ToBranchId", request.ToBranchId), P("@AmountMinor", request.AmountMinor),
            P("@RequestedBy", actor), P("@Reason", request.Reason), P("@NodeId", node));

    public Task DecideTransferAsync(Guid transfer, TransferStep step, Guid actor, Guid node, CancellationToken ct, string? reason = null) =>
        step switch
        {
            TransferStep.Approve => sql.ExecProcAsync("credits.usp_TransferApprove", ct, P("@TransferId", transfer),
                P("@ApproverId", actor), P("@NodeId", node)),
            TransferStep.Cancel => sql.ExecProcAsync("credits.usp_TransferCancel", ct, P("@TransferId", transfer), P("@ActorId", actor),
                P("@Reason", reason), P("@NodeId", node)),
            TransferStep.Dispatch => sql.ExecProcAsync("credits.usp_TransferDispatch", ct, P("@TransferId", transfer),
                P("@ActorId", actor), P("@NodeId", node)),
            _ => sql.ExecProcAsync("credits.usp_TransferReceive", ct, P("@TransferId", transfer), P("@ActorId", actor),
                P("@NodeId", node)),
        };
}
