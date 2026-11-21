using System.Text.Json;
using Savia.Application;
using Savia.Contracts;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

public sealed class CommissionsStore(SqlGateway sql) : ICommissionsStore
{
    public Task<JsonElement> SellersAsync(Guid branch, CancellationToken ct) =>
        sql.ReadElement("sales.usp_ListSellers", ct, P("@BranchId", branch));

    public Task<JsonElement> CommissionsAsync(Guid branch, Guid actor, string period, DateOnly date, CancellationToken ct) =>
        sql.ReadElement("sales.usp_GetCommissions", ct, P("@BranchId", branch), P("@ActorId", actor),
            P("@Period", period), P("@Date", date.ToDateTime(TimeOnly.MinValue)));

    public Task SetSellerRateAsync(Guid seller, SellerRateRequest request, Guid actor, CancellationToken ct) =>
        sql.ExecProcAsync("sales.usp_SetSellerRate", ct, P("@SellerId", seller), P("@ChangeId", request.ChangeId),
            P("@RateBps", request.RateBps), P("@Reason", request.Reason), P("@ActorId", actor));
}
