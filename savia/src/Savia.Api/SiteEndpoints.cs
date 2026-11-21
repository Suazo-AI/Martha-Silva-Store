using Savia.Application;
using Savia.Contracts;

namespace Savia.Api;

public static class SiteEndpoints
{
    public static void Map(RouteGroupBuilder api)
    {
        api.MapGet("/me", async (HttpContext http, SiteService site, CancellationToken ct) =>
            await site.GetMeAsync(http.Actor(), ct)).Produces<MeResponse>().WithTags("site");
    }
}
