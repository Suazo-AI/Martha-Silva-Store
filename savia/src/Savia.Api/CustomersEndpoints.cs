using Savia.Application;
using Savia.Contracts;

namespace Savia.Api;

public static class CustomersEndpoints
{
    public static void Map(RouteGroupBuilder api)
    {
        api.MapGet("/customers", async (string q, HttpContext http, CustomersService customers, CancellationToken ct) =>
            await customers.CustomersAsync(http.Actor(), q, ct)).Produces<CustomerRow[]>().WithTags("customers");
        api.MapGet("/credits/search", async (string q, HttpContext http, CustomersService customers, CancellationToken ct) =>
            await customers.CreditsAsync(http.Actor(), q, ct)).Produces<CustomerCreditRow[]>().WithTags("customers");
    }
}
