using Savia.Application;
using Savia.Contracts;

namespace Savia.Api;

public static class ReturnsEndpoints
{
    public static void Map(RouteGroupBuilder api)
    {
        api.MapPost("/sales/{saleId:guid}/returns/credit",
            async (Guid saleId, PostCreditReturnRequest request, HttpContext http, ReturnsService returns, CancellationToken ct) =>
                await returns.ReturnAsync(http.Actor(), saleId, request, ct)).Produces<SaleReversal>().WithTags("returns");
        api.MapPost("/sales/{saleId:guid}/returns/outcome",
            async (Guid saleId, PostReturnOutcomeRequest request, HttpContext http, ReturnsService returns, CancellationToken ct) =>
                await returns.ReturnOutcomeAsync(http.Actor(), saleId, request, ct)).WithTags("returns");
        api.MapGet("/returns/policy", async (HttpContext http, ReturnsService returns, CancellationToken ct) =>
            await returns.ReturnPolicyAsync(http.Actor(), ct)).WithTags("returns");
        api.MapPost("/returns/policy", async (ReturnWindowRequest request, HttpContext http, ReturnsService returns, CancellationToken ct) =>
        {
            await returns.SetReturnWindowAsync(http.Actor(), request, ct);
            return Results.NoContent();
        }).WithTags("returns");
    }
}
