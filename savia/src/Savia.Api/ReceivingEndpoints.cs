using Savia.Application;
using Savia.Contracts;

namespace Savia.Api;

public static class ReceivingEndpoints
{
    public static void Map(RouteGroupBuilder api)
    {
        api.MapPost("/receiving/sessions", async (OpenScanSessionRequest request, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
        {
            await receiving.OpenSessionAsync(http.Actor(), request, ct);
            return Results.NoContent();
        }).WithTags("receiving");
        api.MapPost("/receiving/sessions/{sessionId:guid}/scans",
            async (Guid sessionId, RecordScanRequest request, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
                await receiving.RecordScanAsync(http.Actor(), sessionId, request, ct)).WithTags("receiving");
        api.MapGet("/receiving/sessions", async (bool? open, int? limit, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
            await receiving.ListSessionsAsync(http.Actor(), open ?? true, limit, ct)).Produces<ScanSessionSummary[]>().WithTags("receiving");
        api.MapGet("/receiving/sessions/{sessionId:guid}/lines",
            async (Guid sessionId, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
                await receiving.GetLinesAsync(http.Actor(), sessionId, ct)).Produces<ScanSessionLine[]>().WithTags("receiving");
        api.MapPost("/receiving/sessions/{sessionId:guid}/scans/{scanId:guid}/resolve",
            async (Guid sessionId, Guid scanId, ResolveScanRequest request, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
            {
                await receiving.ResolveScanAsync(http.Actor(), sessionId, scanId, request, ct);
                return Results.NoContent();
            }).WithTags("receiving");
        api.MapPost("/receiving/sessions/{sessionId:guid}/scans/{scanId:guid}/reject",
            async (Guid sessionId, Guid scanId, RejectScanRequest request, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
            {
                await receiving.RejectScanAsync(http.Actor(), sessionId, scanId, request, ct);
                return Results.NoContent();
            }).WithTags("receiving");
        api.MapGet("/suppliers", async (HttpContext http, ReceivingService receiving, CancellationToken ct) =>
            await receiving.ListSuppliersAsync(http.Actor(), ct)).Produces<SupplierRow[]>().WithTags("receiving");
        api.MapGet("/receiving/sessions/{sessionId:guid}", async (Guid sessionId, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
            await receiving.GetProgressAsync(http.Actor(), sessionId, ct)).WithTags("receiving");
        api.MapPost("/receiving/sessions/{sessionId:guid}/approve",
            async (Guid sessionId, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
            {
                await receiving.ApproveAsync(http.Actor(), sessionId, ct);
                return Results.NoContent();
            }).WithTags("receiving");
        api.MapPost("/receiving/sessions/{sessionId:guid}/post",
            async (Guid sessionId, string? currency, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
                await receiving.PostAsync(http.Actor(), sessionId, currency ?? "NIO", ct)).WithTags("receiving");
        api.MapPost("/receiving/sessions/{sessionId:guid}/quality",
            async (Guid sessionId, QualityRequest request, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
            {
                await receiving.RecordQualityAsync(http.Actor(), sessionId, request, ct);
                return Results.NoContent();
            }).WithTags("receiving");
        api.MapGet("/receiving/sessions/{sessionId:guid}/quality",
            async (Guid sessionId, HttpContext http, ReceivingService receiving, CancellationToken ct) =>
                await receiving.QualityAsync(http.Actor(), sessionId, ct)).WithTags("receiving");
    }
}
