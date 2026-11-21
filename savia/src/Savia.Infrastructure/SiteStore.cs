using Savia.Application;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

public sealed class SiteStore(SqlGateway sql) : ISiteStore
{
    public Task<SiteInfo?> GetSiteAsync(Guid branchId, Guid? locationId, CancellationToken ct) => sql.FirstAsync(
        "SELECT b.Name,b.StoreDisplayName,l.Name FROM core.Branches b LEFT JOIN core.Locations l ON l.Id=@location AND l.BranchId=b.Id WHERE b.Id=@branch",
        r => new SiteInfo(r.GetString(0), r.GetString(1), r.StringOrNull(2)), ct, P("@branch", branchId), P("@location", locationId));
}
