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
}
