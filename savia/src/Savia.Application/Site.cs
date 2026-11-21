using Savia.Contracts;

namespace Savia.Application;

/// <summary>Names of the branch and location this node serves, for the signed-in screen.</summary>
public sealed record SiteInfo(string BranchName, string StoreDisplayName, string? LocationName);

public interface ISiteStore
{
    Task<SiteInfo?> GetSiteAsync(Guid branchId, Guid? locationId, CancellationToken ct);
}

public sealed class SiteService(ISiteStore store, NodeContext node)
{
    /// <summary>The actor plus the branch, location and names of this node, so a client needs no fixed ids.</summary>
    public async Task<MeResponse> GetMeAsync(Actor actor, CancellationToken ct)
    {
        var site = node.BranchId is Guid branch ? await store.GetSiteAsync(branch, node.LocationId, ct) : null;
        return new MeResponse(actor.StaffId, actor.DisplayName, [.. actor.Roles.Order()], node.Kind.ToString(), node.NodeId, node.BranchId,
            node.LocationId, site?.BranchName, site?.StoreDisplayName, site?.LocationName);
    }
}
