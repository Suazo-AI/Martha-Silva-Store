using Savia.Application;
using Savia.Contracts;

namespace Savia.Api;

public static class OwnerPilotEndpoints
{
    public static void Map(RouteGroupBuilder api)
    {
        api.MapPost("/receiving/sessions/{sessionId:guid}/quality",async (Guid sessionId,QualityRequest request,HttpContext http,PilotSalesService pilot,CancellationToken ct)=>
        {
            await pilot.RecordQualityAsync(http.Actor(),sessionId,request,ct);return Results.NoContent();
        }).WithTags("pilot");
        api.MapGet("/receiving/sessions/{sessionId:guid}/quality",async(Guid sessionId,HttpContext http,PilotSalesService pilot,CancellationToken ct)=>
            await pilot.QualityAsync(http.Actor(),sessionId,ct)).WithTags("pilot");
        api.MapGet("/reports/receiving-quality",async(DateOnly from,DateOnly to,HttpContext http,PilotSalesService pilot,CancellationToken ct)=>
            await pilot.QualityReportAsync(http.Actor(),from,to,ct)).WithTags("pilot");
        api.MapGet("/catalog/values",async (string? q,HttpContext http,PilotSalesService pilot,CancellationToken ct)=>
            await pilot.ItemValuesAsync(http.Actor(),q,ct)).WithTags("pilot");
        api.MapPost("/catalog/items/{itemId:guid}/values",async (Guid itemId,ItemValuesRequest request,HttpContext http,PilotSalesService pilot,CancellationToken ct)=>
        {
            await pilot.SetItemValuesAsync(http.Actor(),itemId,request,ct);
            return Results.NoContent();
        }).WithTags("pilot");
        api.MapGet("/sellers", async (HttpContext http, PilotSalesService pilot, CancellationToken ct) =>
            await pilot.SellersAsync(http.Actor(),ct)).WithTags("pilot");
        api.MapGet("/reports/commissions", async (string period,DateOnly date,HttpContext http,PilotSalesService pilot,CancellationToken ct) =>
            await pilot.CommissionsAsync(http.Actor(),period,date,ct)).WithTags("pilot");
        api.MapGet("/reports/commissions.csv", async (string period,DateOnly date,HttpContext http,PilotSalesService pilot,CancellationToken ct) =>
            Results.File(PilotSalesService.SummaryCsv(await pilot.CommissionsAsync(http.Actor(),period,date,ct)),"text/csv; charset=utf-8",$"comisiones-{period}-{date}.csv")).WithTags("pilot");
        api.MapPost("/sellers/{sellerId:guid}/rate",async (Guid sellerId,SellerRateRequest request,HttpContext http,PilotSalesService pilot,CancellationToken ct) =>
        {
            await pilot.SetSellerRateAsync(http.Actor(),sellerId,request,ct);
            return Results.NoContent();
        }).WithTags("pilot");
    }
}
