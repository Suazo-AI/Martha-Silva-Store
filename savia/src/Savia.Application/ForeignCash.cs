using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

public static class ForeignCash
{
    public static bool HasFields(SaleTender t) => t.ForeignCurrencyCode is not null || t.ForeignReceivedMinor is not null ||
        t.ExchangeRateId is not null || t.ExchangeRate is not null || t.RoundingMinor is not null || t.ForeignChangeMinor is not null;

    public static void Validate(SaleTender t)
    {
        if (HasFields(t) && (t.TenderKind != "cash" || t.ForeignCurrencyCode != "USD" ||
            t.ForeignReceivedMinor is null or <= 0 || t.ExchangeRateId is null ||
            t.ForeignChangeMinor is < 0 || t.ForeignChangeMinor >= t.ForeignReceivedMinor))
            throw Errors.Invalid("sale.fx", "Indique efectivo USD, cantidad y tasa vigente.");
    }
}
