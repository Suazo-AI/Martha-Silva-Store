namespace Savia.Contracts;

public sealed record ExchangeRateResponse(Guid Id, string CurrencyCode, decimal Rate, DateOnly EffectiveFrom);
public sealed record ExchangeRateRequest(Guid Id, DateOnly EffectiveFrom, decimal Rate, string Reason);
