using Microsoft.EntityFrameworkCore;

namespace Martha.Store.Api.Internal;

public sealed class InternalCashService(InternalDbContext db, IInternalCommandRunner commands,
    InternalCommerceService commerce, InternalCashOptions options, TimeProvider time)
{
    private bool Currency(string currency) => options.Valid && currency == options.Currency;
    private static InternalResult<T> Fail<T>(string error) => InternalResult<T>.Fail(error);

    public Task<InternalResult<InternalCashOpenReceipt>> Open(InternalCashOpenRequest request, Guid actor, string key, CancellationToken ct)
    {
        if (!Currency(request.Currency) || !InternalCashRules.Amount(request.OpeningMinor) || request.LocationId == Guid.Empty)
            return Task.FromResult(Fail<InternalCashOpenReceipt>("invalid_request"));
        return commands.RunScoped(actor, "cash.till.open", key, InternalRules.Fingerprint(request),
            new("location", request.LocationId), async token => {
                if (!await db.InternalLocations.AnyAsync(x => x.Id == request.LocationId && x.Active, token))
                    return Fail<InternalCashOpenReceipt>("location_not_found");
                if (await db.Set<InternalCashTill>().AnyAsync(x => x.CashierId == actor && x.ClosedAt == null, token))
                    return Fail<InternalCashOpenReceipt>("till_already_open");
                var till = new InternalCashTill { Id = Guid.NewGuid(), CashierId = actor, LocationId = request.LocationId,
                    Currency = options.Currency, Exponent = options.Exponent, OpenedAt = time.GetUtcNow() };
                var entry = Entry(till, actor, "opening", request.OpeningMinor);
                db.Add(till); db.Add(entry); await db.SaveChangesAsync(token);
                return InternalResult<InternalCashOpenReceipt>.Ok(new(till, entry));
            }, ct);
    }

    public Task<InternalResult<InternalCashSaleReceipt>> Sell(InternalCashSaleRequest request, Guid actor, string key, CancellationToken ct)
    {
        if (!Currency(request.Currency) || request.TillId == Guid.Empty || !InternalCashRules.Amount(request.ReceivedMinor)
            || !InternalCommerceRules.ValidSale(new(Guid.NewGuid(), request.CustomerId, request.Lines)))
            return Task.FromResult(Fail<InternalCashSaleReceipt>("invalid_request"));
        return commands.RunScoped(actor, "cash.sale", key, InternalRules.Fingerprint(request), new("till", request.TillId), async token => {
            var till = await LockTill(request.TillId, token);
            if (till is null || till.CashierId != actor) return Fail<InternalCashSaleReceipt>("forbidden");
            if (till.ClosedAt != null) return Fail<InternalCashSaleReceipt>("till_closed");
            if (till.Currency != options.Currency || till.Exponent != options.Exponent) return Fail<InternalCashSaleReceipt>("currency_mismatch");
            var balance = await Balance(till.Id, token);
            // Transaction-local seam: no nested runner/commit. A failed tender rolls back stock and sale.
            var result = await commerce.RecordSaleLocal(new(till.LocationId, request.CustomerId, request.Lines), actor, token);
            if (!result.Success) return Fail<InternalCashSaleReceipt>(result.Error!);
            var sale = result.Value!;
            if (sale.Currency != till.Currency) return Fail<InternalCashSaleReceipt>("currency_mismatch");
            if (!InternalCashRules.TryChange(sale.TotalMinor, request.ReceivedMinor, out var change))
                return Fail<InternalCashSaleReceipt>("insufficient_tender");
            if (!InternalCashRules.TryBalance([balance, sale.TotalMinor], out _)) return Fail<InternalCashSaleReceipt>("amount_out_of_range");
            var entry = Entry(till, actor, "sale", sale.TotalMinor);
            entry.SaleId = sale.SaleId; entry.ReceivedMinor = request.ReceivedMinor; entry.ChangeMinor = change;
            db.Add(entry); await db.SaveChangesAsync(token);
            return InternalResult<InternalCashSaleReceipt>.Ok(new(sale with { PaymentStatus = "paid" }, entry,
                till.LocationId, till.Exponent, change, "paid"));
        }, ct);
    }

    public Task<InternalResult<InternalCashRefundReceipt>> Refund(Guid saleId, InternalCashRefundRequest request, Guid actor, string key, CancellationToken ct)
    {
        var reversalRequest = new InternalSaleReturnRequest(request.Reason, request.Lines);
        if (!Currency(request.Currency) || saleId == Guid.Empty || request.PayingTillId == Guid.Empty || !InternalCommerceRules.ValidReturn(reversalRequest))
            return Task.FromResult(Fail<InternalCashRefundReceipt>("invalid_request"));
        return commands.RunScoped(actor, "cash.refund", key, InternalRules.Fingerprint(new { saleId, request }),
            new("cash_refund", saleId, request.PayingTillId), async token => {
                var sale = await commerce.LockSale(saleId, token);
                var till = await LockTill(request.PayingTillId, token);
                if (sale is null || till is null) return Fail<InternalCashRefundReceipt>("sale_not_found");
                if (till.ClosedAt != null) return Fail<InternalCashRefundReceipt>("till_closed");
                if (sale.LocationId != till.LocationId) return Fail<InternalCashRefundReceipt>("forbidden");
                if (sale.Currency != till.Currency || till.Currency != options.Currency || till.Exponent != options.Exponent)
                    return Fail<InternalCashRefundReceipt>("currency_mismatch");
                var payment = await db.Set<InternalCashEntry>().AsNoTracking().SingleOrDefaultAsync(x => x.SaleId == saleId && x.Kind == "sale", token);
                if (payment is null || payment.Exponent != till.Exponent) return Fail<InternalCashRefundReceipt>("cash_payment_required");
                var refunded = await db.Set<InternalCashEntry>().Where(x => x.SaleId == saleId && x.Kind == "refund").SumAsync(x => (long?)-x.DeltaMinor, token) ?? 0;
                var byId = sale.Lines.ToDictionary(x => x.Id);
                if (request.Lines!.Any(x => !byId.ContainsKey(x.SaleLineId))) return Fail<InternalCashRefundReceipt>("return_quantity_exceeded");
                if (!InternalCommerceRules.TryTotal(request.Lines!.Select(x => (byId[x.SaleLineId].UnitPriceMinor, x.Quantity)), out var amount)
                    || amount <= 0 || amount > payment.DeltaMinor - refunded) return Fail<InternalCashRefundReceipt>("refund_exceeded");
                if (await Balance(till.Id, token) < amount) return Fail<InternalCashRefundReceipt>("insufficient_cash");
                var result = await commerce.ReturnSaleLocal(sale, reversalRequest, actor, token);
                if (!result.Success) return Fail<InternalCashRefundReceipt>(result.Error!);
                var entry = Entry(till, actor, "refund", -amount); entry.SaleId = saleId; entry.ReversalId = result.Value!.ReversalId;
                db.Add(entry); await db.SaveChangesAsync(token);
                var remaining = checked(payment.DeltaMinor - refunded - amount);
                return InternalResult<InternalCashRefundReceipt>.Ok(new(result.Value, entry, till.LocationId, remaining,
                    remaining == 0 ? "refunded" : "partially_refunded"));
            }, ct);
    }

    public Task<InternalResult<InternalCashCloseReceipt>> Close(Guid tillId, InternalCashCloseRequest request, Guid actor, string key, CancellationToken ct)
    {
        if (tillId == Guid.Empty || !InternalCashRules.Amount(request.CountedMinor))
            return Task.FromResult(Fail<InternalCashCloseReceipt>("invalid_request"));
        return commands.RunScoped(actor, "cash.till.close", key, InternalRules.Fingerprint(new { tillId, request }), new("till", tillId), async token => {
            var till = await LockTill(tillId, token);
            if (till is null || till.CashierId != actor) return Fail<InternalCashCloseReceipt>("forbidden");
            if (till.ClosedAt != null) return Fail<InternalCashCloseReceipt>("till_closed");
            var expected = await Balance(till.Id, token);
            var close = new InternalCashClose { Id = Guid.NewGuid(), TillId = till.Id, ActorId = actor,
                ExpectedMinor = expected, CountedMinor = request.CountedMinor,
                DifferenceMinor = checked(request.CountedMinor - expected), CreatedAt = time.GetUtcNow() };
            till.ClosedAt = close.CreatedAt; db.Add(close); await db.SaveChangesAsync(token);
            return InternalResult<InternalCashCloseReceipt>.Ok(new(till, close));
        }, ct);
    }

    private Task<InternalCashTill?> LockTill(Guid id, CancellationToken ct) => db.Set<InternalCashTill>()
        .FromSqlInterpolated($"SELECT * FROM [savia_internal].[CashTills] WITH (UPDLOCK,HOLDLOCK) WHERE [Id]={id}").SingleOrDefaultAsync(ct);
    private async Task<long> Balance(Guid id, CancellationToken ct)
    {
        var values = await db.Set<InternalCashEntry>().Where(x => x.TillId == id).Select(x => x.DeltaMinor).ToListAsync(ct);
        if (!InternalCashRules.TryBalance(values, out var balance)) throw new InvalidOperationException("Persisted cash balance is out of range.");
        return balance;
    }
    private InternalCashEntry Entry(InternalCashTill till, Guid actor, string kind, long delta) => new() {
        Id = Guid.NewGuid(), TillId = till.Id, CashierId = till.CashierId, ActorId = actor, Currency = till.Currency,
        Exponent = till.Exponent, Kind = kind, DeltaMinor = delta, CreatedAt = time.GetUtcNow() };
}
