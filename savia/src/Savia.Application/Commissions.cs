using System.Text.Json;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

public interface ICommissionsStore
{
    Task<JsonElement> SellersAsync(Guid branch, CancellationToken ct);
    Task<JsonElement> CommissionsAsync(Guid branch, Guid actor, string period, DateOnly date, CancellationToken ct);
    Task SetSellerRateAsync(Guid seller, SellerRateRequest request, Guid actor, CancellationToken ct);
}

public sealed class CommissionsService(ICommissionsStore store, NodeContext node)
{
    public Task<JsonElement> SellersAsync(Actor actor, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.SalesStaff);
        return store.SellersAsync(branch, ct);
    }

    public Task<JsonElement> CommissionsAsync(Actor actor, string period, DateOnly date, CancellationToken ct)
    {
        var branch = Guard.Branch(actor, node);
        Guard.Role(actor, Roles.CommissionReaders);
        return store.CommissionsAsync(branch, actor.StaffId, period, date, ct);
    }

    public Task SetSellerRateAsync(Actor actor, Guid seller, SellerRateRequest request, CancellationToken ct)
    {
        Guard.Branch(actor, node);
        Guard.Role(actor, Roles.OwnerOnly);
        Guard.Text(request.Reason, "reason", 250);
        return store.SetSellerRateAsync(seller, request, actor.StaffId, ct);
    }
}
