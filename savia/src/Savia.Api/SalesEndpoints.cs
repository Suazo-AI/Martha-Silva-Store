using Savia.Application;
using Savia.Contracts;

namespace Savia.Api;

public static class SalesEndpoints
{
    public static void Map(RouteGroupBuilder api)
    {
        api.MapPost("/sales", async (PostSaleRequest request, HttpContext http, SalesService sales, AuthService auth, CancellationToken ct) =>
        {
            var token = http.Request.Headers["X-Savia-Approval"].ToString();
            var approval = string.IsNullOrEmpty(token) ? null : await auth.AuthenticateAsync(token, ct);
            return await sales.PostSaleAsync(http.Actor(), request, ct, approval);
        }).WithTags("sales");
        api.MapGet("/sales/{saleId:guid}", async (Guid saleId, HttpContext http, SalesService sales, CancellationToken ct) =>
            await sales.DetailAsync(http.Actor(), saleId, ct)).Produces<SaleDetailResponse>().WithTags("sales");
        api.MapGet("/sales",
            async (DateOnly? from, DateOnly? to, string? q, int? page, int? pageSize, HttpContext http, SalesService sales, CancellationToken ct) =>
                await sales.SearchAsync(http.Actor(), from, to, q, page, pageSize, ct)).Produces<SalesPage>().WithTags("sales");
    }
}
