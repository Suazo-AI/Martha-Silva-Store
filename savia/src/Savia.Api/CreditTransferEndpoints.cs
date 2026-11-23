using Savia.Application;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Api;

/// <summary>D1: moving a customer's credit between stores (V009, V010). Each step exists only on the node that owns it:
/// a store requests, dispatches and receives; the hub approves and cancels. Both list the transfers they hold.</summary>
public static class CreditTransferEndpoints
{
    public static void Map(RouteGroupBuilder api, NodeContext node)
    {
        api.MapGet("/credit-transfers", async (HttpContext http, CustomersService customers, CancellationToken ct) =>
            await customers.TransfersAsync(http.Actor(), ct)).Produces<CreditTransferRow[]>().WithTags("customers");
        if (node.Kind == NodeKind.Branch)
        {
            api.MapPost("/credit-transfers", async (RequestCreditTransferRequest request, HttpContext http, CustomersService customers,
                CancellationToken ct) =>
            {
                await customers.RequestTransferAsync(http.Actor(), request, ct);
                return Results.NoContent();
            }).WithTags("customers");
            api.MapPost("/credit-transfers/{id:guid}/dispatch", Step(TransferStep.Dispatch)).WithTags("customers");
            api.MapPost("/credit-transfers/{id:guid}/receive", Step(TransferStep.Receive)).WithTags("customers");
            return;
        }

        api.MapPost("/credit-transfers/{id:guid}/approve", Step(TransferStep.Approve)).WithTags("customers");
        api.MapPost("/credit-transfers/{id:guid}/cancel", async (Guid id, CancelCreditTransferRequest request, HttpContext http,
            CustomersService customers, CancellationToken ct) =>
        {
            await customers.DecideTransferAsync(http.Actor(), id, TransferStep.Cancel, ct, request.Reason);
            return Results.NoContent();
        }).WithTags("customers");
    }

    private static Func<Guid, HttpContext, CustomersService, CancellationToken, Task<IResult>> Step(TransferStep step) =>
        async (id, http, customers, ct) =>
        {
            await customers.DecideTransferAsync(http.Actor(), id, step, ct);
            return Results.NoContent();
        };
}
