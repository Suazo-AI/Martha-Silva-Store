using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

public interface IExchangeRateStore
{
    Task<ExchangeRateResponse?> CurrentAsync(CancellationToken ct);
    Task SetAsync(ExchangeRateRequest request, Guid actor, CancellationToken ct);
}

public sealed class ExchangeRateService(IExchangeRateStore store, NodeContext node)
{
    public async Task<ExchangeRateResponse> CurrentAsync(Actor actor, CancellationToken ct)
    {
        Guard.BranchRole(actor, node, Roles.TillOperators);
        return await store.CurrentAsync(ct) ?? throw Errors.NotFound("rate.missing", "No hay tasa vigente.");
    }

    public Task SetAsync(Actor actor, ExchangeRateRequest request, CancellationToken ct)
    {
        Guard.BranchRole(actor, node, Roles.Approvers);
        Guard.Text(request.Reason, "reason", 250);
        if (request.Id == Guid.Empty || request.Rate is < 1 or > 1000 || decimal.Round(request.Rate, 4) != request.Rate)
            throw Errors.Invalid("rate.invalid", "Indique una tasa entre 1 y 1000 con hasta cuatro decimales.");
        return store.SetAsync(request, actor.StaffId, ct);
    }
}
