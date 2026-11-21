using Savia.Application;
using Savia.Contracts;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

public sealed class ExchangeRateStore(SqlGateway sql) : IExchangeRateStore
{
    public Task<ExchangeRateResponse?> CurrentAsync(CancellationToken ct) => sql.FirstAsync("""
        SELECT TOP(1) Id,CurrencyCode,Rate,EffectiveFrom FROM core.ExchangeRates
        WHERE EffectiveFrom<=CAST(DATEADD(hour,-6,core.ufn_BusinessNow()) AS date) ORDER BY EffectiveFrom DESC
        """, r => new ExchangeRateResponse(r.GetGuid(0), r.GetString(1), r.GetDecimal(2), DateOnly.FromDateTime(r.GetDateTime(3))), ct);

    public Task SetAsync(ExchangeRateRequest request, Guid actor, CancellationToken ct) =>
        sql.ExecProcAsync("core.usp_SetExchangeRate", ct, P("@Id", request.Id), P("@EffectiveFrom", request.EffectiveFrom.ToDateTime(TimeOnly.MinValue)),
            P("@Rate", request.Rate), P("@ActorId", actor), P("@Reason", request.Reason));
}
