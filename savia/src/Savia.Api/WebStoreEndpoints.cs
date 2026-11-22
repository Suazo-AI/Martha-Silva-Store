using Savia.Application;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Api;

/// <summary>Signed-in routes for web orders: staff on the hub, and the branch that hands stock to the web.</summary>
public static class WebStoreEndpoints
{
    public static void Map(RouteGroupBuilder api, NodeContext node)
    {
        if (node.Kind == NodeKind.Branch)
        {
            api.MapPost("/stock/web-consignments", async (WebConsignmentRequest request, HttpContext http, WebStoreService web,
                CancellationToken ct) =>
            {
                await web.ConsignAsync(http.Actor(), request, ct);
                return Results.NoContent();
            }).WithTags("webstore");
            return;
        }

        api.MapGet("/web-orders", async (string? status, HttpContext http, WebStoreService web, CancellationToken ct) =>
            await web.ListOrdersAsync(http.Actor(), status, ct)).Produces<WebOrderRow[]>().WithTags("webstore");
        api.MapPost("/web-orders/{id:guid}/manual-payment", async (Guid id, ManualPaymentRequest request, HttpContext http,
            WebStoreService web, CancellationToken ct) =>
        {
            await web.RecordManualPaymentAsync(http.Actor(), id, request, ct);
            return Results.NoContent();
        }).WithTags("webstore");
        api.MapPost("/web-orders/{id:guid}/fulfill", async (Guid id, HttpContext http, WebStoreService web, CancellationToken ct) =>
        {
            await web.FulfillAsync(http.Actor(), id, ct);
            return Results.NoContent();
        }).WithTags("webstore");
        api.MapPost("/web-orders/{id:guid}/cancel", async (Guid id, HttpContext http, WebStoreService web, CancellationToken ct) =>
        {
            await web.CancelAsync(http.Actor(), id, ct);
            return Results.NoContent();
        }).WithTags("webstore");
        api.MapPost("/web-stock/release", async (WebReleaseRequest request, HttpContext http, WebStoreService web, CancellationToken ct) =>
        {
            await web.ReleaseAsync(http.Actor(), request, ct);
            return Results.NoContent();
        }).WithTags("webstore");
    }
}
