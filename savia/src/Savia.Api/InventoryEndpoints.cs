using Savia.Application;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Api;

public static class InventoryEndpoints
{
    public static void Map(RouteGroupBuilder api, NodeContext node)
    {
        api.MapGet("/stock", async (Guid? itemId, HttpContext http, InventoryService inventory, CancellationToken ct) =>
            await inventory.GetStockAsync(http.Actor(), itemId, ct)).Produces<StockRow[]>().WithTags("inventory");

        if (node.Kind != NodeKind.Branch) return;

        api.MapGet("/labels/jobs", async (string? status, HttpContext http, InventoryService inventory, CancellationToken ct) =>
            await inventory.GetLabelJobsAsync(http.Actor(), status, ct)).Produces<LabelJob[]>().WithTags("inventory");
        api.MapPost("/labels/jobs/{jobId:guid}/attempts",
            async (Guid jobId, AckPrintRequest request, HttpContext http, InventoryService inventory, CancellationToken ct) =>
            {
                await inventory.AcknowledgePrintAsync(http.Actor(), jobId, request, ct);
                return Results.NoContent();
            }).WithTags("inventory");
        api.MapGet("/stock/exceptions", async (HttpContext http, InventoryService inventory, CancellationToken ct) =>
            await inventory.ExceptionsAsync(http.Actor(), ct)).WithTags("inventory");
        api.MapPost("/stock/exceptions/{exceptionId:guid}/review",
            async (Guid exceptionId, ResolveExceptionRequest request, HttpContext http, InventoryService inventory, CancellationToken ct) =>
            {
                await inventory.ReviewExceptionAsync(http.Actor(), exceptionId, request, ct);
                return Results.NoContent();
            }).WithTags("inventory");
    }
}
