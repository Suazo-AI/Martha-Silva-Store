using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

public interface ICustomersStore
{
    Task<IReadOnlyList<CustomerRow>> CustomersAsync(string query, CancellationToken ct);
    Task<IReadOnlyList<CustomerCreditRow>> CreditsAsync(string query, Guid actor, CancellationToken ct);
}

public sealed class CustomersService(ICustomersStore store, NodeContext node)
{
    public Task<IReadOnlyList<CustomerRow>> CustomersAsync(Actor actor, string q, CancellationToken ct)
    {
        Guard.BranchRole(actor, node, Roles.TillOperators);
        return store.CustomersAsync(Guard.Text(q, "q", 100).Trim(), ct);
    }

    public Task<IReadOnlyList<CustomerCreditRow>> CreditsAsync(Actor actor, string q, CancellationToken ct)
    {
        Guard.BranchRole(actor, node, Roles.TillOperators);
        return store.CreditsAsync(Guard.Text(q, "q", 100).Trim(), actor.StaffId, ct);
    }
}
