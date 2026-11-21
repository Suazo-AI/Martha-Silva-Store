using System.Globalization;
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

    // The closing report replaces the sheet the store hands to the accountant. It reads only
    // recorded movements and closes, only the locations the actor may read, and changes nothing.
    public async Task<string> ClosingReport(DateOnly from, DateOnly to, CancellationToken ct, Guid actorId = default)
    {
        var locations = new InternalBranchAccess(db).Locations(actorId);
        var start = new DateTimeOffset(from.ToDateTime(TimeOnly.MinValue), TimeSpan.Zero);
        var end = new DateTimeOffset(to.AddDays(1).ToDateTime(TimeOnly.MinValue), TimeSpan.Zero);
        var tills = await db.Set<InternalCashTill>().AsNoTracking()
            .Where(x => locations.Any(location => location.Id == x.LocationId)
                && x.OpenedAt < end && (x.ClosedAt == null || x.ClosedAt >= start))
            .OrderBy(x => x.OpenedAt).ThenBy(x => x.Id).ToListAsync(ct);
        var tillIds = tills.Select(x => x.Id).ToArray();
        var entries = await db.Set<InternalCashEntry>().AsNoTracking()
            .Where(x => tillIds.Contains(x.TillId)).ToListAsync(ct);
        var closes = await db.Set<InternalCashClose>().AsNoTracking()
            .Where(x => tillIds.Contains(x.TillId)).ToDictionaryAsync(x => x.TillId, ct);
        var placeIds = tills.Select(x => x.LocationId).Distinct().ToArray();
        var places = await db.Set<InternalLocation>().AsNoTracking()
            .Where(x => placeIds.Contains(x.Id)).ToDictionaryAsync(x => x.Id, ct);
        var cashierIds = tills.Select(x => x.CashierId).Distinct().ToArray();
        var closerIds = closes.Values.Select(x => x.ActorId).Distinct().ToArray();
        var staff = await db.Set<InternalStaff>().AsNoTracking()
            .Where(x => cashierIds.Contains(x.Id) || closerIds.Contains(x.Id)).ToDictionaryAsync(x => x.Id, ct);
        var rows = new List<string> { InternalCsv.Row(InternalCashReport.ClosingReportColumns) };
        var totals = new Dictionary<(string Currency, int Exponent), (long Opening, long Sales, long Refunds, long Expected, long Counted, long Difference)>();
        foreach (var till in tills)
        {
            var own = entries.Where(entry => entry.TillId == till.Id).ToList();
            long Sum(string kind) => own.Where(entry => entry.Kind == kind).Sum(entry => entry.DeltaMinor);
            var opening = Sum("opening");
            var sales = Sum("sale");
            var refunds = -Sum("refund");
            closes.TryGetValue(till.Id, out var close);
            var expected = close?.ExpectedMinor;
            var counted = close?.CountedMinor;
            var difference = close?.DifferenceMinor;
            var total = totals.GetValueOrDefault((till.Currency, till.Exponent));
            totals[(till.Currency, till.Exponent)] = (total.Opening + opening, total.Sales + sales, total.Refunds + refunds,
                total.Expected + (expected ?? 0), total.Counted + (counted ?? 0), total.Difference + (difference ?? 0));
            rows.Add(InternalCsv.Row([
                "caja",
                (close?.CreatedAt ?? till.OpenedAt).ToString("yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture),
                till.Id.ToString(),
                places.TryGetValue(till.LocationId, out var place) ? place.Name : "",
                till.Currency,
                InternalCsv.Money(opening, till.Exponent),
                InternalCsv.Money(sales, till.Exponent),
                InternalCsv.Money(refunds, till.Exponent),
                expected is null ? "" : InternalCsv.Money(expected.Value, till.Exponent),
                counted is null ? "" : InternalCsv.Money(counted.Value, till.Exponent),
                difference is null ? "" : InternalCsv.Money(difference.Value, till.Exponent),
                close is null ? "abierta" : "cerrada",
                close is not null && staff.TryGetValue(close.ActorId, out var closer) ? closer.DisplayName : "",
                staff.TryGetValue(till.CashierId, out var cashier) ? cashier.DisplayName : ""]));
        }
        foreach (var total in totals.OrderBy(total => total.Key.Currency))
        {
            rows.Add(InternalCsv.Row([
                "total", $"{from:yyyy-MM-dd} a {to:yyyy-MM-dd}", "", "TODAS", total.Key.Currency,
                InternalCsv.Money(total.Value.Opening, total.Key.Exponent),
                InternalCsv.Money(total.Value.Sales, total.Key.Exponent),
                InternalCsv.Money(total.Value.Refunds, total.Key.Exponent),
                InternalCsv.Money(total.Value.Expected, total.Key.Exponent),
                InternalCsv.Money(total.Value.Counted, total.Key.Exponent),
                InternalCsv.Money(total.Value.Difference, total.Key.Exponent),
                "", "", ""]));
        }
        return InternalCsv.Document(rows);
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
